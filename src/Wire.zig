const std = @import("std");
const Endian = std.builtin.Endian;

pub fn writeU16(bytes: []u8, value: u16, endian: Endian) void {
    switch (endian) {
        .little => {
            bytes[0] = @truncate(value);
            bytes[1] = @truncate(value >> 8);
        },
        .big => {
            bytes[0] = @truncate(value >> 8);
            bytes[1] = @truncate(value);
        },
    }
}

pub fn writeI16(bytes: []u8, value: i16, endian: Endian) void {
    writeU16(bytes, @bitCast(value), endian);
}

pub fn writeU32(bytes: []u8, value: u32, endian: Endian) void {
    switch (endian) {
        .little => {
            bytes[0] = @truncate(value);
            bytes[1] = @truncate(value >> 8);
            bytes[2] = @truncate(value >> 16);
            bytes[3] = @truncate(value >> 24);
        },
        .big => {
            bytes[0] = @truncate(value >> 24);
            bytes[1] = @truncate(value >> 16);
            bytes[2] = @truncate(value >> 8);
            bytes[3] = @truncate(value);
        },
    }
}

pub fn readU16(bytes: []const u8, endian: Endian) u16 {
    return switch (endian) {
        .little => @as(u16, bytes[0]) |
            (@as(u16, bytes[1]) << 8),
        .big => (@as(u16, bytes[0]) << 8) |
            @as(u16, bytes[1]),
    };
}

pub fn readI16(bytes: []const u8, endian: Endian) i16 {
    return @bitCast(readU16(bytes, endian));
}

pub fn readU32(bytes: []const u8, endian: Endian) u32 {
    return switch (endian) {
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


test "Wire round-trips integer primitives in both byte orders" {
    inline for (.{ Endian.little, Endian.big }) |endian| {
        var u16_bytes: [2]u8 = undefined;
        writeU16(&u16_bytes, 0x1234, endian);
        try std.testing.expectEqual(@as(u16, 0x1234), readU16(&u16_bytes, endian));

        var i16_bytes: [2]u8 = undefined;
        writeI16(&i16_bytes, -12345, endian);
        try std.testing.expectEqual(@as(i16, -12345), readI16(&i16_bytes, endian));

        var u32_bytes: [4]u8 = undefined;
        writeU32(&u32_bytes, 0x12345678, endian);
        try std.testing.expectEqual(@as(u32, 0x12345678), readU32(&u32_bytes, endian));
    }
}

test "Wire uses the expected canonical byte sequences" {
    var bytes: [4]u8 = undefined;

    writeU32(&bytes, 0x12345678, .little);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x56, 0x34, 0x12 }, &bytes);

    writeU32(&bytes, 0x12345678, .big);
    try std.testing.expectEqualSlices(u8, &.{ 0x12, 0x34, 0x56, 0x78 }, &bytes);
}
