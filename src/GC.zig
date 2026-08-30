const std = @import("std");
const Wire = @import("Wire.zig");
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

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
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            const length = self.encodedLength();
            if (buffer.len < length)
                return error.BufferTooSmall;

            var value_mask: u32 = 0;
            var offset: usize = size;

            if (self.foreground) |foreground| {
                value_mask |= 1 << 2;
                Wire.writeU32(buffer[offset .. offset + 4], foreground, byte_order);
                offset += 4;
            }

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.gc_id, byte_order);
            Wire.writeU32(buffer[8..12], self.drawable, byte_order);
            Wire.writeU32(buffer[12..16], value_mask, byte_order);

            return buffer[0..offset];
        }
    };

    pub const Change = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 56;
        pub const base_size: usize = 12;

        gc_id: u32,
        foreground: ?u32 = null,
        background: ?u32 = null,
        line_width: ?u32 = null,

        pub fn encodedLength(self: Change) usize {
            var length = base_size;
            if (self.foreground != null) length += 4;
            if (self.background != null) length += 4;
            if (self.line_width != null) length += 4;
            return length;
        }

        pub fn encode(
            self: Change,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            const length = self.encodedLength();
            if (buffer.len < length)
                return error.BufferTooSmall;

            var value_mask: u32 = 0;
            var offset: usize = base_size;

            if (self.background) |background| {
                value_mask |= 1 << 3;
                Wire.writeU32(buffer[offset .. offset + 4], background, byte_order);
                offset += 4;
            }

            if (self.foreground) |foreground| {
                value_mask |= 1 << 2;
                Wire.writeU32(buffer[offset .. offset + 4], foreground, byte_order);
                offset += 4;
            }

            if (self.line_width) |line_width| {
                value_mask |= 1 << 4;
                Wire.writeU32(buffer[offset .. offset + 4], line_width, byte_order);
                offset += 4;
            }

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.gc_id, byte_order);
            Wire.writeU32(buffer[8..12], value_mask, byte_order);

            return buffer[0..offset];
        }
    };


    pub const Free = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 60;
        pub const size: usize = 8;

        gc_id: u32,

        pub fn encode(
            self: Free,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size)
                return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.gc_id, byte_order);

            return buffer[0..size];
        }
    };

};

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

test "encode little-endian ChangeGC values" {
    const request = GC.Change{
        .gc_id = 0x05060708,
        .foreground = 0x00ff00,
        .background = 0x0000ff,
        .line_width = 3,
    };

    var buffer: [24]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        56, 0,
        6, 0,
        8, 7, 6, 5,
        28, 0, 0, 0,
        0, 255, 0, 0,
        255, 0, 0, 0,
        3, 0, 0, 0,
    }, encoded);
}


test "encode little-endian FreeGC request" {
    const request = GC.Free{
        .gc_id = 0x05060708,
    };

    var buffer: [GC.Free.size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        60, 0,
        2, 0,
        8, 7, 6, 5,
    }, encoded);
}
