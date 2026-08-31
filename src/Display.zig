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

const Address = struct {
    host: []const u8,
    separator: Separator,
    number: u32,
    screen: u32,
};

/// Parses an X11 display name.
pub fn parse(value: []const u8) ParseError!Display {
    if (value.len == 0) return error.InvalidDisplay;

    const protocol = parseProtocol(value);
    const address = try parseAddress(value);

    return .{
        .protocol = protocol,
        .host = address.host,
        .separator = address.separator,
        .number = address.number,
        .screen = address.screen,
    };
}

fn parseProtocol(value: []const u8) ?[]const u8 {
    const slash = std.mem.findScalar(u8, value, '/') orelse {
        return null;
    };

    return value[0..slash];
}

fn parseAddress(value: []const u8) ParseError!Address {
    const address = if (std.mem.findScalar(u8, value, '/')) |slash|
        value[slash + 1 ..]
    else
        value;

    const colon = std.mem.findScalar(u8, address, ':') orelse {
        return error.InvalidDisplay;
    };

    const separator: Separator = if (colon + 1 < address.len and address[colon + 1] == ':')
        .double_colon
    else
        .colon;

    const separator_len: usize = switch (separator) {
        .colon => 1,
        .double_colon => 2,
    };

    const host = address[0..colon];
    const number_and_screen = address[colon + separator_len ..];

    if (number_and_screen.len == 0) return error.InvalidDisplay;

    const number = if (std.mem.findScalar(u8, number_and_screen, '.')) |dot|
        try parseNumber(number_and_screen[0..dot])
    else
        try parseNumber(number_and_screen);

    const screen = if (std.mem.findScalar(u8, number_and_screen, '.')) |dot|
        try parseScreen(number_and_screen[dot + 1 ..])
    else
        0;

    return .{
        .host = host,
        .separator = separator,
        .number = number,
        .screen = screen,
    };
}

fn parseNumber(value: []const u8) ParseError!u32 {
    if (value.len == 0) return error.InvalidDisplay;

    return std.fmt.parseInt(u32, value, 10) catch {
        return error.InvalidDisplay;
    };
}

fn parseScreen(value: []const u8) ParseError!u32 {
    if (value.len == 0 or std.mem.findScalar(u8, value, '.') != null) {
        return error.InvalidDisplay;
    }

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