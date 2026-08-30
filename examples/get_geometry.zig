//! Connects to X11 and queries the geometry of the root window.

const std = @import("std");
const x11 = @import("x11");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;

    const display = try x11.Display.parse(":0");

    const tmpdir = init.environ_map.get("TMPDIR") orelse
        return error.MissingTmpDir;

    var socket_dir_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const socket_dir = try std.fmt.bufPrint(
        &socket_dir_buffer,
        "{s}/.X11-unix",
        .{tmpdir},
    );

    var connection = try x11.Connection.connectLocal(
        init.io,
        display,
        socket_dir,
    );
    defer connection.close(init.io);

    const setup = x11.Setup{};
    var setup_buffer: [12]u8 = undefined;
    try connection.writeAll(init.io, try setup.encode(&setup_buffer));

    var read_buffer: [4096]u8 = undefined;
    var reader = connection.reader(init.io, &read_buffer);

    var prefix: [8]u8 = undefined;
    try reader.interface.readSliceAll(&prefix);

    const response = try x11.SetupResponse.parsePrefix(
        prefix,
        setup.byte_order,
    );

    const additional = try allocator.alloc(u8, response.additionalBytes());
    defer allocator.free(additional);
    try reader.interface.readSliceAll(additional);

    const info = switch (response) {
        .success => try x11.SetupInfo.parse(
            allocator,
            additional,
            setup.byte_order,
        ),
        .failed => return error.SetupFailed,
        .authenticate => return error.AuthenticationRequired,
    };
    defer info.deinit(allocator);

    const root = info.screens[0].screen.root;

    const request = x11.Window.GetGeometry{
        .drawable = root,
    };
    var request_buffer: [x11.Window.GetGeometry.size]u8 = undefined;
    try connection.writeAll(
        init.io,
        try request.encode(&request_buffer, setup.byte_order),
    );

    var reply_bytes: [x11.Window.GetGeometry.reply_size]u8 = undefined;
    try reader.interface.readSliceAll(&reply_bytes);

    const geometry = try x11.Window.GetGeometry.Reply.parse(
        &reply_bytes,
        setup.byte_order,
    );

    std.debug.print(
        "Root geometry: {}x{} at ({}, {}), depth {}, border {}\n",
        .{
            geometry.width,
            geometry.height,
            geometry.x,
            geometry.y,
            geometry.depth,
            geometry.border_width,
        },
    );
}
