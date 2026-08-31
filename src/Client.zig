//! High-level X11 client lifecycle.

const std = @import("std");
const Connection = @import("Connection.zig");
const Setup = @import("Setup.zig");
const SetupResponse = @import("SetupResponse.zig");
const SetupInfo = @import("SetupInfo.zig");
const XidAllocator = @import("XidAllocator.zig");

const Client = @This();

io: std.Io,
allocator: std.mem.Allocator,
connection: Connection,
byte_order: std.builtin.Endian,
setup: SetupInfo,
xids: XidAllocator,

/// Connects to an X server and completes the initial X11 setup handshake.
pub fn connect(
    io: std.Io,
    allocator: std.mem.Allocator,
    display_name: []const u8,
) !Client {
    var connection = try Connection.connect(io, display_name);
    errdefer connection.close(io);

    const setup_request = Setup{};

    var write_buffer: [1024]u8 = undefined;
    var writer = connection.writer(io, &write_buffer);
    try setup_request.encode(&writer.interface);
    try writer.interface.flush();

    var read_buffer: [4096]u8 = undefined;
    var reader = connection.reader(io, &read_buffer);

    var prefix: [8]u8 = undefined;
    try reader.interface.readSliceAll(&prefix);

    const response = try SetupResponse.parsePrefix(prefix, setup_request.byte_order);

    const additional = try allocator.alloc(u8, response.additionalBytes());
    defer allocator.free(additional);
    try reader.interface.readSliceAll(additional);

    var setup_info = switch (response) {
        .success => try SetupInfo.parse(allocator, additional, setup_request.byte_order),
        .failed => return error.SetupFailed,
        .authenticate => return error.AuthenticationRequired,
    };
    errdefer setup_info.deinit(allocator);

    return .{
        .io = io,
        .allocator = allocator,
        .connection = connection,
        .byte_order = setup_request.byte_order,
        .setup = setup_info,
        .xids = XidAllocator.init(setup_info.success.resource_id_base, setup_info.success.resource_id_mask),
    };
}

/// Encodes and sends an X11 request.
pub fn send(self: *Client, request: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var writer = self.connection.writer(self.io, &buffer);

    try request.encode(&writer.interface, self.byte_order);
    try writer.interface.flush();
}

/// Receives and decodes an X11 message.
pub fn recv(self: *Client, comptime T: type) !T {
    var buffer: [4096]u8 = undefined;
    var reader = self.connection.reader(self.io, &buffer);

    return T.decode(&reader.interface, self.byte_order);
}

/// Returns the next X resource identifier available to this client.
pub fn nextXid(self: *Client) XidAllocator.Error!u32 {
    return self.xids.next();
}

/// Releases resources owned by the client and closes its connection.
pub fn deinit(self: *Client) void {
    self.setup.deinit(self.allocator);
    self.connection.close(self.io);
}
