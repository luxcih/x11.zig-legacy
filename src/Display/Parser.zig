//! Internal parser for X11 display names.
//!
//! The parser owns the display-name grammar and produces its parsed fields.

const std = @import("std");

const Parser = @This();

value: []const u8,

pub const Separator = enum {
    colon,
    double_colon,
};

pub const Error = error{
    InvalidDisplay,
};

pub const Result = struct {
    protocol: ?[]const u8,
    host: []const u8,
    separator: Separator,
    number: u32,
    screen: u32 = 0,
};

pub fn init(value: []const u8) Parser {
    return .{
        .value = value,
    };
}

pub fn parse(self: Parser) Error!Result {
    const value = self.value;

    if (value.len == 0) return error.InvalidDisplay;

    const slash = std.mem.findScalar(u8, value, '/');
    const address_start = if (slash) |index| index + 1 else 0;

    const colon = std.mem.findScalar(u8, value[address_start..], ':') orelse {
        return error.InvalidDisplay;
    };
    const host_end = address_start + colon;

    const separator: Separator = if (
        host_end + 1 < value.len and
        value[host_end + 1] == ':'
    )
        .double_colon
    else
        .colon;

    const number_start = host_end + switch (separator) {
        .colon => 1,
        .double_colon => 2,
    };

    const dot = std.mem.findScalar(u8, value[number_start..], '.');
    const number_end = if (dot) |index| number_start + index else value.len;

    const number_slice = value[number_start..number_end];
    if (number_slice.len == 0) return error.InvalidDisplay;

    const number = std.fmt.parseInt(u32, number_slice, 10) catch {
        return error.InvalidDisplay;
    };

    const screen = if (dot != null) blk: {
        const screen_slice = value[number_end + 1 ..];

        if (screen_slice.len == 0) return error.InvalidDisplay;

        break :blk std.fmt.parseInt(u32, screen_slice, 10) catch {
            return error.InvalidDisplay;
        };
    } else 0;

    return .{
        .protocol = if (slash) |index| value[0..index] else null,
        .host = value[address_start..host_end],
        .separator = separator,
        .number = number,
        .screen = screen,
    };
}
