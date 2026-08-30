const std = @import("std");
const x11 = @import("x11");

fn connectAndSetup(init: std.process.Init) !struct {
    connection: x11.Connection,
    byte_order: x11.ByteOrder,
    root: u32,
} {
    const display = try x11.Display.parse(":0");
    const tmpdir = init.environ_map.get("TMPDIR") orelse return error.MissingTmpDir;

    var socket_dir_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const socket_dir = try std.fmt.bufPrint(&socket_dir_buffer, "{s}/.X11-unix", .{tmpdir});

    var connection = try x11.Connection.connectLocal(init.io, display, socket_dir);

    const setup = x11.Setup{};
    var setup_buffer: [12]u8 = undefined;
    try connection.writeAll(init.io, try setup.encode(&setup_buffer));

    var read_buffer: [4096]u8 = undefined;
    var reader = connection.reader(init.io, &read_buffer);
    var prefix: [8]u8 = undefined;
    try reader.interface.readSliceAll(&prefix);

    const response = try x11.SetupResponse.parsePrefix(prefix, setup.byte_order);
    const additional = try std.heap.page_allocator.alloc(u8, response.additionalBytes());
    defer std.heap.page_allocator.free(additional);
    try reader.interface.readSliceAll(additional);

    var info = switch (response) {
        .success => try x11.SetupInfo.parse(std.heap.page_allocator, additional, setup.byte_order),
        .failed => return error.SetupFailed,
        .authenticate => return error.AuthenticationRequired,
    };
    defer info.deinit(std.heap.page_allocator);

    return .{
        .connection = connection,
        .byte_order = setup.byte_order,
        .root = info.screens[0].screen.root,
    };
}

pub fn main(init: std.process.Init) !void {
    var state = try connectAndSetup(init);
    defer state.connection.close(init.io);

    const request = x11.Window.GetWindowAttributes{ .window_id = state.root };
    var request_buffer: [x11.Window.GetWindowAttributes.size]u8 = undefined;
    try state.connection.writeAll(init.io, try request.encode(&request_buffer, state.byte_order));

    var read_buffer: [64]u8 = undefined;
    var reader = state.connection.reader(init.io, &read_buffer);
    var reply_bytes: [x11.Window.GetWindowAttributes.reply_size]u8 = undefined;
    try reader.interface.readSliceAll(&reply_bytes);

    const reply = try x11.Window.GetWindowAttributes.Reply.parse(&reply_bytes, state.byte_order);
    std.debug.print("Root attributes: visual=0x{x}, class={}, map_state={}, override_redirect={}\n", .{
        reply.visual, reply.class, reply.map_state, reply.override_redirect,
    });
}
