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

    const request = x11.Window.QueryTree{ .window_id = state.root };
    var request_buffer: [x11.Window.QueryTree.size]u8 = undefined;
    try state.connection.writeAll(init.io, try request.encode(&request_buffer, state.byte_order));

    var read_buffer: [4096]u8 = undefined;
    var reader = state.connection.reader(init.io, &read_buffer);

    var header_bytes: [x11.Window.QueryTree.reply_header_size]u8 = undefined;
    try reader.interface.readSliceAll(&header_bytes);
    const header = try x11.Window.QueryTree.ReplyHeader.parse(&header_bytes, state.byte_order);

    const children_bytes = try std.heap.page_allocator.alloc(u8, header.childrenBytes());
    defer std.heap.page_allocator.free(children_bytes);
    try reader.interface.readSliceAll(children_bytes);

    const children = try x11.Window.QueryTree.parseChildren(
        std.heap.page_allocator,
        children_bytes,
        header.children_count,
        state.byte_order,
    );
    defer std.heap.page_allocator.free(children);

    std.debug.print("Tree: root=0x{x}, parent=0x{x}, children={}\n", .{
        header.root, header.parent, children.len,
    });
}
