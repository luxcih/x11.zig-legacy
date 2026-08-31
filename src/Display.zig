//! X11 display names such as `:0` and `hostname:1.0`.
//!
//! A display name identifies the X server a client intends to connect to.

const std = @import("std");
const Parser = @import("Display/Parser.zig");

const Display = @This();

protocol: ?[]const u8,
host: []const u8,
separator: Separator,
display_number: u32,
screen_number: u32 = 0,

pub const Separator = Parser.Separator;
pub const ParseError = Parser.Error;

/// Parses an X11 display name.
pub fn parse(value: []const u8) ParseError!Display {
    var parser = Parser.init(value);
    const result = try parser.parse();

    return .{
        .protocol = result.protocol,
        .host = result.host,
        .separator = result.separator,
        .display_number = result.display_number,
        .screen_number = result.screen_number,
    };
}

test "parse local display" {
    const display = try Display.parse(":0");

    try std.testing.expect(display.protocol == null);
    try std.testing.expectEqualStrings("", display.host);
    try std.testing.expectEqual(Display.Separator.colon, display.separator);
    try std.testing.expectEqual(@as(u32, 0), display.display_number);
    try std.testing.expectEqual(@as(u32, 0), display.screen_number);
}

test "parse local display with screen" {
    const display = try Display.parse(":0.1");

    try std.testing.expectEqualStrings("", display.host);
    try std.testing.expectEqual(Display.Separator.colon, display.separator);
    try std.testing.expectEqual(@as(u32, 0), display.display_number);
    try std.testing.expectEqual(@as(u32, 1), display.screen_number);
}

test "parse hostname" {
    const display = try Display.parse("example.org:12.3");

    try std.testing.expect(display.protocol == null);
    try std.testing.expectEqualStrings("example.org", display.host);
    try std.testing.expectEqual(Display.Separator.colon, display.separator);
    try std.testing.expectEqual(@as(u32, 12), display.display_number);
    try std.testing.expectEqual(@as(u32, 3), display.screen_number);
}

test "parse protocol" {
    const display = try Display.parse("tcp/example.org:1");

    try std.testing.expectEqualStrings("tcp", display.protocol.?);
    try std.testing.expectEqualStrings("example.org", display.host);
    try std.testing.expectEqual(Display.Separator.colon, display.separator);
    try std.testing.expectEqual(@as(u32, 1), display.display_number);
}

test "parse double colon" {
    const display = try Display.parse("machine::0.1");

    try std.testing.expectEqualStrings("machine", display.host);
    try std.testing.expectEqual(Display.Separator.double_colon, display.separator);
    try std.testing.expectEqual(@as(u32, 0), display.display_number);
    try std.testing.expectEqual(@as(u32, 1), display.screen_number);
}

test "reject malformed displays" {
    const invalid = [_][]const u8{
        "",
        ":",
        ":abc",
        "/host:0",
        "tcp/:0",
        "host:0/",
        "host:",
        "host:0.",
        "host:.0",
        "host:0.1.2",
    };

    for (invalid) |value| {
        try std.testing.expectError(Display.ParseError.InvalidDisplay, Display.parse(value));
    }
}
