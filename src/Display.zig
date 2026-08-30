const std = @import("std");

const Display = @This();

protocol: ?[]const u8,
host: []const u8,
number: u32,
screen: u32 = 0,

pub const ParseError = error{
    InvalidDisplay,
};

/// Parses an X11 display name.
///
/// Supported forms:
///   :0
///   :0.1
///   host:0
///   protocol/host:0
///   [::1]:0
pub fn parse(value: []const u8) ParseError!Display {
    if (value.len == 0) return error.InvalidDisplay;

    const rest = parseProtocol(value) catch return error.InvalidDisplay;
    const address = parseAddress(rest) catch return error.InvalidDisplay;

    return .{
        .protocol = parseProtocolName(value, rest),
        .host = address.host,
        .number = parseNumber(address.display),
        .screen = parseScreen(address.screen),
    };
}

const Address = struct {
    host: []const u8,
    display: []const u8,
    screen: ?[]const u8,
};

fn parseProtocol(value: []const u8) ParseError![]const u8 {
    const slash = std.mem.findScalar(u8, value, '/') orelse return value;

    if (slash == 0) return error.InvalidDisplay;
    if (slash + 1 >= value.len) return error.InvalidDisplay;

    return value[slash + 1 ..];
}

fn parseProtocolName(value: []const u8, rest: []const u8) ?[]const u8 {
    if (rest.ptr == value.ptr) return null;

    const protocol_len = value.len - rest.len - 1;
    return value[0..protocol_len];
}

fn parseAddress(value: []const u8) ParseError!Address {
    if (value[0] == '[') return parseBracketedHost(value);
    return parseHost(value);
}

fn parseBracketedHost(value: []const u8) ParseError!Address {
    const close = std.mem.findScalar(u8, value, ']') orelse return error.InvalidDisplay;
    if (close == 1) return error.InvalidDisplay;
    if (close + 1 >= value.len or value[close + 1] != ':') {
        return error.InvalidDisplay;
    }

    return parseDisplay(value[1..close], value[close + 2 ..]);
}

fn parseHost(value: []const u8) ParseError!Address {
    const colon = std.mem.findLastScalar(u8, value, ':') orelse {
        return error.InvalidDisplay;
    };

    return parseDisplay(value[0..colon], value[colon + 1 ..]);
}

fn parseDisplay(host: []const u8, value: []const u8) ParseError!Address {
    if (value.len == 0) return error.InvalidDisplay;

    if (std.mem.findScalar(u8, value, '.')) |dot| {
        if (dot == 0 or dot + 1 >= value.len) return error.InvalidDisplay;
        if (std.mem.findScalar(u8, value[dot + 1 ..], '.')) != null) {
            return error.InvalidDisplay;
        }

        return .{
            .host = host,
            .display = value[0..dot],
            .screen = value[dot + 1 ..],
        };
    }

    return .{
        .host = host,
        .display = value,
        .screen = null,
    };
}

fn parseNumber(value: []const u8) ParseError!u32 {
    return std.fmt.parseInt(u32, value, 10) catch error.InvalidDisplay;
}

fn parseScreen(value: ?[]const u8) ParseError!u32 {
    if (value) |screen| return parseNumber(screen);
    return 0;
}

test "parse local display" {
    const display = try parse(":0");

    try std.testing.expect(display.protocol == null);
    try std.testing.expectEqualStrings("", display.host);
    try std.testing.expectEqual(@as(u32, 0), display.number);
    try std.testing.expectEqual(@as(u32, 0), display.screen);
}

test "parse local display with screen" {
    const display = try parse(":0.1");

    try std.testing.expectEqualStrings("", display.host);
    try std.testing.expectEqual(@as(u32, 0), display.number);
    try std.testing.expectEqual(@as(u32, 1), display.screen);
}

test "parse hostname" {
    const display = try parse("example.org:12.3");

    try std.testing.expect(display.protocol == null);
    try std.testing.expectEqualStrings("example.org", display.host);
    try std.testing.expectEqual(@as(u32, 12), display.number);
    try std.testing.expectEqual(@as(u32, 3), display.screen);
}

test "parse protocol" {
    const display = try parse("tcp/example.org:1");

    try std.testing.expectEqualStrings("tcp", display.protocol.?);
    try std.testing.expectEqualStrings("example.org", display.host);
    try std.testing.expectEqual(@as(u32, 1), display.number);
}

test "parse bracketed IPv6" {
    const display = try parse("[::1]:0");

    try std.testing.expectEqualStrings("::1", display.host);
    try std.testing.expectEqual(@as(u32, 0), display.number);
}

test "reject malformed displays" {
    const invalid = [_][]const u8{
        "",
        ":",
        ":abc",
        "host:",
        "host:0.",
        "host:.0",
        "host:0.1.2",
        "[::1",
        "[]:0",
    };

    for (invalid) |value| {
        try std.testing.expectError(error.InvalidDisplay, parse(value));
    }
}
