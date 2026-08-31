//! Performs the one-time X11 connection handshake.

const std = @import("std");
const Endian = std.builtin.Endian;
const Wire = @import("Wire.zig");
const Server = @import("Server.zig");

const Handshake = @This();

pub const Result = struct {
    server: Server,
    resource_id_base: u32,
    resource_id_mask: u32,
};

pub fn perform(
    allocator: std.mem.Allocator,
    reader: anytype,
    writer: anytype,
    endian: Endian,
) !Result {
    var request: [12]u8 = undefined;
    encodeRequest(&request, endian);

    try writer.interface.writeAll(&request);
    try writer.interface.flush();

    var prefix: [8]u8 = undefined;
    try reader.interface.readSliceAll(&prefix);

    const additional_length = Wire.readU16(prefix[6..8], endian);
    const additional_bytes = @as(usize, additional_length) * 4;

    const body = try allocator.alloc(u8, additional_bytes);
    defer allocator.free(body);
    try reader.interface.readSliceAll(body);

    return switch (prefix[0]) {
        0 => error.SetupFailed,
        1 => .{
            .server = try Server.parse(allocator, body, endian),
            .resource_id_base = Wire.readU32(body[4..8], endian),
            .resource_id_mask = Wire.readU32(body[8..12], endian),
        },
        2 => error.AuthenticationRequired,
        else => error.InvalidSetupResponse,
    };
}

fn encodeRequest(buffer: []u8, endian: Endian) void {
    buffer[0] = switch (endian) {
        .little => 'l',
        .big => 'B',
    };
    buffer[1] = 0;

    Wire.writeU16(buffer[2..4], 11, endian);
    Wire.writeU16(buffer[4..6], 0, endian);
    Wire.writeU16(buffer[6..8], 0, endian);
    Wire.writeU16(buffer[8..10], 0, endian);
    buffer[10] = 0;
    buffer[11] = 0;
}
