//! Parsing of X11 display names such as `:0` and `hostname:1.0`.
//!
//! A display name identifies the X server a client intends to connect to.
//! This type parses the protocol, host, display number, and optional screen.

const std = @import("std");

const Display = @This();

protocol: ?[]const u8,
host: []const u8,
separator: Separator,
number: u32,
screen: u32 = 0,

pub const Separator = enum {
    colon,
    double_colon,
};

pub const ParseError = error{
    InvalidDisplay,
};

/// Parses an X11 display name.
pub fn parse(value: []const u8) ParseError!Display {
    if (value.len == 0) return error.InvalidDisplay;

    const protocol, const address = parseProtocol(value);
    const host, const separator, const number_and_screen = try parseAddress(address);

    const number, const screen = try parseNumberAndScreen(number_and_screen);

    return .{
        .protocol = protocol,
        .host = host,
        .separator = separator,
        .number = number,
        .screen = screen,
    };
}

fn parseProtocol(value: []const u8) struct { ?[]const u8, []const u8 } {
    const slash = std.mem.findScalar(u8, value, '/') orelse {
        return .{ null, value };
    };

    return .{ value[0..slash], value[slash + 1 ..] };
}

fn parseAddress(value: []const u8) ParseError!struct { []const u8, Separator, []const u8 } {
    const colon = std.mem.findScalar(u8, value, ':') orelse {
        return error.InvalidDisplay;
    };

    const separator: Separator = if (colon + 1 < value.len and value[colon + 1] == ':') .double_colon else .colon;

    const separator_len: usize = switch (separator) {
        .colon => 1,
        .double_colon => 2,
    };

    const host = value[0..colon];
    const number_and_screen = value[colon + separator_len ..];

    if (number_and_screen.len == 0) return error.InvalidDisplay;

    return .{ host, separator, number_and_screen };
}

fn parseNumberAndScreen(value: []const u8) ParseError!struct { u32, u32 } {
    if (std.mem.findScalar(u8, value, '.')) |dot| {
        const number = value[0..dot];
        const screen = value[dot + 1 ..];

        if (number.len == 0 or screen.len == 0) {
            return error.InvalidDisplay;
        }

        if (std.mem.findScalar(u8, screen, '.') != null) {
            return error.InvalidDisplay;
        }

        return .{
            try parseNumber(number),
            try parseNumber(screen),
        };
    }

    return .{
        try parseNumber(value),
        0,
    };
}

fn parseNumber(value: []const u8) ParseError!u32 {
    return std.fmt.parseInt(u32, value, 10) catch {
        return error.InvalidDisplay;
    };
}

test "parse local display" {
    const display = try Display.parse(":0");

    try std.testing.expect(display.protocol == null);
    try std.testing.expectEqualStrings("", display.host);
    try std.testing.expectEqual(Display.Separator.colon, display.separator);
    try std.testing.expectEqual(@as(u32, 0), display.number);
    try std.testing.expectEqual(@as(u32, 0), display.screen);
}

test "parse local display with screen" {
    const display = try Display.parse(":0.1");

    try std.testing.expectEqualStrings("", display.host);
    try std.testing.expectEqual(Display.Separator.colon, display.separator);
    try std.testing.expectEqual(@as(u32, 0), display.number);
    try std.testing.expectEqual(@as(u32, 1), display.screen);
}

test "parse hostname" {
    const display = try Display.parse("example.org:12.3");

    try std.testing.expect(display.protocol == null);
    try std.testing.expectEqualStrings("example.org", display.host);
    try std.testing.expectEqual(Display.Separator.colon, display.separator);
    try std.testing.expectEqual(@as(u32, 12), display.number);
    try std.testing.expectEqual(@as(u32, 3), display.screen);
}

test "parse protocol" {
    const display = try Display.parse("tcp/example.org:1");

    try std.testing.expectEqualStrings("tcp", display.protocol.?);
    try std.testing.expectEqualStrings("example.org", display.host);
    try std.testing.expectEqual(Display.Separator.colon, display.separator);
    try std.testing.expectEqual(@as(u32, 1), display.number);
}

test "parse double colon" {
    const display = try Display.parse("machine::0.1");

    try std.testing.expectEqualStrings("machine", display.host);
    try std.testing.expectEqual(Display.Separator.double_colon, display.separator);
    try std.testing.expectEqual(@as(u32, 0), display.number);
    try std.testing.expectEqual(@as(u32, 1), display.screen);
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
    };

    for (invalid) |value| {
        try std.testing.expectError(Display.ParseError.InvalidDisplay, Display.parse(value));
    }
}
