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

    const slash = std.mem.findScalar(u8, value, '/');
    const address_start = if (slash) |index| index + 1 else 0;

    const colon = std.mem.findScalar(u8, value[address_start..], ':') orelse {
        return error.InvalidDisplay;
    };
    const separator_start = address_start + colon;

    const separator: Separator = if (
        separator_start + 1 < value.len and
        value[separator_start + 1] == ':'
    )
        .double_colon
    else
        .colon;

    const number_start = separator_start + switch (separator) {
        .colon => 1,
        .double_colon => 2,
    };

    const number_and_screen = value[number_start..];
    if (number_and_screen.len == 0) return error.InvalidDisplay;

    const dot = std.mem.findScalar(u8, number_and_screen, '.');

    const number_slice = if (dot) |index|
        number_and_screen[0..index]
    else
        number_and_screen;

    if (number_slice.len == 0) return error.InvalidDisplay;

    const number = std.fmt.parseInt(u32, number_slice, 10) catch {
        return error.InvalidDisplay;
    };

    const screen = if (dot) |index| blk: {
        const screen_slice = number_and_screen[index + 1 ..];

        if (screen_slice.len == 0) return error.InvalidDisplay;

        break :blk std.fmt.parseInt(u32, screen_slice, 10) catch {
            return error.InvalidDisplay;
        };
    } else 0;

    return .{
        .protocol = if (slash) |index| value[0..index] else null,
        .host = value[address_start..separator_start],
        .separator = separator,
        .number = number,
        .screen = screen,
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