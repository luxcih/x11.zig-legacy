const std = @import("std");
const x11 = @import("x11");

pub const Session = struct {
    connection: x11.Connection,
    byte_order: x11.ByteOrder,
    root: u32,

    pub fn close(self: *Session, io: std.Io) void {
        self.connection.close(io);
    }
};

pub fn connectAndSetup(init: std.process.Init) !Session {
    const allocator = std.heap.page_allocator;
    const display = try x11.Display.parse(":0");
    const tmpdir = init.environ_map.get("TMPDIR") orelse return error.MissingTmpDir;

    var socket_dir_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const socket_dir = try std.fmt.bufPrint(&socket_dir_buffer, "{s}/.X11-unix", .{tmpdir});

    var connection = try x11.Connection.connectLocal(init.io, display, socket_dir);
    errdefer connection.close(init.io);

    const setup = x11.Setup{};
    var setup_buffer: [12]u8 = undefined;
    try connection.writeAll(init.io, try setup.encode(&setup_buffer));

    var read_buffer: [4096]u8 = undefined;
    var reader = connection.reader(init.io, &read_buffer);
    var prefix: [8]u8 = undefined;
    try reader.interface.readSliceAll(&prefix);

    const response = try x11.SetupResponse.parsePrefix(prefix, setup.byte_order);
    const additional = try allocator.alloc(u8, response.additionalBytes());
    defer allocator.free(additional);
    try reader.interface.readSliceAll(additional);

    var info = switch (response) {
        .success => try x11.SetupInfo.parse(allocator, additional, setup.byte_order),
        .failed => return error.SetupFailed,
        .authenticate => return error.AuthenticationRequired,
    };
    defer info.deinit(allocator);

    return .{ .connection = connection, .byte_order = setup.byte_order, .root = info.screens[0].screen.root };
}
