//! Performs the one-time X11 connection handshake.

const std = @import("std");
const Client = @import("Client.zig");
const Endian = std.builtin.Endian;
const Wire = @import("Wire.zig");
const Server = @import("Server.zig");

const Handshake = @This();

pub const Result = struct {
    server: Server,
    resource_id_base: u32,
    resource_id_mask: u32,
};

pub fn perform(client: *Client) !Result {
    try client.send(Request{});

    var prefix: [8]u8 = undefined;
    try client.read(&prefix);

    const additional_length = Wire.readU16(prefix[6..8], client.endian);
    const additional_bytes = @as(usize, additional_length) * 4;

    const body = try client.allocator.alloc(u8, additional_bytes);
    defer client.allocator.free(body);
    try client.read(body);

    return switch (prefix[0]) {
        0 => error.SetupFailed,
        1 => .{
            .server = try Server.parse(client.allocator, body, client.endian),
            .resource_id_base = Wire.readU32(body[4..8], client.endian),
            .resource_id_mask = Wire.readU32(body[8..12], client.endian),
        },
        2 => error.AuthenticationRequired,
        else => error.InvalidSetupResponse,
    };
}

const Request = struct {
    pub fn encode(
        _: Request,
        writer: *std.Io.Writer,
        endian: Endian,
    ) !void {
        var request: [12]u8 = undefined;
        request[0] = switch (endian) {
            .little => 'l',
            .big => 'B',
        };
        request[1] = 0;
        Wire.writeU16(request[2..4], 11, endian);
        Wire.writeU16(request[4..6], 0, endian);
        Wire.writeU16(request[6..8], 0, endian);
        Wire.writeU16(request[8..10], 0, endian);
        request[10] = 0;
        request[11] = 0;

        try writer.writeAll(&request);
    }
};

