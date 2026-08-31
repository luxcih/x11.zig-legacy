//! High-level X11 client lifecycle.

const std = @import("std");
const Connection = @import("Connection.zig");
const Setup = @import("Setup.zig");
const SetupResponse = @import("SetupResponse.zig");
const SetupInfo = @import("SetupInfo.zig");
const XidAllocator = @import("XidAllocator.zig");

const Client = @This();

const IoState = struct {
    connection: Connection,
    read_buffer: [4096]u8 = undefined,
    write_buffer: [1024]u8 = undefined,
    reader: std.Io.net.Stream.Reader = undefined,
    writer: std.Io.net.Stream.Writer = undefined,

    fn init(
        self: *IoState,
        io: std.Io,
        connection: Connection,
    ) void {
        self.connection = connection;
        self.reader = self.connection.reader(io, &self.read_buffer);
        self.writer = self.connection.writer(io, &self.write_buffer);
    }

    fn deinit(self: *IoState, io: std.Io) void {
        self.connection.close(io);
    }
};

io: std.Io,
allocator: std.mem.Allocator,
io_state: *IoState,
endian: std.builtin.Endian,
setup: SetupInfo,
xids: XidAllocator,

/// Connects to an X server and completes the initial X11 setup handshake.
pub fn connect(
    io: std.Io,
    allocator: std.mem.Allocator,
    display_name: []const u8,
) !Client {
    const io_state = try allocator.create(IoState);
    errdefer allocator.destroy(io_state);

    const connection = try Connection.connect(io, display_name);
    errdefer connection.close(io);

    io_state.init(io, connection);

    const setup_request = Setup{};

    try setup_request.encode(&io_state.writer.interface);
    try io_state.writer.interface.flush();

    var prefix: [8]u8 = undefined;
    try io_state.reader.interface.readSliceAll(&prefix);

    const response = try SetupResponse.parsePrefix(prefix, setup_request.endian);

    const additional = try allocator.alloc(u8, response.additionalBytes());
    defer allocator.free(additional);
    try io_state.reader.interface.readSliceAll(additional);

    var setup_info = switch (response) {
        .success => try SetupInfo.parse(allocator, additional, setup_request.endian),
        .failed => return error.SetupFailed,
        .authenticate => return error.AuthenticationRequired,
    };
    errdefer setup_info.deinit(allocator);

    return .{
        .io = io,
        .allocator = allocator,
        .io_state = io_state,
        .endian = setup_request.endian,
        .setup = setup_info,
        .xids = XidAllocator.init(
            setup_info.success.resource_id_base,
            setup_info.success.resource_id_mask,
        ),
    };
}

/// Encodes and sends an X11 request.
pub fn send(self: *Client, request: anytype) !void {
    try request.encode(&self.io_state.writer.interface, self.endian);
    try self.io_state.writer.interface.flush();
}

/// Receives and decodes an X11 message.
pub fn recv(self: *Client, comptime T: type) !T {
    return T.decode(&self.io_state.reader.interface, self.endian);
}

/// Returns the next X resource identifier available to this client.
pub fn nextXid(self: *Client) XidAllocator.Error!u32 {
    return self.xids.next();
}

/// Releases resources owned by the client and closes its connection.
pub fn deinit(self: *Client) void {
    self.setup.deinit(self.allocator);
    self.io_state.deinit(self.io);
    self.allocator.destroy(self.io_state);
}
