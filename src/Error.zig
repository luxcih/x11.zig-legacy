//! Parsing of X11 protocol errors returned by the server.
//!
//! Errors identify the failed request through its sequence and opcodes and may
//! include the resource involved in the failure.

const std = @import("std");
const Wire = @import("Wire.zig");
const Endian = std.builtin.Endian;

/// An X11 protocol error returned by the server.
pub const Error = struct {
    pub const size: usize = 32;

    code: u8,
    sequence: u16,
    resource_id: u32,
    minor_opcode: u16,
    major_opcode: u8,

    pub const ParseError = error{
        InvalidLength,
        InvalidResponse,
    };

    /// Parses the standard 32-byte X11 error packet.
    pub fn parse(bytes: []const u8, endian: Endian) ParseError!Error {
        if (bytes.len != size) return error.InvalidLength;
        if (bytes[0] != 0) return error.InvalidResponse;

        return .{
            .code = bytes[1],
            .sequence = Wire.readU16(bytes[2..4], endian),
            .resource_id = Wire.readU32(bytes[4..8], endian),
            .minor_opcode = Wire.readU16(bytes[8..10], endian),
            .major_opcode = bytes[10],
        };
    }
};

test "parse little-endian X11 error" {
    var bytes: [Error.size]u8 = [_]u8{0} ** Error.size;
    bytes[0] = 0;
    bytes[1] = 3;
    Wire.writeU16(bytes[2..4], 0x1234, .little);
    Wire.writeU32(bytes[4..8], 0x01020304, .little);
    Wire.writeU16(bytes[8..10], 0x5678, .little);
    bytes[10] = 42;

    const parsed = try Error.parse(&bytes, .little);
    try std.testing.expectEqual(@as(u8, 3), parsed.code);
    try std.testing.expectEqual(@as(u16, 0x1234), parsed.sequence);
    try std.testing.expectEqual(@as(u32, 0x01020304), parsed.resource_id);
    try std.testing.expectEqual(@as(u16, 0x5678), parsed.minor_opcode);
    try std.testing.expectEqual(@as(u8, 42), parsed.major_opcode);
}

test "parse big-endian X11 error" {
    var bytes: [Error.size]u8 = [_]u8{0} ** Error.size;
    bytes[1] = 3;
    Wire.writeU16(bytes[2..4], 0x1234, .big);
    Wire.writeU32(bytes[4..8], 0x01020304, .big);
    Wire.writeU16(bytes[8..10], 0x5678, .big);
    bytes[10] = 42;

    const parsed = try Error.parse(&bytes, .big);
    try std.testing.expectEqual(@as(u8, 3), parsed.code);
    try std.testing.expectEqual(@as(u16, 0x1234), parsed.sequence);
    try std.testing.expectEqual(@as(u32, 0x01020304), parsed.resource_id);
    try std.testing.expectEqual(@as(u16, 0x5678), parsed.minor_opcode);
    try std.testing.expectEqual(@as(u8, 42), parsed.major_opcode);
}

test "reject malformed X11 errors" {
    var bytes: [Error.size]u8 = [_]u8{0} ** Error.size;

    try std.testing.expectError(error.InvalidLength, Error.parse(bytes[0..31], .little));

    bytes[0] = 1;
    try std.testing.expectError(error.InvalidResponse, Error.parse(&bytes, .little));
}
