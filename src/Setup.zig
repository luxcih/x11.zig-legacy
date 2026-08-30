const std = @import("std");
const Wire = @import("Wire.zig");
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

const Setup = @This();
    pub const EncodeError = error{
        BufferTooSmall,
        AuthorizationTooLong,
    };

    byte_order: ByteOrder = .little,
    major_version: u16 = 11,
    minor_version: u16 = 0,
    authorization_name: []const u8 = "",
    authorization_data: []const u8 = "",

    pub fn encodedLength(self: Setup) usize {
        return 12 +
            paddedLength(self.authorization_name.len) +
            paddedLength(self.authorization_data.len);
    }

    pub fn encode(self: Setup, buffer: []u8) EncodeError![]const u8 {
        if (self.authorization_name.len > std.math.maxInt(u16) or
            self.authorization_data.len > std.math.maxInt(u16))
        {
            return error.AuthorizationTooLong;
        }

        const length = self.encodedLength();
        if (buffer.len < length) return error.BufferTooSmall;

        buffer[0] = switch (self.byte_order) {
            .little => 'l',
            .big => 'B',
        };
        buffer[1] = 0;

        Wire.writeU16(buffer[2..4], self.major_version, self.byte_order);
        Wire.writeU16(buffer[4..6], self.minor_version, self.byte_order);
        Wire.writeU16(buffer[6..8], @intCast(self.authorization_name.len), self.byte_order);
        Wire.writeU16(buffer[8..10], @intCast(self.authorization_data.len), self.byte_order);
        buffer[10] = 0;
        buffer[11] = 0;

        var offset: usize = 12;
        offset = writePadded(buffer, offset, self.authorization_name);
        _ = writePadded(buffer, offset, self.authorization_data);

        return buffer[0..length];
    }

    fn paddedLength(length: usize) usize {
        return (length + 3) & ~@as(usize, 3);
    }

    fn writePadded(buffer: []u8, offset: usize, value: []const u8) usize {
        @memcpy(buffer[offset .. offset + value.len], value);

        const padded_end = offset + paddedLength(value.len);
        @memset(buffer[offset + value.len .. padded_end], 0);

        return padded_end;
    }


test "encode little-endian setup without authorization" {
    const setup = Setup{};

    var buffer: [12]u8 = undefined;
    const encoded = try setup.encode(&buffer);

    try std.testing.expectEqualSlices(u8, &.{
        'l', 0,
        11, 0,
        0, 0,
        0, 0,
        0, 0,
        0, 0,
    }, encoded);
}

test "encode setup authorization with padding" {
    const setup = Setup{
        .authorization_name = "MIT",
        .authorization_data = "12345",
    };

    var buffer: [24]u8 = undefined;
    const encoded = try setup.encode(&buffer);

    try std.testing.expectEqual(@as(usize, 24), encoded.len);
    try std.testing.expectEqualSlices(u8, "MIT", encoded[12..15]);
    try std.testing.expectEqual(@as(u8, 0), encoded[15]);
    try std.testing.expectEqualSlices(u8, "12345", encoded[16..21]);
    try std.testing.expectEqual(@as(u8, 0), encoded[21]);
    try std.testing.expectEqual(@as(u8, 0), encoded[22]);
    try std.testing.expectEqual(@as(u8, 0), encoded[23]);
}

test "encode big-endian setup" {
    const setup = Setup{
        .byte_order = .big,
    };

    var buffer: [12]u8 = undefined;
    const encoded = try setup.encode(&buffer);

    try std.testing.expectEqualSlices(u8, &.{
        'B', 0,
        0, 11,
        0, 0,
        0, 0,
        0, 0,
        0, 0,
    }, encoded);
}
