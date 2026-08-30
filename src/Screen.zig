const std = @import("std");
const Wire = @import("Wire.zig");
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

const Screen = @This();
    pub const ParseError = error{
        BufferTooShort,
    };

    root: u32,
    default_colormap: u32,
    white_pixel: u32,
    black_pixel: u32,
    current_input_masks: u32,
    width_pixels: u16,
    height_pixels: u16,
    width_millimeters: u16,
    height_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,
    root_visual: u32,
    backing_stores: u8,
    save_unders: bool,
    root_depth: u8,
    depth_count: u8,

    pub const size = 40;

    pub fn parse(
        bytes: []const u8,
        byte_order: ByteOrder,
    ) ParseError!Screen {
        if (bytes.len < size) return error.BufferTooShort;

        return .{
            .root = Wire.readU32(bytes[0..4], byte_order),
            .default_colormap = Wire.readU32(bytes[4..8], byte_order),
            .white_pixel = Wire.readU32(bytes[8..12], byte_order),
            .black_pixel = Wire.readU32(bytes[12..16], byte_order),
            .current_input_masks = Wire.readU32(bytes[16..20], byte_order),
            .width_pixels = Wire.readU16(bytes[20..22], byte_order),
            .height_pixels = Wire.readU16(bytes[22..24], byte_order),
            .width_millimeters = Wire.readU16(bytes[24..26], byte_order),
            .height_millimeters = Wire.readU16(bytes[26..28], byte_order),
            .min_installed_maps = Wire.readU16(bytes[28..30], byte_order),
            .max_installed_maps = Wire.readU16(bytes[30..32], byte_order),
            .root_visual = Wire.readU32(bytes[32..36], byte_order),
            .backing_stores = bytes[36],
            .save_unders = bytes[37] != 0,
            .root_depth = bytes[38],
            .depth_count = bytes[39],
        };
    }

test "parse little-endian screen" {
    const screen = try Screen.parse(&.{
        1, 0, 0, 0,
        2, 0, 0, 0,
        3, 0, 0, 0,
        4, 0, 0, 0,
        5, 0, 0, 0,
        0x80, 0x02,
        0xe0, 0x01,
        100, 0,
        50, 0,
        1, 0,
        2, 0,
        9, 0, 0, 0,
        1,
        1,
        24,
        3,
    }, .little);

    try std.testing.expectEqual(@as(u32, 1), screen.root);
    try std.testing.expectEqual(@as(u16, 640), screen.width_pixels);
    try std.testing.expectEqual(@as(u16, 480), screen.height_pixels);
    try std.testing.expect(screen.save_unders);
    try std.testing.expectEqual(@as(u8, 3), screen.depth_count);
}

test "parse big-endian screen" {
    const screen = try Screen.parse(&.{
        0,0,0,1, 0,0,0,2, 0,0,0,3, 0,0,0,4,
        0,0,0,5, 2,128, 1,224, 0,100, 0,50, 0,1, 0,2,
        0,0,0,9, 1,1,24,3,
    }, .big);
    try std.testing.expectEqual(@as(u32, 1), screen.root);
    try std.testing.expectEqual(@as(u16, 640), screen.width_pixels);
    try std.testing.expectEqual(@as(u16, 480), screen.height_pixels);
}
