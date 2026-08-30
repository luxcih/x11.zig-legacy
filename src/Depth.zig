const std = @import("std");
const Setup = @import("Setup.zig").Setup;
const Wire = @import("Wire.zig");

pub const Depth = struct {
    pub const ParseError = error{
        BufferTooShort,
    };

    depth: u8,
    visual_count: u16,

    pub const size = 8;

    pub fn parse(
        bytes: []const u8,
        byte_order: Setup.ByteOrder,
    ) ParseError!Depth {
        if (bytes.len < size) return error.BufferTooShort;

        return .{
            .depth = bytes[0],
            .visual_count = Wire.readU16(bytes[2..4], byte_order),
        };
    }

    pub fn visualsOffset(self: Depth) usize {
        _ = self;
        return size;
    }

    pub fn visualsLength(self: Depth) usize {
        return @as(usize, self.visual_count) * 24;
    }

    pub fn totalLength(self: Depth) usize {
        return self.visualsOffset() + self.visualsLength();
    }
};

test "parse little-endian depth" {
    const depth = try Depth.parse(
        &.{ 24, 0, 3, 0, 0, 0, 0, 0 },
        .little,
    );

    try std.testing.expectEqual(@as(u8, 24), depth.depth);
    try std.testing.expectEqual(@as(u16, 3), depth.visual_count);
    try std.testing.expectEqual(@as(usize, 72), depth.visualsLength());
    try std.testing.expectEqual(@as(usize, 80), depth.totalLength());
}
