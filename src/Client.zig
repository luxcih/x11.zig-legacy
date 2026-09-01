//! High-level X11 client lifecycle.

const std = @import("std");
const Connection = @import("Connection.zig");
const Handshake = @import("Handshake.zig");
const Server = @import("Server.zig");
const XidAllocator = @import("Xid/Allocator.zig");

const Client = @This();

io: std.Io,
allocator: std.mem.Allocator,
connection: Connection,

read_buffer: [4096]u8 = undefined,
write_buffer: [1024]u8 = undefined,
reader: std.Io.net.Stream.Reader = undefined,
writer: std.Io.net.Stream.Writer = undefined,

endian: std.builtin.Endian,
server: Server,
xids: XidAllocator,

/// Connects to an X server and completes the initial X11 handshake.
pub fn connect(
    io: std.Io,
    allocator: std.mem.Allocator,
    display_name: []const u8,
) !*Client {
    const self = try allocator.create(Client);
    errdefer allocator.destroy(self);

    self.io = io;
    self.allocator = allocator;
    self.connection = try Connection.connect(io, display_name);
    errdefer self.connection.close(io);

    self.reader = self.connection.reader(io, &self.read_buffer);
    self.writer = self.connection.writer(io, &self.write_buffer);

    self.endian = .little;

    self.server = try Handshake.perform(self);
    errdefer self.server.deinit(allocator);
    self.xids = XidAllocator.init(
        self.server.resource_id_base,
        self.server.resource_id_mask,
    );

    return self;
}

/// Writes raw bytes to the connection.
pub fn write(self: *Client, bytes: []const u8) !void {
    try self.writer.interface.writeAll(bytes);
}

/// Reads exactly the requested number of raw bytes from the connection.
pub fn read(self: *Client, bytes: []u8) !void {
    try self.reader.interface.readSliceAll(bytes);
}

/// Flushes buffered outgoing data to the connection.
pub fn flush(self: *Client) !void {
    try self.writer.interface.flush();
}

/// Encodes an X11 request to the connection.
pub fn send(self: *Client, request: anytype) !void {
    try request.encode(&self.writer.interface, self.endian);
}

/// Receives a fixed-size X11 protocol value.
pub fn recv(self: *Client, comptime T: type) !T {
    var bytes: [T.size]u8 = undefined;
    try self.read(&bytes);
    return T.parse(&bytes, self.endian);
}

/// Returns the next X resource identifier available to this client.
pub fn nextXid(self: *Client) XidAllocator.Error!u32 {
    return self.xids.next();
}

/// Releases resources owned by the client and closes its connection.
pub fn deinit(self: *Client) void {
    self.server.deinit(self.allocator);
    self.connection.close(self.io);
    self.allocator.destroy(self);
}
