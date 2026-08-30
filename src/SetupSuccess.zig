const std = @import("std");
const Setup = @import("Setup.zig").Setup;

pub const SetupSuccess = struct {
    pub const ParseError = error{
        BodyTooShort,
        VendorOutOfBounds,
    };

    release_number: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    vendor: []const u8,
    maximum_request_length: u16,
    screen_count: u8,
    pixmap_format_count: u8,
    image_byte_order: u8,
    bitmap_bit_order: u8,
    bitmap_scanline_unit: u8,
    bitmap_scanline_pad: u8,
    min_keycode: u8,
    max_keycode: u8,

    pub fn parse(
        body: []const u8,
        byte_order: Setup.ByteOrder,
    ) ParseError!SetupSuccess {
        if (body.len < 32) return error.BodyTooShort;

        const vendor_length = readU16(body[16..18], byte_order);
        const vendor_end = 32 + @as(usize, vendor_length);

        if (vendor_end > body.len) return error.VendorOutOfBounds;

        return .{
            .release_number = readU32(body[0..4], byte_order),
            .resource_id_base = readU32(body[4..8], byte_order),
            .resource_id_mask = readU32(body[8..12], byte_order),
            .motion_buffer_size = readU32(body[12..16], byte_order),
            .vendor = body[32..vendor_end],
            .maximum_request_length = readU16(body[18..20], byte_order),
            .screen_count = body[20],
            .pixmap_format_count = body[21],
            .image_byte_order = body[22],
            .bitmap_bit_order = body[23],
            .bitmap_scanline_unit = body[24],
            .bitmap_scanline_pad = body[25],
            .min_keycode = body[26],
            .max_keycode = body[27],
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

test "parse little-endian setup success header" {
    const body = [_]u8{
        0x78, 0x56, 0x34, 0x12,
        0x10, 0x00, 0x00, 0x20,
        0xff, 0x00, 0x00, 0x00,
        0x40, 0x00, 0x00, 0x00,
        3, 0,
        0x00, 0x10,
        1,
        2,
        0,
        1,
        32,
        0,
        32,
        8,
        255,
        0, 0, 0,
        'X', 'o', 'r',
    };

    const success = try SetupSuccess.parse(&body, .little);

    try std.testing.expectEqual(@as(u32, 0x12345678), success.release_number);
    try std.testing.expectEqual(@as(u32, 0x20000010), success.resource_id_base);
    try std.testing.expectEqual(@as(u16, 0x1000), success.maximum_request_length);
    try std.testing.expectEqualStrings("Xor", success.vendor);
    try std.testing.expectEqual(@as(u8, 1), success.screen_count);
    try std.testing.expectEqual(@as(u8, 2), success.pixmap_format_count);
}
