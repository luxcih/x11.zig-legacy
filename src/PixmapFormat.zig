const std = @import("std");

pub const PixmapFormat = struct {
    pub const ParseError = error{
        BufferTooShort,
    };

    depth: u8,
    bits_per_pixel: u8,
    scanline_pad: u8,

    pub const size = 8;

    pub fn parse(bytes: []const u8) ParseError!PixmapFormat {
        if (bytes.len < size) return error.BufferTooShort;

        return .{
            .depth = bytes[0],
            .bits_per_pixel = bytes[1],
            .scanline_pad = bytes[2],
        };
    }
};

test "parse pixmap format" {
    const format = try PixmapFormat.parse(&.{
        24,
        32,
        32,
        0, 0, 0, 0, 0,
    });

    try std.testing.expectEqual(@as(u8, 24), format.depth);
    try std.testing.expectEqual(@as(u8, 32), format.bits_per_pixel);
    try std.testing.expectEqual(@as(u8, 32), format.scanline_pad);
}
