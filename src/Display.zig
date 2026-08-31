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

    return .{
        .protocol = parseProtocol(value),
        .host = try parseHost(value),
        .separator = try parseSeparator(value),
        .number = try parseNumber(value),
        .screen = try parseScreen(value),
    };
}

fn parseProtocol(value: []const u8) ?[]const u8 {
    const slash = std.mem.findScalar(u8, value, '/') orelse {
        return null;
    };

    return value[0..slash];
}

fn parseHost(value: []const u8) ParseError![]const u8 {
    const start = if (std.mem.findScalar(u8, value, '/')) |slash|
        slash + 1
    else
        0;

    const colon = std.mem.findScalar(u8, value[start..], ':') orelse {
        return error.InvalidDisplay;
    };

    return value[start .. start + colon];
}

fn parseSeparator(value: []const u8) ParseError!Separator {
    const start = if (std.mem.findScalar(u8, value, '/')) |slash|
        slash + 1
    else
        0;

    const colon = std.mem.findScalar(u8, value[start..], ':') orelse {
        return error.InvalidDisplay;
    };

    const index = start + colon;

    if (index + 1 < value.len and value[index + 1] == ':') {
        return .double_colon;
    }

    return .colon;
}

fn parseNumber(value: []const u8) ParseError!u32 {
    const start = if (std.mem.findScalar(u8, value, '/')) |slash|
        slash + 1
    else
        0;

    const colon = std.mem.findScalar(u8, value[start..], ':') orelse {
        return error.InvalidDisplay;
    };

    var number_start = start + colon + 1;
    if (number_start < value.len and value[number_start] == ':') {
        number_start += 1;
    }

    const number_and_screen = value[number_start..];
    const number = if (std.mem.findScalar(u8, number_and_screen, '.')) |dot|
        number_and_screen[0..dot]
    else
        number_and_screen;

    return parseInteger(number);
}

fn parseScreen(value: []const u8) ParseError!u32 {
    const start = if (std.mem.findScalar(u8, value, '/')) |slash|
        slash + 1
    else
        0;

    const colon = std.mem.findScalar(u8, value[start..], ':') orelse {
        return error.InvalidDisplay;
    };

    var number_start = start + colon + 1;
    if (number_start < value.len and value[number_start] == ':') {
        number_start += 1;
    }

    const number_and_screen = value[number_start..];

    const dot = std.mem.findScalar(u8, number_and_screen, '.') orelse {
        return 0;
    };

    return parseInteger(number_and_screen[dot + 1 ..]);
}

fn parseInteger(value: []const u8) ParseError!u32 {
    if (value.len == 0) return error.InvalidDisplay;

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