const std = @import("std");
const Setup = @import("Setup.zig").Setup;

pub const VisualType = struct {
    pub const ParseError = error{
        BufferTooShort,
        InvalidClass,
    };

    pub const Class = enum(u8) {
        static_gray = 0,
        gray_scale = 1,
        static_color = 2,
        pseudo_color = 3,
        true_color = 4,
        direct_color = 5,
    };

    visual_id: u32,
    class: Class,
    bits_per_rgb_value: u8,
    colormap_entries: u16,
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,

    pub const size = 24;

    pub fn parse(
        bytes: []const u8,
        byte_order: Setup.ByteOrder,
    ) ParseError!VisualType {
        if (bytes.len < size) return error.BufferTooShort;

        const class = std.meta.intToEnum(Class, bytes[4]) catch
            return error.InvalidClass;

        return .{
            .visual_id = readU32(bytes[0..4], byte_order),
            .class = class,
            .bits_per_rgb_value = bytes[5],
            .colormap_entries = readU16(bytes[6..8], byte_order),
            .red_mask = readU32(bytes[8..12], byte_order),
            .green_mask = readU32(bytes[12..16], byte_order),
            .blue_mask = readU32(bytes[16..20], byte_order),
        };
    }

    fn readU16(bytes: []const u8, byte_order: Setup.ByteOrder) u16 {
        return switch (byte_order) {
            .little => @as(u16, bytes[0]) |
                (@as(u16, bytes[1]) << 8),
            .big => (@as(u16, bytes[0]) << 8) |
                @as(u16, bytes[1]),
        };
    }

    fn readU32(bytes: []const u8, byte_order: Setup.ByteOrder) u32 {
        return switch (byte_order) {
            .little => @as(u32, bytes[0]) |
                (@as(u32, bytes[1]) << 8) |
                (@as(u32, bytes[2]) << 16) |
                (@as(u32, bytes[3]) << 24),
            .big => (@as(u32, bytes[0]) << 24) |
                (@as(u32, bytes[1]) << 16) |
                (@as(u32, bytes[2]) << 8) |
                @as(u32, bytes[3]),
        };
    }
};

test "parse little-endian true color visual" {
    const visual = try VisualType.parse(&.{
        0x21, 0x43, 0x65, 0x87,
        4,
        8,
        0x00, 0x01,
        0x00, 0x00, 0xff, 0x00,
        0x00, 0xff, 0x00, 0x00,
        0xff, 0x00, 0x00, 0x00,
        0, 0, 0, 0,
    }, .little);

    try std.testing.expectEqual(@as(u32, 0x87654321), visual.visual_id);
    try std.testing.expectEqual(VisualType.Class.true_color, visual.class);
    try std.testing.expectEqual(@as(u8, 8), visual.bits_per_rgb_value);
    try std.testing.expectEqual(@as(u16, 256), visual.colormap_entries);
    try std.testing.expectEqual(@as(u32, 0x00ff0000), visual.red_mask);
    try std.testing.expectEqual(@as(u32, 0x0000ff00), visual.green_mask);
    try std.testing.expectEqual(@as(u32, 0x000000ff), visual.blue_mask);
}
