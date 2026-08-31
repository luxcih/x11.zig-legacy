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

read_buffer: [4096]u8 = undefined,
write_buffer: [1024]u8 = undefined,
reader: std.Io.net.Stream.Reader = undefined,
writer: std.Io.net.Stream.Writer = undefined,

endian: std.builtin.Endian,
setup: SetupInfo,
xids: XidAllocator,

/// Connects to an X server and completes the initial X11 setup handshake.
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

    const setup_request = Setup{};

    try setup_request.encode(&self.writer.interface);
    try self.writer.interface.flush();

    var prefix: [8]u8 = undefined;
    try self.reader.interface.readSliceAll(&prefix);

    const response = try SetupResponse.parsePrefix(prefix, setup_request.endian);

    const additional = try allocator.alloc(u8, response.additionalBytes());
    defer allocator.free(additional);
    try self.reader.interface.readSliceAll(additional);

    self.setup = switch (response) {
        .success => try SetupInfo.parse(allocator, additional, setup_request.endian),
        .failed => return error.SetupFailed,
        .authenticate => return error.AuthenticationRequired,
    };
    errdefer self.setup.deinit(allocator);

    self.endian = setup_request.endian;
    self.xids = XidAllocator.init(
        self.setup.success.resource_id_base,
        self.setup.success.resource_id_mask,
    );

    return self;
}

/// Encodes and sends an X11 request.
pub fn send(self: *Client, request: anytype) !void {
    try request.encode(&self.writer.interface, self.endian);
    try self.writer.interface.flush();
}

/// Receives and decodes an X11 message.
pub fn recv(self: *Client, comptime T: type) !T {
    return T.decode(&self.reader.interface, self.endian);
}

/// Returns the next X resource identifier available to this client.
pub fn nextXid(self: *Client) XidAllocator.Error!u32 {
    return self.xids.next();
}

/// Releases resources owned by the client and closes its connection.
pub fn deinit(self: *Client) void {
    self.setup.deinit(self.allocator);
    self.connection.close(self.io);
    self.allocator.destroy(self);
}
