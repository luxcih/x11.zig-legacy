//! High-level X11 client lifecycle.

const std = @import("std");
const Connection = @import("Connection.zig");
const Setup = @import("Setup.zig");
const SetupResponse = @import("SetupResponse.zig");
const SetupInfo = @import("SetupInfo.zig");
const XidAllocator = @import("XidAllocator.zig");

const Client = @This();

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
    var setup_buffer: [12]u8 = undefined;

    var write_buffer: [1024]u8 = undefined;
    var writer = connection.writer(io, &write_buffer);
    try writer.interface.writeAll(try setup_request.encode(&setup_buffer));
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
        .allocator = allocator,
        .connection = connection,
        .byte_order = setup_request.byte_order,
        .setup = setup_info,
        .xids = XidAllocator.init(setup_info.success.resource_id_base, setup_info.success.resource_id_mask),
    };
}



/// Writes raw bytes to the X server.
fn write(self: *Client, io: std.Io, bytes: []const u8) !void {
    var buffer: [1024]u8 = undefined;
    var writer = self.connection.writer(io, &buffer);

    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
}


/// Writes raw bytes to the X server.
fn write(self: *Client, io: std.Io, bytes: []const u8) !void {
    var buffer: [1024]u8 = undefined;
    var writer = self.connection.writer(io, &buffer);

    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
}

/// Returns the next X resource identifier available to this client.
pub fn nextXid(self: *Client) XidAllocator.Error!u32 {
    return self.xids.next();
}

/// Releases resources owned by the client and closes its connection.
pub fn deinit(self: *Client, io: std.Io) void {
    self.setup.deinit(self.allocator);
    self.connection.close(io);
}
