const Wire = @import("Wire.zig");
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

pub const Input = struct {
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
};
