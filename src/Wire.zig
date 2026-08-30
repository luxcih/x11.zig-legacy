const Setup = @import("Setup.zig").Setup;

pub const ByteOrder = Setup.ByteOrder;

pub fn writeU16(bytes: []u8, value: u16, byte_order: ByteOrder) void {
    switch (byte_order) {
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

pub fn writeI16(bytes: []u8, value: i16, byte_order: ByteOrder) void {
    writeU16(bytes, @bitCast(value), byte_order);
}

pub fn writeU32(bytes: []u8, value: u32, byte_order: ByteOrder) void {
    switch (byte_order) {
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

pub fn readU16(bytes: []const u8, byte_order: ByteOrder) u16 {
    return switch (byte_order) {
        .little => @as(u16, bytes[0]) |
            (@as(u16, bytes[1]) << 8),
        .big => (@as(u16, bytes[0]) << 8) |
            @as(u16, bytes[1]),
    };
}

pub fn readU32(bytes: []const u8, byte_order: ByteOrder) u32 {
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
