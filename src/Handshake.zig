//! Performs the one-time X11 connection handshake.

const std = @import("std");
const Endian = std.builtin.Endian;
const Wire = @import("Wire.zig");
const Server = @import("Server.zig");

const Handshake = @This();

pub const Options = struct {
    endian: Endian = .little,
    authorization: ?Authorization = null,
};

pub const Authorization = struct {
    name: []const u8,
    data: []const u8,
};

pub const Result = struct {
    server: Server,
    resource_id_base: u32,
    resource_id_mask: u32,
};

pub fn perform(
    allocator: std.mem.Allocator,
    reader: anytype,
    writer: anytype,
    options: Options,
) !Result {
    try writeRequest(allocator, writer, options);

    var prefix: [8]u8 = undefined;
    try reader.interface.readSliceAll(&prefix);

    const additional_length = Wire.readU16(prefix[6..8], options.endian);
    const additional_bytes = @as(usize, additional_length) * 4;

    const body = try allocator.alloc(u8, additional_bytes);
    defer allocator.free(body);
    try reader.interface.readSliceAll(body);

    return switch (prefix[0]) {
        0 => error.SetupFailed,
        1 => .{
            .server = try Server.parse(allocator, body, options.endian),
            .resource_id_base = Wire.readU32(body[4..8], options.endian),
            .resource_id_mask = Wire.readU32(body[8..12], options.endian),
        },
        2 => error.AuthenticationRequired,
        else => error.InvalidSetupResponse,
    };
}

fn writeRequest(
    allocator: std.mem.Allocator,
    writer: anytype,
    options: Options,
) !void {
    const authorization = options.authorization orelse Authorization{
        .name = "",
        .data = "",
    };

    const name_length = authorization.name.len;
    const data_length = authorization.data.len;
    if (name_length > std.math.maxInt(u16) or data_length > std.math.maxInt(u16)) {
        return error.AuthorizationTooLong;
    }

    const name_end = 12 + name_length;
    const data_offset = paddedLength(name_end);
    const request_length = paddedLength(data_offset + data_length);

    const request = try allocator.alloc(u8, request_length);
    defer allocator.free(request);
    @memset(request, 0);

    request[0] = switch (options.endian) {
        .little => 'l',
        .big => 'B',
    };

    Wire.writeU16(request[2..4], 11, options.endian);
    Wire.writeU16(request[4..6], 0, options.endian);
    Wire.writeU16(request[6..8], @intCast(name_length), options.endian);
    Wire.writeU16(request[8..10], @intCast(data_length), options.endian);

    @memcpy(request[12..name_end], authorization.name);
    @memcpy(
        request[data_offset .. data_offset + data_length],
        authorization.data,
    );

    try writer.interface.writeAll(request);
    try writer.interface.flush();
}

fn paddedLength(length: usize) usize {
    return (length + 3) & ~@as(usize, 3);
}
