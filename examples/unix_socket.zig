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
            var setup_info = try x11.SetupInfo.parse(
                std.heap.page_allocator,
                additional,
                setup.byte_order,
            );
            defer setup_info.deinit(std.heap.page_allocator);

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
                    setup_info.success.vendor,
                    setup_info.success.release_number,
                    setup_info.screens.len,
                },
            );

            for (setup_info.pixmap_formats) |format| {
                std.debug.print(
                    "  depth {}: {} bits per pixel, {} scanline pad\n",
                    .{
                        format.depth,
                        format.bits_per_pixel,
                        format.scanline_pad,
                    },
                );
            }


            if (setup_info.screens.len == 0)
                return error.NoScreens;

            const screen = setup_info.screens[0].screen;

            var ids = x11.XidAllocator.init(
                setup_info.success.resource_id_base,
                setup_info.success.resource_id_mask,
            );

            const window_id = try ids.next();

            const create = x11.Window.Create{
                .depth = 0, // CopyFromParent
                .window_id = window_id,
                .parent = screen.root,
                .x = 100,
                .y = 100,
                .width = 640,
                .height = 480,
                .background_pixel = screen.white_pixel,
            };

            var create_buffer: [x11.Window.Create.size + 4]u8 = undefined;
            const create_bytes = try create.encode(
                &create_buffer,
                setup.byte_order,
            );
            try connection.writeAll(init.io, create_bytes);

            const change_attributes = x11.Window.ChangeAttributes{
                .window_id = window_id,
                .event_mask = .{
                    .key_press = true,
                    .key_release = true,
                    .button_press = true,
                    .button_release = true,
                    .pointer_motion = true,
                    .exposure = true,
                    .structure_notify = true,
                },
            };

            var change_attributes_buffer: [x11.Window.ChangeAttributes.size]u8 = undefined;
            const change_attributes_bytes = try change_attributes.encode(
                &change_attributes_buffer,
                setup.byte_order,
            );
            try connection.writeAll(init.io, change_attributes_bytes);

            const map = x11.Window.Map{
                .window_id = window_id,
            };

            var map_buffer: [x11.Window.Map.size]u8 = undefined;
            const map_bytes = try map.encode(
                &map_buffer,
                setup.byte_order,
            );
            try connection.writeAll(init.io, map_bytes);
            std.debug.print("sent MapWindow\n", .{});

            std.debug.print(
                "Created and mapped window 0x{x}\n",
                .{window_id},
            );

            const configure = x11.Window.Configure{
                .window_id = window_id,
                .x = 200,
                .y = 150,
                .width = 800,
                .height = 600,
            };

            var configure_buffer: [28]u8 = undefined;
            const configure_bytes = try configure.encode(
                &configure_buffer,
                setup.byte_order,
            );
            try connection.writeAll(init.io, configure_bytes);

            std.debug.print("Configured window to 800x600 at (200, 150)\n", .{});

            const gc_id = try ids.next();

            const create_gc = x11.GC.Create{
                .drawable = window_id,
                .gc_id = gc_id,
                .foreground = 0x00ff00,
            };

            var gc_buffer: [20]u8 = undefined;
            const gc_bytes = try create_gc.encode(
                &gc_buffer,
                setup.byte_order,
            );
            try connection.writeAll(init.io, gc_bytes);

            const fill = x11.Draw.Fill{
                .drawable = window_id,
                .gc = gc_id,
                .rectangles = &.{
                    .{
                        .x = 100,
                        .y = 100,
                        .width = 300,
                        .height = 200,
                    },
                },
            };

            var fill_buffer: [x11.Draw.Fill.base_size + x11.Draw.Fill.rectangle_size]u8 = undefined;
            const fill_bytes = try fill.encode(
                &fill_buffer,
                setup.byte_order,
            );
            try connection.writeAll(init.io, fill_bytes);

            const line = x11.Draw.Line{
                .drawable = window_id,
                .gc = gc_id,
                .points = &.{
                    .{ .x = 50, .y = 50 },
                    .{ .x = 500, .y = 350 },
                    .{ .x = 700, .y = 100 },
                },
            };

            var line_buffer: [x11.Draw.Line.base_size + 3 * x11.Draw.Line.point_size]u8 = undefined;
            const line_bytes = try line.encode(
                &line_buffer,
                setup.byte_order,
            );
            try connection.writeAll(init.io, line_bytes);

            std.debug.print("Drew rectangle and line\n", .{});

            // Keep the X11 client connection alive and process incoming
            // protocol messages so the server keeps this client's window.
            var message: [32]u8 = undefined;
            while (true) {
                try reader.interface.readSliceAll(&message);

                const event = try x11.Event.parse(&message, setup.byte_order);

                switch (event) {
                    .key_press => |key| {
                        std.debug.print(
                            "KeyPress: keycode {}; exiting\n",
                            .{key.detail},
                        );
                        break;
                    },
                    .key_release => |key| std.debug.print(
                        "KeyRelease: keycode {}\n",
                        .{key.detail},
                    ),
                    .button_press => |button| std.debug.print(
                        "ButtonPress: button {} at ({}, {})\n",
                        .{ button.detail, button.event_x, button.event_y },
                    ),
                    .button_release => |button| std.debug.print(
                        "ButtonRelease: button {} at ({}, {})\n",
                        .{ button.detail, button.event_x, button.event_y },
                    ),
                    .motion_notify => |motion| std.debug.print(
                        "MotionNotify at ({}, {})\n",
                        .{ motion.event_x, motion.event_y },
                    ),
                    .expose => |expose| std.debug.print(
                        "Expose {}x{} at ({}, {})\n",
                        .{ expose.width, expose.height, expose.x, expose.y },
                    ),
                    .map_notify => std.debug.print("MapNotify event\n", .{}),
                    .configure_notify => |configure_notify| std.debug.print(
                        "ConfigureNotify {}x{} at ({}, {})\n",
                        .{ configure_notify.width, configure_notify.height, configure_notify.x, configure_notify.y },
                    ),
                    .unmap_notify => std.debug.print("UnmapNotify event\n", .{}),
                    .destroy_notify => std.debug.print("DestroyNotify event\n", .{}),
                    .unknown => |unknown| std.debug.print(
                        "X11 message type {}\n",
                        .{unknown.response_type},
                    ),
                }
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
