const std = @import("std");
const Wire = @import("Wire.zig");
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

const Input = @This();
    pub const GetInputFocus = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const ParseError = error{ InvalidLength, InvalidResponse };

        pub const opcode = 43;
        pub const size: usize = 4;
        pub const reply_size: usize = 32;

        pub const RevertTo = enum(u8) {
            none = 0,
            pointer_root = 1,
            parent = 2,
        };

        pub const Reply = struct {
            revert_to: RevertTo,
            focus: u32,

            pub fn parse(bytes: []const u8, byte_order: ByteOrder) ParseError!Reply {
                if (bytes.len != reply_size) return error.InvalidLength;
                if (bytes[0] != 1) return error.InvalidResponse;

                const revert_to: RevertTo = switch (bytes[1]) {
                    0 => .none,
                    1 => .pointer_root,
                    2 => .parent,
                    else => return error.InvalidResponse,
                };
                return .{
                    .revert_to = revert_to,
                    .focus = Wire.readU32(bytes[8..12], byte_order),
                };
            }
        };

        pub fn encode(buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], @intCast(size / 4), byte_order);
            return buffer[0..size];
        }
    };


    pub const SetInputFocus = struct {
        pub const EncodeError = error{BufferTooSmall};

        pub const opcode = 42;
        pub const size: usize = 12;

        pub const RevertTo = enum(u8) {
            none = 0,
            pointer_root = 1,
            parent = 2,
        };

        revert_to: RevertTo = .none,
        focus: u32,
        time: u32 = 0,

        pub fn encode(
            self: SetInputFocus,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = @intFromEnum(self.revert_to);
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            Wire.writeU32(buffer[4..8], self.focus, byte_order);
            Wire.writeU32(buffer[8..12], self.time, byte_order);

            return buffer[0..size];
        }
    };

test "encode SetInputFocus" {
    const request = Input.SetInputFocus{
        .revert_to = .parent,
        .focus = 0x01020304,
        .time = 0x05060708,
    };

    var buffer: [Input.SetInputFocus.size]u8 = undefined;

    const little = try request.encode(&buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{
        42, 2, 3, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
    }, little);

    const big = try request.encode(&buffer, .big);
    try std.testing.expectEqualSlices(u8, &.{
        42, 2, 0, 3,
        1, 2, 3, 4,
        5, 6, 7, 8,
    }, big);
}

test "SetInputFocus rejects a small buffer" {
    const request = Input.SetInputFocus{ .focus = 1 };
    var buffer: [Input.SetInputFocus.size - 1]u8 = undefined;

    try std.testing.expectError(
        error.BufferTooSmall,
        request.encode(&buffer, .little),
    );
}


    pub const QueryKeymap = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const ParseError = error{InvalidLength, InvalidResponse};

        pub const opcode = 44;
        pub const size: usize = 4;
        pub const reply_header_size: usize = 32;
        pub const keys_size: usize = 32;

        pub const Reply = struct {
            keys: [keys_size]u8,

            pub fn parse(
                header: []const u8,
                keys: []const u8,
            ) ParseError!Reply {
                if (header.len != reply_header_size or keys.len != keys_size)
                    return error.InvalidLength;
                if (header[0] != 1) return error.InvalidResponse;

                return .{ .keys = keys[0..keys_size].* };
            }

            pub fn isDown(self: Reply, keycode: u8) bool {
                return (self.keys[keycode / 8] & (@as(u8, 1) << @intCast(keycode % 8))) != 0;
            }
        };

        pub fn encode(buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            return buffer[0..size];
        }
    };

test "encode and parse QueryKeymap" {
    var request: [Input.QueryKeymap.size]u8 = undefined;
    const encoded = try Input.QueryKeymap.encode(&request, .little);
    try std.testing.expectEqualSlices(u8, &.{ 44, 0, 1, 0 }, encoded);

    var header: [Input.QueryKeymap.reply_header_size]u8 =
        [_]u8{0} ** Input.QueryKeymap.reply_header_size;
    header[0] = 1;

    var keys: [Input.QueryKeymap.keys_size]u8 =
        [_]u8{0} ** Input.QueryKeymap.keys_size;
    keys[38 / 8] |= @as(u8, 1) << (38 % 8);

    const parsed = try Input.QueryKeymap.Reply.parse(&header, &keys);
    try std.testing.expect(parsed.isDown(38));
    try std.testing.expect(!parsed.isDown(39));
}

test "encode QueryKeymap big-endian" {
    var request: [Input.QueryKeymap.size]u8 = undefined;
    const encoded = try Input.QueryKeymap.encode(&request, .big);
    try std.testing.expectEqualSlices(u8, &.{ 44, 0, 0, 1 }, encoded);
}


    pub const WarpPointer = struct {
        pub const EncodeError = error{BufferTooSmall};

        pub const opcode = 41;
        pub const size: usize = 24;

        src_window: u32 = 0,
        dst_window: u32 = 0,
        src_x: i16 = 0,
        src_y: i16 = 0,
        src_width: u16 = 0,
        src_height: u16 = 0,
        dst_x: i16,
        dst_y: i16,

        pub fn encode(
            self: WarpPointer,
            buffer: []u8,
            byte_order: ByteOrder,
        ) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;

            buffer[0] = opcode;
            buffer[1] = 0;
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            Wire.writeU32(buffer[4..8], self.src_window, byte_order);
            Wire.writeU32(buffer[8..12], self.dst_window, byte_order);
            Wire.writeI16(buffer[12..14], self.src_x, byte_order);
            Wire.writeI16(buffer[14..16], self.src_y, byte_order);
            Wire.writeU16(buffer[16..18], self.src_width, byte_order);
            Wire.writeU16(buffer[18..20], self.src_height, byte_order);
            Wire.writeI16(buffer[20..22], self.dst_x, byte_order);
            Wire.writeI16(buffer[22..24], self.dst_y, byte_order);

            return buffer[0..size];
        }
    };

test "encode WarpPointer" {
    const request = Input.WarpPointer{
        .src_window = 0x01020304,
        .dst_window = 0x05060708,
        .src_x = -10,
        .src_y = 20,
        .src_width = 30,
        .src_height = 40,
        .dst_x = 50,
        .dst_y = -60,
    };

    var buffer: [Input.WarpPointer.size]u8 = undefined;

    const little = try request.encode(&buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{
        41, 0, 6, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
        246, 255,
        20, 0,
        30, 0,
        40, 0,
        50, 0,
        196, 255,
    }, little);

    const big = try request.encode(&buffer, .big);
    try std.testing.expectEqualSlices(u8, &.{
        41, 0, 0, 6,
        1, 2, 3, 4,
        5, 6, 7, 8,
        255, 246,
        0, 20,
        0, 30,
        0, 40,
        0, 50,
        255, 196,
    }, big);
}

test "WarpPointer rejects a small buffer" {
    const request = Input.WarpPointer{ .dst_x = 0, .dst_y = 0 };
    var buffer: [Input.WarpPointer.size - 1]u8 = undefined;

    try std.testing.expectError(
        error.BufferTooSmall,
        request.encode(&buffer, .little),
    );
}


    pub const GrabPointer = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const ParseError = error{InvalidLength, InvalidResponse};
        pub const opcode = 26;
        pub const size: usize = 24;
        pub const reply_size: usize = 32;

        pub const Status = enum(u8) { success = 0, already_grabbed = 1, invalid_time = 2, not_viewable = 3, frozen = 4 };

        owner_events: bool,
        grab_window: u32,
        event_mask: u16,
        pointer_mode: u8 = 1,
        keyboard_mode: u8 = 1,
        confine_to: u32 = 0,
        cursor: u32 = 0,
        time: u32 = 0,

        pub const Reply = struct {
            status: Status,
            pub fn parse(bytes: []const u8) ParseError!Reply {
                if (bytes.len != reply_size) return error.InvalidLength;
                if (bytes[0] != 1) return error.InvalidResponse;
                return .{ .status = switch (bytes[1]) {
                    0 => .success, 1 => .already_grabbed, 2 => .invalid_time,
                    3 => .not_viewable, 4 => .frozen, else => return error.InvalidResponse,
                }};
            }
        };

        pub fn encode(self: GrabPointer, buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode;
            buffer[1] = if (self.owner_events) 1 else 0;
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            Wire.writeU32(buffer[4..8], self.grab_window, byte_order);
            Wire.writeU16(buffer[8..10], self.event_mask, byte_order);
            buffer[10] = self.pointer_mode;
            buffer[11] = self.keyboard_mode;
            Wire.writeU32(buffer[12..16], self.confine_to, byte_order);
            Wire.writeU32(buffer[16..20], self.cursor, byte_order);
            Wire.writeU32(buffer[20..24], self.time, byte_order);
            return buffer[0..size];
        }
    };

    pub const UngrabPointer = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const opcode = 27;
        pub const size: usize = 8;
        time: u32 = 0,
        pub fn encode(self: UngrabPointer, buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode; buffer[1] = 0;
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            Wire.writeU32(buffer[4..8], self.time, byte_order);
            return buffer[0..size];
        }
    };

test "encode GrabPointer and UngrabPointer" {
    const grab = Input.GrabPointer{ .owner_events = true, .grab_window = 0x01020304, .event_mask = 0x1234 };
    var buffer: [Input.GrabPointer.size]u8 = undefined;
    const encoded = try grab.encode(&buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{ 26, 1, 6, 0, 4, 3, 2, 1, 0x34, 0x12, 1, 1, 0,0,0,0, 0,0,0,0, 0,0,0,0 }, encoded);

    const ungrab = Input.UngrabPointer{};
    var ungrab_buffer: [Input.UngrabPointer.size]u8 = undefined;
    const ungrab_encoded = try ungrab.encode(&ungrab_buffer, .big);
    try std.testing.expectEqualSlices(u8, &.{ 27, 0, 0, 2, 0, 0, 0, 0 }, ungrab_encoded);
}

test "parse GrabPointer reply" {
    var reply: [Input.GrabPointer.reply_size]u8 = [_]u8{0} ** Input.GrabPointer.reply_size;
    reply[0] = 1;
    reply[1] = 0;
    const parsed = try Input.GrabPointer.Reply.parse(&reply);
    try std.testing.expectEqual(Input.GrabPointer.Status.success, parsed.status);
}


    pub const GrabKeyboard = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const ParseError = error{InvalidLength, InvalidResponse};
        pub const opcode = 31;
        pub const size: usize = 16;
        pub const reply_size: usize = 32;

        pub const Status = enum(u8) { success = 0, already_grabbed = 1, invalid_time = 2, not_viewable = 3, frozen = 4 };

        owner_events: bool,
        grab_window: u32,
        time: u32 = 0,
        pointer_mode: u8 = 1,
        keyboard_mode: u8 = 1,

        pub const Reply = struct {
            status: Status,
            pub fn parse(bytes: []const u8) ParseError!Reply {
                if (bytes.len != reply_size) return error.InvalidLength;
                if (bytes[0] != 1) return error.InvalidResponse;
                return .{ .status = switch (bytes[1]) {
                    0 => .success, 1 => .already_grabbed, 2 => .invalid_time,
                    3 => .not_viewable, 4 => .frozen, else => return error.InvalidResponse,
                }};
            }
        };

        pub fn encode(self: GrabKeyboard, buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode;
            buffer[1] = if (self.owner_events) 1 else 0;
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            Wire.writeU32(buffer[4..8], self.grab_window, byte_order);
            Wire.writeU32(buffer[8..12], self.time, byte_order);
            buffer[12] = self.pointer_mode;
            buffer[13] = self.keyboard_mode;
            buffer[14] = 0; buffer[15] = 0;
            return buffer[0..size];
        }
    };

    pub const UngrabKeyboard = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const opcode = 32;
        pub const size: usize = 8;
        time: u32 = 0,
        pub fn encode(self: UngrabKeyboard, buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode; buffer[1] = 0;
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            Wire.writeU32(buffer[4..8], self.time, byte_order);
            return buffer[0..size];
        }
    };

test "encode GrabKeyboard and UngrabKeyboard" {
    const grab = Input.GrabKeyboard{ .owner_events = true, .grab_window = 0x01020304, .time = 0x05060708, .pointer_mode = 0, .keyboard_mode = 1 };
    var buffer: [Input.GrabKeyboard.size]u8 = undefined;
    const encoded = try grab.encode(&buffer, .big);
    try std.testing.expectEqualSlices(u8, &.{ 31,1,0,4,1,2,3,4,5,6,7,8,0,1,0,0 }, encoded);

    const ungrab = Input.UngrabKeyboard{ .time = 0x01020304 };
    var ungrab_buffer: [Input.UngrabKeyboard.size]u8 = undefined;
    const ungrab_encoded = try ungrab.encode(&ungrab_buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{ 32,0,2,0,4,3,2,1 }, ungrab_encoded);
}


    pub const AllowEvents = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const opcode = 35;
        pub const size: usize = 8;
        pub const Mode = enum(u8) {
            async_pointer = 0, sync_pointer = 1, replay_pointer = 2,
            async_keyboard = 3, sync_keyboard = 4, replay_keyboard = 5,
            async_both = 6, sync_both = 7,
        };
        mode: Mode,
        time: u32 = 0,
        pub fn encode(self: AllowEvents, buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode; buffer[1] = @intFromEnum(self.mode);
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            Wire.writeU32(buffer[4..8], self.time, byte_order);
            return buffer[0..size];
        }
    };

    pub const GrabServer = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const opcode = 36;
        pub const size: usize = 4;
        pub fn encode(buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode; buffer[1] = 0;
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            return buffer[0..size];
        }
    };

    pub const UngrabServer = struct {
        pub const EncodeError = error{BufferTooSmall};
        pub const opcode = 37;
        pub const size: usize = 4;
        pub fn encode(buffer: []u8, byte_order: ByteOrder) EncodeError![]const u8 {
            if (buffer.len < size) return error.BufferTooSmall;
            buffer[0] = opcode; buffer[1] = 0;
            Wire.writeU16(buffer[2..4], size / 4, byte_order);
            return buffer[0..size];
        }
    };

test "encode AllowEvents and server grabs" {
    const allow = Input.AllowEvents{ .mode = .sync_both, .time = 0x01020304 };
    var buffer: [Input.AllowEvents.size]u8 = undefined;
    const encoded = try allow.encode(&buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{ 35,7,2,0,4,3,2,1 }, encoded);

    var grab: [Input.GrabServer.size]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &.{ 36,0,0,1 }, try Input.GrabServer.encode(&grab, .big));

    var ungrab: [Input.UngrabServer.size]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &.{ 37,0,1,0 }, try Input.UngrabServer.encode(&ungrab, .little));
}


test "encode and parse GetInputFocus big-endian" {

    var request_buffer: [Input.GetInputFocus.size]u8 = undefined;
    const encoded = try Input.GetInputFocus.encode(&request_buffer, .big);
    try std.testing.expectEqualSlices(u8, &.{ 43, 0, 0, 1 }, encoded);

    var reply: [Input.GetInputFocus.reply_size]u8 = [_]u8{0} ** Input.GetInputFocus.reply_size;
    reply[0] = 1;
    reply[1] = 2;
    Wire.writeU32(reply[8..12], 0x01020304, .big);

    const parsed = try Input.GetInputFocus.Reply.parse(&reply, .big);
    try std.testing.expectEqual(Input.GetInputFocus.RevertTo.parent, parsed.revert_to);
    try std.testing.expectEqual(@as(u32, 0x01020304), parsed.focus);
}

test "reject invalid GetInputFocus replies" {

    var reply: [Input.GetInputFocus.reply_size]u8 = [_]u8{0} ** Input.GetInputFocus.reply_size;
    reply[0] = 1;
    reply[1] = 3;

    try std.testing.expectError(
        error.InvalidResponse,
        Input.GetInputFocus.Reply.parse(&reply, .little),
    );

    reply[0] = 0;
    reply[1] = 0;

    try std.testing.expectError(
        error.InvalidResponse,
        Input.GetInputFocus.Reply.parse(&reply, .little),
    );
}

test "encode and parse GetInputFocus" {

    var request_buffer: [Input.GetInputFocus.size]u8 = undefined;
    const encoded = try Input.GetInputFocus.encode(&request_buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{ 43, 0, 1, 0 }, encoded);

    var reply: [Input.GetInputFocus.reply_size]u8 = [_]u8{0} ** Input.GetInputFocus.reply_size;
    reply[0] = 1;
    reply[1] = 1;
    Wire.writeU32(reply[8..12], 0x01020304, .little);

    const parsed = try Input.GetInputFocus.Reply.parse(&reply, .little);
    try std.testing.expectEqual(Input.GetInputFocus.RevertTo.pointer_root, parsed.revert_to);
    try std.testing.expectEqual(@as(u32, 0x01020304), parsed.focus);
}
