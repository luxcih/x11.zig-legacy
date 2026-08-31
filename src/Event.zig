//! Parsing of asynchronous X11 events.
//!
//! Events are 32-byte server-to-client notifications generated independently of
//! a specific request, such as input activity, exposure, and window changes.

const std = @import("std");
const Wire = @import("Wire.zig");
const Endian = std.builtin.Endian;

pub const Event = union(enum) {
    key_press: Key,
    key_release: Key,
    button_press: Button,
    button_release: Button,
    motion_notify: Motion,
    expose: Expose,
    destroy_notify: DestroyNotify,
    unmap_notify: UnmapNotify,
    map_notify: MapNotify,
    configure_notify: ConfigureNotify,
    unknown: Unknown,

    pub const ParseError = error{
        InvalidLength,
    };

    pub const Input = struct {
        detail: u8,
        time: u32,
        root: u32,
        event: u32,
        child: u32,
        root_x: i16,
        root_y: i16,
        event_x: i16,
        event_y: i16,
        state: u16,
        same_screen: bool,
    };

    pub const Key = Input;
    pub const Button = Input;
    pub const Motion = Input;

    pub const Expose = struct {
        window: u32,
        x: i16,
        y: i16,
        width: u16,
        height: u16,
        count: u16,
    };

    pub const DestroyNotify = struct {
        event: u32,
        window: u32,
    };

    pub const UnmapNotify = struct {
        event: u32,
        window: u32,
        from_configure: bool,
    };

    pub const MapNotify = struct {
        event: u32,
        window: u32,
        override_redirect: bool,
    };

    pub const ConfigureNotify = struct {
        event: u32,
        window: u32,
        above_sibling: u32,
        x: i16,
        y: i16,
        width: u16,
        height: u16,
        border_width: u16,
        override_redirect: bool,
    };

    pub const Unknown = struct {
        response_type: u8,
        raw: [32]u8,
    };

    /// Parses one complete 32-byte X11 event while preserving unknown event types.
    pub fn parse(bytes: []const u8, endian: Endian) ParseError!Event {
        if (bytes.len != 32)
            return error.InvalidLength;

        const response_type = bytes[0] & 0x7f;

        return switch (response_type) {
            2 => .{ .key_press = parseInput(bytes, endian) },
            3 => .{ .key_release = parseInput(bytes, endian) },
            4 => .{ .button_press = parseInput(bytes, endian) },
            5 => .{ .button_release = parseInput(bytes, endian) },
            6 => .{ .motion_notify = parseInput(bytes, endian) },
            12 => .{ .expose = .{
                .window = Wire.readU32(bytes[4..8], endian),
                .x = @bitCast(Wire.readU16(bytes[8..10], endian)),
                .y = @bitCast(Wire.readU16(bytes[10..12], endian)),
                .width = Wire.readU16(bytes[12..14], endian),
                .height = Wire.readU16(bytes[14..16], endian),
                .count = Wire.readU16(bytes[16..18], endian),
            } },
            17 => .{ .destroy_notify = .{
                .event = Wire.readU32(bytes[4..8], endian),
                .window = Wire.readU32(bytes[8..12], endian),
            } },
            18 => .{ .unmap_notify = .{
                .event = Wire.readU32(bytes[4..8], endian),
                .window = Wire.readU32(bytes[8..12], endian),
                .from_configure = bytes[12] != 0,
            } },
            19 => .{ .map_notify = .{
                .event = Wire.readU32(bytes[4..8], endian),
                .window = Wire.readU32(bytes[8..12], endian),
                .override_redirect = bytes[12] != 0,
            } },
            22 => .{ .configure_notify = .{
                .event = Wire.readU32(bytes[4..8], endian),
                .window = Wire.readU32(bytes[8..12], endian),
                .above_sibling = Wire.readU32(bytes[12..16], endian),
                .x = @bitCast(Wire.readU16(bytes[16..18], endian)),
                .y = @bitCast(Wire.readU16(bytes[18..20], endian)),
                .width = Wire.readU16(bytes[20..22], endian),
                .height = Wire.readU16(bytes[22..24], endian),
                .border_width = Wire.readU16(bytes[24..26], endian),
                .override_redirect = bytes[26] != 0,
            } },
            else => .{ .unknown = .{
                .response_type = response_type,
                .raw = bytes[0..32].*,
            } },
        };
    }

    fn parseInput(
        bytes: []const u8,
        endian: Endian,
    ) Input {
        return .{
            .detail = bytes[1],
            .time = Wire.readU32(bytes[4..8], endian),
            .root = Wire.readU32(bytes[8..12], endian),
            .event = Wire.readU32(bytes[12..16], endian),
            .child = Wire.readU32(bytes[16..20], endian),
            .root_x = @bitCast(Wire.readU16(bytes[20..22], endian)),
            .root_y = @bitCast(Wire.readU16(bytes[22..24], endian)),
            .event_x = @bitCast(Wire.readU16(bytes[24..26], endian)),
            .event_y = @bitCast(Wire.readU16(bytes[26..28], endian)),
            .state = Wire.readU16(bytes[28..30], endian),
            .same_screen = bytes[30] != 0,
        };
    }
};

test "parse big-endian input and configure events" {
    {
        const event = try Event.parse(&.{
            0x82, 38, 0,   0,
            1,    2,  3,   4,
            5,    6,  7,   8,
            9,    10, 11,  12,
            13,   14, 15,  16,
            0,    10, 255, 236,
            0,    30, 0,   40,
            0,    1,  1,   0,
        }, .big);

        switch (event) {
            .key_press => |key| {
                try std.testing.expectEqual(@as(u8, 38), key.detail);
                try std.testing.expectEqual(@as(u32, 0x01020304), key.time);
                try std.testing.expectEqual(@as(i16, -20), key.root_y);
                try std.testing.expect(key.same_screen);
            },
            else => return error.UnexpectedEvent,
        }
    }

    {
        const event = try Event.parse(&.{
            22, 0,   0,   0,
            1,  2,   3,   4,
            5,  6,   7,   8,
            9,  10,  11,  12,
            0,  10,  255, 236,
            2,  128, 1,   224,
            0,  5,   1,   0,
            0,  0,   0,   0,
        }, .big);

        switch (event) {
            .configure_notify => |configure| {
                try std.testing.expectEqual(@as(u32, 0x01020304), configure.event);
                try std.testing.expectEqual(@as(u32, 0x05060708), configure.window);
                try std.testing.expectEqual(@as(i16, 10), configure.x);
                try std.testing.expectEqual(@as(i16, -20), configure.y);
                try std.testing.expectEqual(@as(u16, 640), configure.width);
                try std.testing.expect(configure.override_redirect);
            },
            else => return error.UnexpectedEvent,
        }
    }
}

test "parse unknown event preserving raw bytes" {
    const event = try Event.parse(&.{
        99, 7, 0, 0,
        1,  2, 3, 4,
        0,  0, 0, 0,
        0,  0, 0, 0,
        0,  0, 0, 0,
        0,  0, 0, 0,
        0,  0, 0, 0,
        0,  0, 0, 0,
    }, .little);

    switch (event) {
        .unknown => |unknown| {
            try std.testing.expectEqual(@as(u8, 99), unknown.response_type);
            try std.testing.expectEqual(@as(u8, 7), unknown.raw[1]);
        },
        else => return error.UnexpectedEvent,
    }
}

test "parse little-endian expose event" {
    const event = try Event.parse(&.{
        12,  0, 0,   0,
        4,   3, 2,   1,
        10,  0, 20,  0,
        128, 2, 224, 1,
        0,   0, 0,   0,
        0,   0, 0,   0,
        0,   0, 0,   0,
        0,   0, 0,   0,
    }, .little);

    switch (event) {
        .expose => |expose| {
            try std.testing.expectEqual(@as(u32, 0x01020304), expose.window);
            try std.testing.expectEqual(@as(i16, 10), expose.x);
            try std.testing.expectEqual(@as(i16, 20), expose.y);
            try std.testing.expectEqual(@as(u16, 640), expose.width);
            try std.testing.expectEqual(@as(u16, 480), expose.height);
        },
        else => return error.UnexpectedEvent,
    }
}

test "parse little-endian key press event" {
    const event = try Event.parse(&.{
        2,  38, 0,  0,
        4,  3,  2,  1,
        8,  7,  6,  5,
        12, 11, 10, 9,
        16, 15, 14, 13,
        10, 0,  20, 0,
        30, 0,  40, 0,
        1,  0,  1,  0,
    }, .little);

    switch (event) {
        .key_press => |key| {
            try std.testing.expectEqual(@as(u8, 38), key.detail);
            try std.testing.expectEqual(@as(u32, 0x01020304), key.time);
            try std.testing.expectEqual(@as(i16, 10), key.root_x);
            try std.testing.expectEqual(@as(i16, 40), key.event_y);
            try std.testing.expectEqual(@as(u16, 1), key.state);
            try std.testing.expect(key.same_screen);
        },
        else => return error.UnexpectedEvent,
    }
}
