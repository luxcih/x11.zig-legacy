//! Description of an X11 visual.
//!
//! A visual defines how pixel values are interpreted, including its class,
//! component masks, color precision, and colormap characteristics.

const std = @import("std");
const Wire = @import("Wire.zig");
const Endian = std.builtin.Endian;

const VisualType = @This();
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
    endian: Endian,
) ParseError!VisualType {
    if (bytes.len < size) return error.BufferTooShort;

    const class: Class = switch (bytes[4]) {
        0 => .static_gray,
        1 => .gray_scale,
        2 => .static_color,
        3 => .pseudo_color,
        4 => .true_color,
        5 => .direct_color,
        else => return error.InvalidClass,
    };

    return .{
        .visual_id = Wire.readU32(bytes[0..4], endian),
        .class = class,
        .bits_per_rgb_value = bytes[5],
        .colormap_entries = Wire.readU16(bytes[6..8], endian),
        .red_mask = Wire.readU32(bytes[8..12], endian),
        .green_mask = Wire.readU32(bytes[12..16], endian),
        .blue_mask = Wire.readU32(bytes[16..20], endian),
    };
}

test "parse little-endian true color visual" {
    const visual = try VisualType.parse(&.{
        0x21, 0x43, 0x65, 0x87,
        4,    8,    0x00, 0x01,
        0x00, 0x00, 0xff, 0x00,
        0x00, 0xff, 0x00, 0x00,
        0xff, 0x00, 0x00, 0x00,
        0,    0,    0,    0,
    }, .little);

    try std.testing.expectEqual(@as(u32, 0x87654321), visual.visual_id);
    try std.testing.expectEqual(VisualType.Class.true_color, visual.class);
    try std.testing.expectEqual(@as(u8, 8), visual.bits_per_rgb_value);
    try std.testing.expectEqual(@as(u16, 256), visual.colormap_entries);
    try std.testing.expectEqual(@as(u32, 0x00ff0000), visual.red_mask);
    try std.testing.expectEqual(@as(u32, 0x0000ff00), visual.green_mask);
    try std.testing.expectEqual(@as(u32, 0x000000ff), visual.blue_mask);
}

test "parse big-endian true color visual" {
    const visual = try VisualType.parse(&.{
        0x87, 0x65, 0x43, 0x21, 4,    8,    0x01, 0x00,
        0x00, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0x00,
        0x00, 0x00, 0x00, 0xff, 0,    0,    0,    0,
    }, .big);
    try std.testing.expectEqual(@as(u32, 0x87654321), visual.visual_id);
    try std.testing.expectEqual(@as(u16, 256), visual.colormap_entries);
    try std.testing.expectEqual(@as(u32, 0x00ff0000), visual.red_mask);
}
