const std = @import("std");
const x11 = @import("x11");

pub fn main(init: std.process.Init) !void {
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
    const request = try setup.encode(&setup_buffer);
    try connection.writeAll(init.io, request);

    var read_buffer: [4096]u8 = undefined;
    var reader = connection.reader(init.io, &read_buffer);

    var prefix: [8]u8 = undefined;
    try reader.interface.readSliceAll(&prefix);

    const response = try x11.SetupResponse.parsePrefix(
        prefix,
        setup.byte_order,
    );

    const additional_length = response.additionalBytes();
    const additional = try std.heap.page_allocator.alloc(
        u8,
        additional_length,
    );
    defer std.heap.page_allocator.free(additional);

    try reader.interface.readSliceAll(additional);

    switch (response) {
        .success => |success| {
            var info = try x11.SetupInfo.parse(
                std.heap.page_allocator,
                additional,
                setup.byte_order,
            );
            defer info.deinit(std.heap.page_allocator);

            std.debug.print(
                "Connected to X11 {}.{}\nVendor: {s}\nScreens: {}\n",
                .{
                    success.major_version,
                    success.minor_version,
                    info.success.vendor,
                    info.screens.len,
                },
            );

            for (info.screens, 0..) |parsed_screen, index| {
                const screen = parsed_screen.screen;
                std.debug.print(
                    "Screen {}: root=0x{x}, {}x{}, depth {}\n",
                    .{
                        index,
                        screen.root,
                        screen.width_in_pixels,
                        screen.height_in_pixels,
                        screen.root_depth,
                    },
                );
            }
        },
        .failed => |failed| {
            std.debug.print(
                "X11 setup failed: version {}.{}\n",
                .{ failed.major_version, failed.minor_version },
            );
        },
        .authenticate => {
            std.debug.print("X11 requested authentication\n", .{});
        },
    }
}
