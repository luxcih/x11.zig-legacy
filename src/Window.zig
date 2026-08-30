const std = @import("std");
const Setup = @import("Setup.zig").Setup;

pub const Window = struct {
    pub const Create = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 1;
        pub const size: usize = 32;

        depth: u8,
        window_id: u32,
        parent: u32,
        x: i16 = 0,
        y: i16 = 0,
        width: u16,
        height: u16,
        border_width: u16 = 0,
        class: Class = .input_output,
        visual: u32 = 0,
        background_pixel: ?u32 = null,

        pub const Class = enum(u16) {
            copy_from_parent = 0,
            input_output = 1,
            input_only = 2,
        };

        pub fn encodedLength(self: Create) usize {
            return size + if (self.background_pixel != null) @as(usize, 4) else 0;
        }

        pub fn encode(
            self: Create,
            buffer: []u8,
            byte_order: Setup.ByteOrder,
        ) EncodeError![]const u8 {
            const length = self.encodedLength();
            if (buffer.len < length) return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = self.depth;
            writeU16(buffer[2..4], @intCast(length / 4), byte_order);
            writeU32(buffer[4..8], self.window_id, byte_order);
            writeU32(buffer[8..12], self.parent, byte_order);
            writeI16(buffer[12..14], self.x, byte_order);
            writeI16(buffer[14..16], self.y, byte_order);
            writeU16(buffer[16..18], self.width, byte_order);
            writeU16(buffer[18..20], self.height, byte_order);
            writeU16(buffer[20..22], self.border_width, byte_order);
            writeU16(buffer[22..24], @intFromEnum(self.class), byte_order);
            writeU32(buffer[24..28], self.visual, byte_order);
            var offset: usize = size;
            var value_mask: u32 = 0;

            if (self.background_pixel) |pixel| {
                value_mask |= 1 << 1;
                writeU32(buffer[offset .. offset + 4], pixel, byte_order);
                offset += 4;
            }

            writeU32(buffer[28..32], value_mask, byte_order);

            return buffer[0..offset];
        }

        fn writeU16(buffer: []u8, value: u16, byte_order: Setup.ByteOrder) void {
            switch (byte_order) {
                .little => {
                    buffer[0] = @truncate(value);
                    buffer[1] = @truncate(value >> 8);
                },
                .big => {
                    buffer[0] = @truncate(value >> 8);
                    buffer[1] = @truncate(value);
                },
            }
        }

        fn writeI16(buffer: []u8, value: i16, byte_order: Setup.ByteOrder) void {
            writeU16(buffer, @bitCast(value), byte_order);
        }

        fn writeU32(buffer: []u8, value: u32, byte_order: Setup.ByteOrder) void {
            switch (byte_order) {
                .little => {
                    buffer[0] = @truncate(value);
                    buffer[1] = @truncate(value >> 8);
                    buffer[2] = @truncate(value >> 16);
                    buffer[3] = @truncate(value >> 24);
                },
                .big => {
                    buffer[0] = @truncate(value >> 24);
                    buffer[1] = @truncate(value >> 16);
                    buffer[2] = @truncate(value >> 8);
                    buffer[3] = @truncate(value);
                },
            }
        }
    };

    pub const Map = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 8;
        pub const size = 8;

        window_id: u32,

        pub fn encodedLength(self: Map) usize {
            _ = self;
            return size;
        }

        pub fn encode(
            self: Map,
            buffer: []u8,
            byte_order: Setup.ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Create.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Create.writeU32(buffer[4..8], self.window_id, byte_order);

            return buffer[0..size];
        }
    };
};

test "encode little-endian create window request" {
    const request = Window.Create{
        .depth = 24,
        .window_id = 0x01020304,
        .parent = 0x05060708,
        .x = 10,
        .y = -20,
        .width = 640,
        .height = 480,
    };

    var buffer: [Window.Create.size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqual(@as(u8, 1), encoded[0]);
    try std.testing.expectEqual(@as(u8, 24), encoded[1]);
    try std.testing.expectEqualSlices(u8, &.{ 8, 0 }, encoded[2..4]);
    try std.testing.expectEqualSlices(u8, &.{ 4, 3, 2, 1 }, encoded[4..8]);
    try std.testing.expectEqualSlices(u8, &.{ 10, 0 }, encoded[12..14]);
    try std.testing.expectEqualSlices(u8, &.{ 236, 255 }, encoded[14..16]);
}


test "encode little-endian map window request" {
    const request = Window.Map{
        .window_id = 0x01020304,
    };

    var buffer: [Window.Map.size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        8, 0,
        2, 0,
        4, 3, 2, 1,
    }, encoded);
}
