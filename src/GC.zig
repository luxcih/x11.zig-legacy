const Setup = @import("Setup.zig").Setup;

pub const GC = struct {
    pub const Create = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 55;
        pub const size: usize = 16;

        drawable: u32,
        gc_id: u32,
        foreground: ?u32 = null,

        pub fn encodedLength(self: Create) usize {
            return size + if (self.foreground != null) @as(usize, 4) else 0;
        }

        pub fn encode(
            self: Create,
            buffer: []u8,
            byte_order: Setup.ByteOrder,
        ) EncodeError![]const u8 {
            const length = self.encodedLength();
            if (buffer.len < length)
                return error.BufferTooSmall;

            var value_mask: u32 = 0;
            var offset: usize = size;

            if (self.foreground) |foreground| {
                value_mask |= 1 << 2;
                writeU32(buffer[offset .. offset + 4], foreground, byte_order);
                offset += 4;
            }

            buffer[0] = opcode;
            buffer[1] = 0;
            writeU16(buffer[2..4], @intCast(length / 4), byte_order);
            writeU32(buffer[4..8], self.gc_id, byte_order);
            writeU32(buffer[8..12], self.drawable, byte_order);
            writeU32(buffer[12..16], value_mask, byte_order);

            return buffer[0..offset];
        }
    };

    fn writeU16(bytes: []u8, value: u16, byte_order: Setup.ByteOrder) void {
        switch (byte_order) {
            .little => std.mem.writeInt(u16, bytes[0..2], value, .little),
            .big => std.mem.writeInt(u16, bytes[0..2], value, .big),
        }
    }

    fn writeU32(bytes: []u8, value: u32, byte_order: Setup.ByteOrder) void {
        switch (byte_order) {
            .little => std.mem.writeInt(u32, bytes[0..4], value, .little),
            .big => std.mem.writeInt(u32, bytes[0..4], value, .big),
        }
    }
};

const std = @import("std");

test "encode little-endian CreateGC with foreground" {
    const request = GC.Create{
        .drawable = 0x01020304,
        .gc_id = 0x05060708,
        .foreground = 0x00ff00,
    };

    var buffer: [20]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        55, 0,
        5, 0,
        8, 7, 6, 5,
        4, 3, 2, 1,
        4, 0, 0, 0,
        0, 255, 0, 0,
    }, encoded);
}
