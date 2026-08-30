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
            const setup_success = try x11.SetupSuccess.parse(
                additional,
                setup.byte_order,
            );

            std.debug.print(
                "X11 setup succeeded: {}.{}\n",
                .{
                    success.major_version,
                    success.minor_version,
                },
            );
            std.debug.print(
                "Vendor: {s}\nRelease: {}\nScreens: {}\nPixmap formats:\n",
                .{
                    setup_success.vendor,
                    setup_success.release_number,
                    setup_success.screen_count,
                },
            );

            const formats_offset = setup_success.pixmapFormatsOffset();
            const formats_length = setup_success.pixmapFormatsLength();
            const formats = additional[
                formats_offset .. formats_offset + formats_length
            ];

            for (0..setup_success.pixmap_format_count) |index| {
                const offset = index * x11.PixmapFormat.size;
                const format = try x11.PixmapFormat.parse(
                    formats[offset .. offset + x11.PixmapFormat.size],
                );

                std.debug.print(
                    "  depth {}: {} bits per pixel, {} scanline pad\n",
                    .{
                        format.depth,
                        format.bits_per_pixel,
                        format.scanline_pad,
                    },
                );
            }

            const screen_offset = setup_success.screensOffset();
            const screen = try x11.Screen.parse(
                additional[screen_offset .. screen_offset + x11.Screen.size],
                setup.byte_order,
            );

            std.debug.print(
                "Root screen: {}x{} pixels, depth {}\n",
                .{
                    screen.width_pixels,
                    screen.height_pixels,
                    screen.root_depth,
                },
            );

            var depth_offset = screen_offset + x11.Screen.size;

            for (0..screen.depth_count) |depth_index| {
                _ = depth_index;

                const depth = try x11.Depth.parse(
                    additional[depth_offset .. depth_offset + x11.Depth.size],
                    setup.byte_order,
                );

                std.debug.print(
                    "  Depth {} ({} visuals):\n",
                    .{ depth.depth, depth.visual_count },
                );

                var visual_offset = depth_offset + depth.visualsOffset();

                for (0..depth.visual_count) |_| {
                    const visual = try x11.VisualType.parse(
                        additional[
                            visual_offset ..
                                visual_offset + x11.VisualType.size
                        ],
                        setup.byte_order,
                    );

                    std.debug.print(
                        "    visual 0x{x}: {s}, {} RGB bits\n",
                        .{
                            visual.visual_id,
                            @tagName(visual.class),
                            visual.bits_per_rgb_value,
                        },
                    );

                    visual_offset += x11.VisualType.size;
                }

                depth_offset += depth.totalLength();
            }

        },
        .failed => |failed| {
            std.debug.print(
                "X11 setup failed: version {}.{} ({} additional bytes)\n",
                .{
                    failed.major_version,
                    failed.minor_version,
                    additional.len,
                },
            );
        },
        .authenticate => {
            std.debug.print(
                "X11 setup requires authentication ({} additional bytes)\n",
                .{additional.len},
            );
        },
    }
}
