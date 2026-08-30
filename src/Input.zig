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


test "encode and parse GetInputFocus big-endian" {
    const std = @import("std");

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
    const std = @import("std");

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
    const std = @import("std");

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
