const std = @import("std");
const Wire = @import("Wire.zig");
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

const Window = @This();
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


    pub const GetWindowAttributes = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const ParseError = error{ InvalidLength, InvalidResponse };

        pub const opcode = 3;
        pub const size: usize = 8;
        pub const reply_size: usize = 44;

        window_id: u32,

        pub const Reply = struct {
            backing_store: u8,
            visual: u32,
            class: u16,
            bit_gravity: u8,
            win_gravity: u8,
            backing_planes: u32,
            backing_pixel: u32,
            save_under: bool,
            map_is_installed: bool,
            map_state: u8,
            override_redirect: bool,
            colormap: u32,
            all_event_masks: u32,
            your_event_mask: u32,
            do_not_propagate_mask: u16,

            pub fn parse(bytes: []const u8, byte_order: ByteOrder) ParseError!Reply {
                if (bytes.len != reply_size) return error.InvalidLength;
                if (bytes[0] != 1) return error.InvalidResponse;

                return .{
                    .backing_store = bytes[1],
                    .visual = Wire.readU32(bytes[8..12], byte_order),
                    .class = Wire.readU16(bytes[12..14], byte_order),
                    .bit_gravity = bytes[14],
                    .win_gravity = bytes[15],
                    .backing_planes = Wire.readU32(bytes[16..20], byte_order),
                    .backing_pixel = Wire.readU32(bytes[20..24], byte_order),
                    .save_under = bytes[24] != 0,
                    .map_is_installed = bytes[25] != 0,
                    .map_state = bytes[26],
                    .override_redirect = bytes[27] != 0,
                    .colormap = Wire.readU32(bytes[28..32], byte_order),
                    .all_event_masks = Wire.readU32(bytes[32..36], byte_order),
                    .your_event_mask = Wire.readU32(bytes[36..40], byte_order),
                    .do_not_propagate_mask = Wire.readU16(bytes[40..42], byte_order),
                };
            }
        };

        pub fn encode(self: GetWindowAttributes, buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.window_id, byte_order);
            return buffer[0..size];
        }
    };

    pub const QueryTree = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const ParseError = std.mem.Allocator.Error || error{ InvalidLength, InvalidResponse, InvalidChildrenLength };

        pub const opcode = 15;
        pub const size: usize = 8;
        pub const reply_header_size: usize = 32;

        window_id: u32,

        pub const ReplyHeader = struct {
            root: u32,
            parent: u32,
            children_count: u16,

            pub fn parse(bytes: []const u8, byte_order: ByteOrder) ParseError!ReplyHeader {
                if (bytes.len != reply_header_size) return error.InvalidLength;
                if (bytes[0] != 1) return error.InvalidResponse;
                return .{
                    .root = Wire.readU32(bytes[8..12], byte_order),
                    .parent = Wire.readU32(bytes[12..16], byte_order),
                    .children_count = Wire.readU16(bytes[16..18], byte_order),
                };
            }

            pub fn childrenBytes(self: ReplyHeader) usize {
                return @as(usize, self.children_count) * 4;
            }
        };

        pub fn parseChildren(
            allocator: std.mem.Allocator,
            bytes: []const u8,
            count: u16,
            byte_order: ByteOrder,
        ) ParseError![]u32 {
            const expected = @as(usize, count) * 4;
            if (bytes.len != expected) return error.InvalidChildrenLength;

            const children = try allocator.alloc(u32, count);
            for (children, 0..) |*child, index| {
                const offset = index * 4;
                child.* = Wire.readU32(bytes[offset .. offset + 4], byte_order);
            }
            return children;
        }

        pub fn encode(self: QueryTree, buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            Wire.writeU32(buffer[4..8], self.window_id, byte_order);
            return buffer[0..size];
        }
    };

    pub const QueryPointer = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const ParseError = error{ InvalidLength, InvalidResponse };

        pub const opcode = 38;
        pub const size: usize = 8;
        pub const reply_size: usize = 32;

        window_id: u32,

        pub const Reply = struct {
            same_screen: bool,
            root: u32,
            child: u32,
            root_x: i16,
            root_y: i16,
            win_x: i16,
            win_y: i16,
            mask: u16,

            pub fn parse(bytes: []const u8, byte_order: ByteOrder) ParseError!Reply {
                if (bytes.len != reply_size) return error.InvalidLength;
                if (bytes[0] != 1) return error.InvalidResponse;

                return .{
                    .same_screen = bytes[1] != 0,
                    .root = Wire.readU32(bytes[8..12], byte_order),
                    .child = Wire.readU32(bytes[12..16], byte_order),
                    .root_x = Wire.readI16(bytes[16..18], byte_order),
                    .root_y = Wire.readI16(bytes[18..20], byte_order),
                    .win_x = Wire.readI16(bytes[20..22], byte_order),
                    .win_y = Wire.readI16(bytes[22..24], byte_order),
                    .mask = Wire.readU16(bytes[24..26], byte_order),
                };
            }
        };

        pub fn encode(
            self: QueryPointer,
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

pub const GetProperty = struct {
    pub const EncodeError = error{BufferTooSmall};
    pub const ParseError = error{InvalidLength, InvalidResponse};

    pub const opcode = 20;
    pub const request_size = 24;
    pub const reply_size = 32;

    window_id: u32,
    delete: bool = false,
    property: u32,
    type: u32 = 0,
    long_offset: u32 = 0,
    long_length: u32,

    pub fn encode(
        self: GetProperty,
        buffer: []u8,
        byte_order: ByteOrder,
    ) EncodeError![]const u8 {
        if (buffer.len < request_size)
            return error.BufferTooSmall;

        @memset(buffer[0..request_size], 0);
        buffer[0] = opcode;
        buffer[1] = @intFromBool(self.delete);
        Wire.writeU16(buffer[2..4], request_size / 4, byte_order);
        Wire.writeU32(buffer[4..8], self.window_id, byte_order);
        Wire.writeU32(buffer[8..12], self.property, byte_order);
        Wire.writeU32(buffer[12..16], self.type, byte_order);
        Wire.writeU32(buffer[16..20], self.long_offset, byte_order);
        Wire.writeU32(buffer[20..24], self.long_length, byte_order);

        return buffer[0..request_size];
    }

    pub const Reply = struct {
        format: u8,
        type: u32,
        bytes_after: u32,
        value_length: u32,

        pub fn parsePrefix(bytes: []const u8, byte_order: ByteOrder) ParseError!Reply {
            if (bytes.len != reply_size)
                return error.InvalidLength;
            if (bytes[0] != 1)
                return error.InvalidResponse;

            return .{
                .format = bytes[1],
                .type = Wire.readU32(bytes[8..12], byte_order),
                .bytes_after = Wire.readU32(bytes[12..16], byte_order),
                .value_length = Wire.readU32(bytes[16..20], byte_order),
            };
        }

        pub fn valueByteLength(self: Reply) usize {
            const item_size: usize = switch (self.format) {
                0 => return 0,
                8 => 1,
                16 => 2,
                32 => 4,
                else => return 0,
            };
            return @as(usize, self.value_length) * item_size;
        }
    };
};


pub const ChangeProperty = struct {
    pub const EncodeError = error{
        BufferTooSmall,
        InvalidFormat,
        InvalidDataLength,
    };

    pub const opcode = 18;
    pub const header_size = 24;

    pub const Mode = enum(u8) {
        replace = 0,
        prepend = 1,
        append = 2,
    };

    window_id: u32,
    mode: Mode = .replace,
    property: u32,
    type: u32,
    format: u8,
    data: []const u8,

    pub fn encodedLength(self: ChangeProperty) EncodeError!usize {
        const item_size: usize = switch (self.format) {
            8 => 1,
            16 => 2,
            32 => 4,
            else => return error.InvalidFormat,
        };

        if (self.data.len % item_size != 0)
            return error.InvalidDataLength;

        return header_size + std.mem.alignForward(usize, self.data.len, 4);
    }

    pub fn encode(
        self: ChangeProperty,
        buffer: []u8,
        byte_order: ByteOrder,
    ) EncodeError![]const u8 {
        const length = try self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        const item_size: usize = switch (self.format) {
            8 => 1,
            16 => 2,
            32 => 4,
            else => unreachable,
        };
        const item_count = self.data.len / item_size;

        @memset(buffer[0..length], 0);
        buffer[0] = opcode;
        buffer[1] = @intFromEnum(self.mode);
        Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        Wire.writeU32(buffer[4..8], self.window_id, byte_order);
        Wire.writeU32(buffer[8..12], self.property, byte_order);
        Wire.writeU32(buffer[12..16], self.type, byte_order);
        buffer[16] = self.format;
        Wire.writeU32(buffer[20..24], @intCast(item_count), byte_order);
        @memcpy(buffer[24 .. 24 + self.data.len], self.data);

        return buffer[0..length];
    }
};


pub const DeleteProperty = struct {
    pub const EncodeError = error{BufferTooSmall};

    pub const opcode = 19;
    pub const request_size = 12;

    window_id: u32,
    property: u32,

    pub fn encode(
        self: DeleteProperty,
        buffer: []u8,
        byte_order: ByteOrder,
    ) EncodeError![]const u8 {
        if (buffer.len < request_size)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], request_size / 4, byte_order);
        Wire.writeU32(buffer[4..8], self.window_id, byte_order);
        Wire.writeU32(buffer[8..12], self.property, byte_order);

        return buffer[0..request_size];
    }
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


test "encode and parse GetGeometry" {
    const request = Window.GetGeometry{ .drawable = 0x01020304 };
    var request_buffer: [Window.GetGeometry.size]u8 = undefined;
    const encoded = try request.encode(&request_buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{ 14, 0, 2, 0, 4, 3, 2, 1 }, encoded);

    var reply: [Window.GetGeometry.reply_size]u8 = [_]u8{0} ** Window.GetGeometry.reply_size;
    reply[0] = 1;
    reply[1] = 24;
    Wire.writeU32(reply[8..12], 0x01020304, .little);
    Wire.writeI16(reply[12..14], -10, .little);
    Wire.writeI16(reply[14..16], 20, .little);
    Wire.writeU16(reply[16..18], 640, .little);
    Wire.writeU16(reply[18..20], 480, .little);
    Wire.writeU16(reply[20..22], 2, .little);

    const parsed = try Window.GetGeometry.Reply.parse(&reply, .little);
    try std.testing.expectEqual(@as(u8, 24), parsed.depth);
    try std.testing.expectEqual(@as(i16, -10), parsed.x);
    try std.testing.expectEqual(@as(u16, 640), parsed.width);
}

test "encode and parse GetWindowAttributes" {
    const request = Window.GetWindowAttributes{ .window_id = 0x01020304 };
    var request_buffer: [Window.GetWindowAttributes.size]u8 = undefined;
    const encoded = try request.encode(&request_buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{ 3, 0, 2, 0, 4, 3, 2, 1 }, encoded);

    var reply: [Window.GetWindowAttributes.reply_size]u8 = [_]u8{0} ** Window.GetWindowAttributes.reply_size;
    reply[0] = 1;
    reply[1] = 2;
    Wire.writeU32(reply[8..12], 0x01020304, .little);
    Wire.writeU16(reply[12..14], 1, .little);
    reply[24] = 1;
    reply[25] = 1;
    reply[26] = 2;
    reply[27] = 1;

    const parsed = try Window.GetWindowAttributes.Reply.parse(&reply, .little);
    try std.testing.expectEqual(@as(u32, 0x01020304), parsed.visual);
    try std.testing.expect(parsed.save_under);
    try std.testing.expect(parsed.map_is_installed);
    try std.testing.expect(parsed.override_redirect);
}

test "encode and parse QueryTree" {
    const request = Window.QueryTree{ .window_id = 0x01020304 };
    var request_buffer: [Window.QueryTree.size]u8 = undefined;
    const encoded = try request.encode(&request_buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{ 15, 0, 2, 0, 4, 3, 2, 1 }, encoded);

    var header_bytes: [Window.QueryTree.reply_header_size]u8 = [_]u8{0} ** Window.QueryTree.reply_header_size;
    header_bytes[0] = 1;
    Wire.writeU32(header_bytes[8..12], 1, .little);
    Wire.writeU32(header_bytes[12..16], 2, .little);
    Wire.writeU16(header_bytes[16..18], 2, .little);

    const header = try Window.QueryTree.ReplyHeader.parse(&header_bytes, .little);
    try std.testing.expectEqual(@as(usize, 8), header.childrenBytes());

    var child_bytes: [8]u8 = undefined;
    Wire.writeU32(child_bytes[0..4], 3, .little);
    Wire.writeU32(child_bytes[4..8], 4, .little);
    const children = try Window.QueryTree.parseChildren(
        std.testing.allocator,
        &child_bytes,
        header.children_count,
        .little,
    );
    defer std.testing.allocator.free(children);

    try std.testing.expectEqualSlices(u32, &.{ 3, 4 }, children);
}


test "encode and parse QueryPointer" {
    const request = Window.QueryPointer{ .window_id = 0x01020304 };
    var request_buffer: [Window.QueryPointer.size]u8 = undefined;
    const encoded = try request.encode(&request_buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{ 38, 0, 2, 0, 4, 3, 2, 1 }, encoded);

    var reply: [Window.QueryPointer.reply_size]u8 = [_]u8{0} ** Window.QueryPointer.reply_size;
    reply[0] = 1;
    reply[1] = 1;
    Wire.writeU32(reply[8..12], 0x11121314, .little);
    Wire.writeU32(reply[12..16], 0x21222324, .little);
    Wire.writeI16(reply[16..18], 100, .little);
    Wire.writeI16(reply[18..20], -50, .little);
    Wire.writeI16(reply[20..22], 25, .little);
    Wire.writeI16(reply[22..24], 30, .little);
    Wire.writeU16(reply[24..26], 0x0005, .little);

    const parsed = try Window.QueryPointer.Reply.parse(&reply, .little);
    try std.testing.expect(parsed.same_screen);
    try std.testing.expectEqual(@as(u32, 0x11121314), parsed.root);
    try std.testing.expectEqual(@as(i16, -50), parsed.root_y);
    try std.testing.expectEqual(@as(i16, 25), parsed.win_x);
    try std.testing.expectEqual(@as(u16, 0x0005), parsed.mask);
}


test "encode little-endian GetProperty" {
    const request = Window.GetProperty{
        .window_id = 0x01020304,
        .property = 0x11121314,
        .type = 0,
        .long_offset = 0,
        .long_length = 1024,
    };

    var buffer: [Window.GetProperty.request_size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        20, 0, 6, 0,
        4, 3, 2, 1,
        20, 19, 18, 17,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 4, 0, 0,
    }, encoded);
}

test "parse GetProperty reply prefix" {
    var bytes: [Window.GetProperty.reply_size]u8 =
        [_]u8{0} ** Window.GetProperty.reply_size;
    bytes[0] = 1;
    bytes[1] = 8;
    Wire.writeU32(bytes[8..12], 31, .little);
    Wire.writeU32(bytes[12..16], 4, .little);
    Wire.writeU32(bytes[16..20], 12, .little);

    const reply = try Window.GetProperty.Reply.parsePrefix(&bytes, .little);

    try std.testing.expectEqual(@as(u8, 8), reply.format);
    try std.testing.expectEqual(@as(u32, 31), reply.type);
    try std.testing.expectEqual(@as(u32, 4), reply.bytes_after);
    try std.testing.expectEqual(@as(u32, 12), reply.value_length);
    try std.testing.expectEqual(@as(usize, 12), reply.valueByteLength());
}


test "encode little-endian ChangeProperty format 8" {
    const request = Window.ChangeProperty{
        .window_id = 0x01020304,
        .property = 0x11121314,
        .type = 31,
        .format = 8,
        .data = "hello",
    };

    var buffer: [32]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        18, 0, 8, 0,
        4, 3, 2, 1,
        20, 19, 18, 17,
        31, 0, 0, 0,
        8, 0, 0, 0,
        5, 0, 0, 0,
        'h', 'e', 'l', 'l', 'o', 0, 0, 0,
    }, encoded);
}

test "ChangeProperty rejects invalid format" {
    const request = Window.ChangeProperty{
        .window_id = 1,
        .property = 2,
        .type = 3,
        .format = 12,
        .data = &.{},
    };

    try std.testing.expectError(error.InvalidFormat, request.encodedLength());
}


test "encode little-endian DeleteProperty" {
    const request = Window.DeleteProperty{
        .window_id = 0x01020304,
        .property = 0x11121314,
    };

    var buffer: [Window.DeleteProperty.request_size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        19, 0, 3, 0,
        4, 3, 2, 1,
        20, 19, 18, 17,
    }, encoded);
}
