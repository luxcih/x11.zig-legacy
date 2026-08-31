//! Internal parser for X11 display names.
//!
//! The parser owns the display-name grammar and produces its parsed fields.

const std = @import("std");

const Parser = @This();

value: []const u8,
index: usize = 0,

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

pub fn parse(self: *Parser) Error!Result {
    if (self.value.len == 0) return error.InvalidDisplay;

    const protocol = try self.parseProtocol();
    const host = try self.parseHost();
    const separator = try self.parseSeparator();
    const number = try self.parseNumber();
    const screen = try self.parseScreen();

    if (self.index != self.value.len) return error.InvalidDisplay;

    return .{
        .protocol = protocol,
        .host = host,
        .separator = separator,
        .number = number,
        .screen = screen,
    };
}

fn parseProtocol(self: *Parser) Error!?[]const u8 {
    const slash = std.mem.findScalar(u8, self.value[self.index..], '/');
    const colon = std.mem.findScalar(u8, self.value[self.index..], ':');

    const slash_index = slash orelse return null;
    const colon_index = colon orelse return error.InvalidDisplay;

    if (slash_index > colon_index) return null;
    if (slash_index == 0) return error.InvalidDisplay;

    const end = self.index + slash_index;
    self.index = end + 1;

    return self.value[0..end];
}

fn parseHost(self: *Parser) Error![]const u8 {
    const colon = std.mem.findScalar(u8, self.value[self.index..], ':') orelse {
        return error.InvalidDisplay;
    };

    const end = self.index + colon;
    const host = self.value[self.index..end];

    if (self.index != 0 and host.len == 0) {
        return error.InvalidDisplay;
    }

    self.index = end;
    return host;
}

fn parseSeparator(self: *Parser) Error!Separator {
    if (self.index >= self.value.len or self.value[self.index] != ':') {
        return error.InvalidDisplay;
    }

    self.index += 1;

    if (self.index < self.value.len and self.value[self.index] == ':') {
        self.index += 1;
        return .double_colon;
    }

    return .colon;
}

fn parseNumber(self: *Parser) Error!u32 {
    const start = self.index;

    while (self.index < self.value.len and self.value[self.index] != '.') {
        self.index += 1;
    }

    const number = self.value[start..self.index];
    if (number.len == 0) return error.InvalidDisplay;

    return std.fmt.parseInt(u32, number, 10) catch {
        return error.InvalidDisplay;
    };
}

fn parseScreen(self: *Parser) Error!u32 {
    if (self.index == self.value.len) return 0;

    if (self.value[self.index] != '.') return error.InvalidDisplay;

    self.index += 1;

    const screen = self.value[self.index..];
    if (screen.len == 0) return error.InvalidDisplay;

    self.index = self.value.len;

    return std.fmt.parseInt(u32, screen, 10) catch {
        return error.InvalidDisplay;
    };
}
