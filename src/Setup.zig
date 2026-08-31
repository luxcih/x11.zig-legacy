//! Encoding of the initial X11 connection setup request.
//!
//! Before ordinary requests can be sent, an X11 client and server perform a
//! setup handshake. The client first declares its byte order and protocol
//! version, optionally followed by authorization data padded to 4-byte boundaries.

const std = @import("std");
const Wire = @import("Wire.zig");
const Endian = std.builtin.Endian;

const Setup = @This();
pub const EncodeError = error{
    AuthorizationTooLong,
};

byte_order: Endian = .little,
major_version: u16 = 11,
minor_version: u16 = 0,
authorization_name: []const u8 = "",
authorization_data: []const u8 = "",

/// Encodes the setup handshake, including required 4-byte padding for authorization fields.
pub fn encode(self: Setup, writer: *std.Io.Writer) EncodeError!void {
    if (self.authorization_name.len > std.math.maxInt(u16) or
        self.authorization_data.len > std.math.maxInt(u16))
    {
        return error.AuthorizationTooLong;
    }

    var header: [12]u8 = undefined;
    header[0] = switch (self.byte_order) {
        .little => 'l',
        .big => 'B',
    };
    header[1] = 0;
    Wire.writeU16(header[2..4], self.major_version, self.byte_order);
    Wire.writeU16(header[4..6], self.minor_version, self.byte_order);
    Wire.writeU16(header[6..8], @intCast(self.authorization_name.len), self.byte_order);
    Wire.writeU16(header[8..10], @intCast(self.authorization_data.len), self.byte_order);
    header[10] = 0;
    header[11] = 0;

    try writer.writeAll(&header);
    try writePadded(writer, self.authorization_name);
    try writePadded(writer, self.authorization_data);
}

fn paddedLength(length: usize) usize {
    return (length + 3) & ~@as(usize, 3);
}

fn writePadded(writer: *std.Io.Writer, value: []const u8) !void {
    try writer.writeAll(value);

    const padding = paddedLength(value.len) - value.len;
    if (padding > 0) {
        var zeros: [3]u8 = .{ 0, 0, 0 };
        try writer.writeAll(zeros[0..padding]);
    }
}

test "encode little-endian setup without authorization" {
    const setup = Setup{};

    var buffer: [12]u8 = undefined;
    const encoded = try setup.encode(&buffer);

    try std.testing.expectEqualSlices(u8, &.{
        'l', 0,
        11,  0,
        0,   0,
        0,   0,
        0,   0,
        0,   0,
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
        0,   11,
        0,   0,
        0,   0,
        0,   0,
        0,   0,
    }, encoded);
}
