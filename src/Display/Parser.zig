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
    if (self.value.len == 0) return error.InvalidDisplay;

    const address_start = try self.parseProtocol();
    const separator_index = try self.findSeparator(address_start);

    return .{
        .protocol = self.protocol(address_start),
        .host = try self.parseHost(address_start, separator_index),
        .separator = self.parseSeparator(separator_index),
        .number = try self.parseNumber(separator_index),
        .screen = try self.parseScreen(separator_index),
    };
}

fn parseProtocol(self: Parser) Error!usize {
    const slash = std.mem.findScalar(u8, self.value, '/') orelse return 0;

    if (slash == 0) return error.InvalidDisplay;

    return slash + 1;
}

fn protocol(self: Parser, address_start: usize) ?[]const u8 {
    if (address_start == 0) return null;
    return self.value[0 .. address_start - 1];
}

fn findSeparator(self: Parser, address_start: usize) Error!usize {
    return address_start + (std.mem.findScalar(
        u8,
        self.value[address_start..],
        ':',
    ) orelse return error.InvalidDisplay);
}

fn parseHost(
    self: Parser,
    address_start: usize,
    separator_index: usize,
) Error![]const u8 {
    const host = self.value[address_start..separator_index];

    if (address_start != 0 and host.len == 0) {
        return error.InvalidDisplay;
    }

    return host;
}

fn parseSeparator(self: Parser, separator_index: usize) Separator {
    return if (
        separator_index + 1 < self.value.len and
        self.value[separator_index + 1] == ':'
    )
        .double_colon
    else
        .colon;
}

fn numberStart(
    self: Parser,
    separator_index: usize,
) usize {
    return separator_index + switch (self.parseSeparator(separator_index)) {
        .colon => 1,
        .double_colon => 2,
    };
}

fn parseNumber(self: Parser, separator_index: usize) Error!u32 {
    const number_start = self.numberStart(separator_index);
    const dot = std.mem.findScalar(u8, self.value[number_start..], '.');
    const number_end = if (dot) |index| number_start + index else self.value.len;
    const number_slice = self.value[number_start..number_end];

    if (number_slice.len == 0) return error.InvalidDisplay;

    return std.fmt.parseInt(u32, number_slice, 10) catch {
        return error.InvalidDisplay;
    };
}

fn parseScreen(self: Parser, separator_index: usize) Error!u32 {
    const number_start = self.numberStart(separator_index);
    const dot = std.mem.findScalar(u8, self.value[number_start..], '.') orelse {
        return 0;
    };

    const screen_start = number_start + dot + 1;
    const screen_slice = self.value[screen_start..];

    if (screen_slice.len == 0) return error.InvalidDisplay;

    return std.fmt.parseInt(u32, screen_slice, 10) catch {
        return error.InvalidDisplay;
    };
}
