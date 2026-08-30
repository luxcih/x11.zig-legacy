const std = @import("std");

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

    pub const Button = struct {
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

    pub const Motion = struct {
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

    pub const Key = struct {
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

    pub fn parse(bytes: []const u8, byte_order: @import("Setup.zig").Setup.ByteOrder) ParseError!Event {
        if (bytes.len < 32)
            return error.InvalidLength;

        const response_type = bytes[0] & 0x7f;

        return switch (response_type) {
            2 => .{ .key_press = parseKey(bytes, byte_order) },
            3 => .{ .key_release = parseKey(bytes, byte_order) },
            4 => .{ .button_press = parseButton(bytes, byte_order) },
            5 => .{ .button_release = parseButton(bytes, byte_order) },
            6 => .{ .motion_notify = parseMotion(bytes, byte_order) },
            12 => .{ .expose = .{
                .window = readU32(bytes[4..8], byte_order),
                .x = @bitCast(readU16(bytes[8..10], byte_order)),
                .y = @bitCast(readU16(bytes[10..12], byte_order)),
                .width = readU16(bytes[12..14], byte_order),
                .height = readU16(bytes[14..16], byte_order),
                .count = readU16(bytes[16..18], byte_order),
            } },
            17 => .{ .destroy_notify = .{
                .event = readU32(bytes[4..8], byte_order),
                .window = readU32(bytes[8..12], byte_order),
            } },
            18 => .{ .unmap_notify = .{
                .event = readU32(bytes[4..8], byte_order),
                .window = readU32(bytes[8..12], byte_order),
                .from_configure = bytes[12] != 0,
            } },
            19 => .{ .map_notify = .{
                .event = readU32(bytes[4..8], byte_order),
                .window = readU32(bytes[8..12], byte_order),
                .override_redirect = bytes[12] != 0,
            } },
            22 => .{ .configure_notify = .{
                .event = readU32(bytes[4..8], byte_order),
                .window = readU32(bytes[8..12], byte_order),
                .above_sibling = readU32(bytes[12..16], byte_order),
                .x = @bitCast(readU16(bytes[16..18], byte_order)),
                .y = @bitCast(readU16(bytes[18..20], byte_order)),
                .width = readU16(bytes[20..22], byte_order),
                .height = readU16(bytes[22..24], byte_order),
                .border_width = readU16(bytes[24..26], byte_order),
                .override_redirect = bytes[26] != 0,
            } },
            else => .{ .unknown = .{
                .response_type = response_type,
                .raw = bytes[0..32].*,
            } },
        };
    }

    fn parseButton(bytes: []const u8, byte_order: @import("Setup.zig").Setup.ByteOrder) Button {
        return .{
            .detail = bytes[1],
            .time = readU32(bytes[4..8], byte_order),
            .root = readU32(bytes[8..12], byte_order),
            .event = readU32(bytes[12..16], byte_order),
            .child = readU32(bytes[16..20], byte_order),
            .root_x = @bitCast(readU16(bytes[20..22], byte_order)),
            .root_y = @bitCast(readU16(bytes[22..24], byte_order)),
            .event_x = @bitCast(readU16(bytes[24..26], byte_order)),
            .event_y = @bitCast(readU16(bytes[26..28], byte_order)),
            .state = readU16(bytes[28..30], byte_order),
            .same_screen = bytes[30] != 0,
        };
    }

    fn parseMotion(bytes: []const u8, byte_order: @import("Setup.zig").Setup.ByteOrder) Motion {
        return .{
            .detail = bytes[1],
            .time = readU32(bytes[4..8], byte_order),
            .root = readU32(bytes[8..12], byte_order),
            .event = readU32(bytes[12..16], byte_order),
            .child = readU32(bytes[16..20], byte_order),
            .root_x = @bitCast(readU16(bytes[20..22], byte_order)),
            .root_y = @bitCast(readU16(bytes[22..24], byte_order)),
            .event_x = @bitCast(readU16(bytes[24..26], byte_order)),
            .event_y = @bitCast(readU16(bytes[26..28], byte_order)),
            .state = readU16(bytes[28..30], byte_order),
            .same_screen = bytes[30] != 0,
        };
    }

    fn parseKey(bytes: []const u8, byte_order: @import("Setup.zig").Setup.ByteOrder) Key {
        return .{
            .detail = bytes[1],
            .time = readU32(bytes[4..8], byte_order),
            .root = readU32(bytes[8..12], byte_order),
            .event = readU32(bytes[12..16], byte_order),
            .child = readU32(bytes[16..20], byte_order),
            .root_x = @bitCast(readU16(bytes[20..22], byte_order)),
            .root_y = @bitCast(readU16(bytes[22..24], byte_order)),
            .event_x = @bitCast(readU16(bytes[24..26], byte_order)),
            .event_y = @bitCast(readU16(bytes[26..28], byte_order)),
            .state = readU16(bytes[28..30], byte_order),
            .same_screen = bytes[30] != 0,
        };
    }

    fn readU16(bytes: []const u8, byte_order: @import("Setup.zig").Setup.ByteOrder) u16 {
        return switch (byte_order) {
            .little => std.mem.readInt(u16, bytes[0..2], .little),
            .big => std.mem.readInt(u16, bytes[0..2], .big),
        };
    }

    fn readU32(bytes: []const u8, byte_order: @import("Setup.zig").Setup.ByteOrder) u32 {
        return switch (byte_order) {
            .little => std.mem.readInt(u32, bytes[0..4], .little),
            .big => std.mem.readInt(u32, bytes[0..4], .big),
        };
    }
};

test "parse little-endian expose event" {
    const event = try Event.parse(&.{
        12, 0, 0, 0,
        4, 3, 2, 1,
        10, 0,
        20, 0,
        128, 2,
        224, 1,
        0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
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
        2, 38, 0, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
        12, 11, 10, 9,
        16, 15, 14, 13,
        10, 0,
        20, 0,
        30, 0,
        40, 0,
        1, 0,
        1,
        0,
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
