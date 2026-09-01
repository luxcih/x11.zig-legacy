//! Performs the one-time X11 connection handshake.

const std = @import("std");
const Client = @import("Client.zig");
const Endian = std.builtin.Endian;
const Wire = @import("Wire.zig");
const Server = @import("Server.zig");

const Handshake = @This();

pub fn perform(client: *Client) !Server {
    try client.send(Request{});
    try client.flush();

    const response = try client.recv(Response.Header);

    return switch (response.status) {
        .failed => error.HandshakeFailed,
        .success => try Server.receive(client),
        .authenticate => error.AuthenticationRequired,
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

const Response = struct {
    const Status = enum(u8) {
        failed = 0,
        success = 1,
        authenticate = 2,

        _,
    };

    const Header = struct {
        status: Status,
        protocol_major_version: u16,
        protocol_minor_version: u16,
        additional_length: u16,

        pub const size = 8;

        pub fn parse(
            bytes: []const u8,
            endian: Endian,
        ) !Header {
            return .{
                .status = @enumFromInt(bytes[0]),
                .protocol_major_version = Wire.readU16(bytes[2..4], endian),
                .protocol_minor_version = Wire.readU16(bytes[4..6], endian),
                .additional_length = Wire.readU16(bytes[6..8], endian),
            };
        }
    };
};


test "Response.Header parses a successful handshake response" {
    const header = try Response.Header.parse(
        &.{ 1, 0, 11, 0, 0, 0, 32, 0 },
        .little,
    );

    try std.testing.expectEqual(Response.Status.success, header.status);
    try std.testing.expectEqual(@as(u16, 11), header.protocol_major_version);
    try std.testing.expectEqual(@as(u16, 0), header.protocol_minor_version);
    try std.testing.expectEqual(@as(u16, 32), header.additional_length);
}

test "Response.Header parses a failed handshake response" {
    const header = try Response.Header.parse(
        &.{ 0, 5, 11, 0, 0, 0, 4, 0 },
        .little,
    );

    try std.testing.expectEqual(Response.Status.failed, header.status);
    try std.testing.expectEqual(@as(u16, 11), header.protocol_major_version);
    try std.testing.expectEqual(@as(u16, 0), header.protocol_minor_version);
    try std.testing.expectEqual(@as(u16, 4), header.additional_length);
}

test "Response.Header parses an authentication response" {
    const header = try Response.Header.parse(
        &.{ 2, 0, 0, 0, 0, 0, 8, 0 },
        .little,
    );

    try std.testing.expectEqual(Response.Status.authenticate, header.status);
    try std.testing.expectEqual(@as(u16, 8), header.additional_length);
}
