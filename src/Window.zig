const std = @import("std");
const Wire = @import("Wire.zig");
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

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
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            const length = self.encodedLength();
            if (buffer.len < length) return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = self.depth;
            Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.window_id, byte_order);
            Wire.writeU32(buffer[8..12], self.parent, byte_order);
            Wire.writeI16(buffer[12..14], self.x, byte_order);
            Wire.writeI16(buffer[14..16], self.y, byte_order);
            Wire.writeU16(buffer[16..18], self.width, byte_order);
            Wire.writeU16(buffer[18..20], self.height, byte_order);
            Wire.writeU16(buffer[20..22], self.border_width, byte_order);
            Wire.writeU16(buffer[22..24], @intFromEnum(self.class), byte_order);
            Wire.writeU32(buffer[24..28], self.visual, byte_order);
            var offset: usize = size;
            var value_mask: u32 = 0;

            if (self.background_pixel) |pixel| {
                value_mask |= 1 << 1;
                Wire.writeU32(buffer[offset .. offset + 4], pixel, byte_order);
                offset += 4;
            }

            Wire.writeU32(buffer[28..32], value_mask, byte_order);

            return buffer[0..offset];
        }

    };

    pub const ChangeAttributes = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 2;
        pub const event_mask_bit: u32 = 1 << 11;

        pub const EventMask = packed struct(u32) {
            key_press: bool = false,
            key_release: bool = false,
            button_press: bool = false,
            button_release: bool = false,
            enter_window: bool = false,
            leave_window: bool = false,
            pointer_motion: bool = false,
            pointer_motion_hint: bool = false,
            button_1_motion: bool = false,
            button_2_motion: bool = false,
            button_3_motion: bool = false,
            button_4_motion: bool = false,
            button_5_motion: bool = false,
            button_motion: bool = false,
            keymap_state: bool = false,
            exposure: bool = false,
            visibility_change: bool = false,
            structure_notify: bool = false,
            resize_redirect: bool = false,
            substructure_notify: bool = false,
            substructure_redirect: bool = false,
            focus_change: bool = false,
            property_change: bool = false,
            colormap_change: bool = false,
            owner_grab_button: bool = false,
            _reserved: u7 = 0,
        };

        window_id: u32,
        event_mask: EventMask,

        pub const size: usize = 16;

        pub fn encode(
            self: ChangeAttributes,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size)
                return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.window_id, byte_order);
            Wire.writeU32(buffer[8..12], event_mask_bit, byte_order);
            Wire.writeU32(buffer[12..16], @bitCast(self.event_mask), byte_order);

            return buffer[0..size];
        }
    };

    pub const Unmap = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 10;
        pub const size: usize = 8;

        window_id: u32,

        pub fn encode(
            self: Unmap,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size)
                return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.window_id, byte_order);

            return buffer[0..size];
        }
    };

    pub const Destroy = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 4;
        pub const size: usize = 8;

        window_id: u32,

        pub fn encode(
            self: Destroy,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size)
                return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.window_id, byte_order);

            return buffer[0..size];
        }
    };

    pub const Configure = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const opcode = 12;
        pub const base_size: usize = 12;

        window_id: u32,
        x: ?i32 = null,
        y: ?i32 = null,
        width: ?u32 = null,
        height: ?u32 = null,

        pub fn encodedLength(self: Configure) usize {
            var count: usize = 0;
            if (self.x != null) count += 1;
            if (self.y != null) count += 1;
            if (self.width != null) count += 1;
            if (self.height != null) count += 1;
            return base_size + count * 4;
        }

        pub fn encode(
            self: Configure,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            const length = self.encodedLength();
            if (buffer.len < length)
                return error.BufferTooSmall;

            var value_mask: u16 = 0;
            var offset: usize = base_size;

            if (self.x) |value| {
                value_mask |= 1 << 0;
                Wire.writeU32(buffer[offset .. offset + 4], @bitCast(value), byte_order);
                offset += 4;
            }

            if (self.y) |value| {
                value_mask |= 1 << 1;
                Wire.writeU32(buffer[offset .. offset + 4], @bitCast(value), byte_order);
                offset += 4;
            }

            if (self.width) |value| {
                value_mask |= 1 << 2;
                Wire.writeU32(buffer[offset .. offset + 4], value, byte_order);
                offset += 4;
            }

            if (self.height) |value| {
                value_mask |= 1 << 3;
                Wire.writeU32(buffer[offset .. offset + 4], value, byte_order);
                offset += 4;
            }

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.window_id, byte_order);
            Wire.writeU16(buffer[8..10], value_mask, byte_order);
            Wire.writeU16(buffer[10..12], 0, byte_order);

            return buffer[0..offset];
        }
    };

    pub const GetGeometry = struct {
        pub const EncodeError = error{
            BufferTooSmall,
        };

        pub const ParseError = error{
            InvalidLength,
            InvalidResponse,
        };

        pub const opcode = 14;
        pub const size: usize = 8;
        pub const reply_size: usize = 32;

        drawable: u32,

        pub const Reply = struct {
            depth: u8,
            root: u32,
            x: i16,
            y: i16,
            width: u16,
            height: u16,
            border_width: u16,

            pub fn parse(bytes: []const u8, byte_order: ByteOrder) ParseError!Reply {
                if (bytes.len != reply_size) return error.InvalidLength;
                if (bytes[0] != 1) return error.InvalidResponse;

                return .{
                    .depth = bytes[1],
                    .root = Wire.readU32(bytes[8..12], byte_order),
                    .x = Wire.readI16(bytes[12..14], byte_order),
                    .y = Wire.readI16(bytes[14..16], byte_order),
                    .width = Wire.readU16(bytes[16..18], byte_order),
                    .height = Wire.readU16(bytes[18..20], byte_order),
                    .border_width = Wire.readU16(bytes[20..22], byte_order),
                };
            }
        };

        pub fn encode(
            self: GetGeometry,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.drawable, byte_order);

            return buffer[0..size];
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
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.window_id, byte_order);

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


test "encode little-endian destroy window request" {
    const request = Window.Destroy{
        .window_id = 0x01020304,
    };

    var buffer: [Window.Destroy.size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        4, 0,
        2, 0,
        4, 3, 2, 1,
    }, encoded);
}


test "encode little-endian unmap window request" {
    const request = Window.Unmap{
        .window_id = 0x01020304,
    };

    var buffer: [Window.Unmap.size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        10, 0,
        2, 0,
        4, 3, 2, 1,
    }, encoded);
}


test "encode little-endian configure window request" {
    const request = Window.Configure{
        .window_id = 0x01020304,
        .x = 100,
        .y = -50,
        .width = 800,
        .height = 600,
    };

    var buffer: [28]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        12, 0,
        7, 0,
        4, 3, 2, 1,
        15, 0,
        0, 0,
        100, 0, 0, 0,
        206, 255, 255, 255,
        32, 3, 0, 0,
        88, 2, 0, 0,
    }, encoded);
}


test "encode little-endian change attributes request" {
    const request = Window.ChangeAttributes{
        .window_id = 0x01020304,
        .event_mask = .{
            .exposure = true,
            .structure_notify = true,
        },
    };

    var buffer: [Window.ChangeAttributes.size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        2, 0,
        3, 0,
        4, 3, 2, 1,
        0, 128, 10, 0,
    }, encoded);
}
