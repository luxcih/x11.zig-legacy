const std = @import("std");
const x11 = @import("x11");

const Scene = struct {
    green_gc: []const u8,
    fill: []const u8,
    draw_gc: []const u8,
    line: []const u8,
    rectangle: []const u8,
    arc: []const u8,
    filled_arc: []const u8,
    text: []const u8,
};

fn drawScene(
    connection: *x11.Connection,
    io: std.Io,
    scene: Scene,
) !void {
    try connection.writeAll(io, scene.green_gc);
    try connection.writeAll(io, scene.fill);

    try connection.writeAll(io, scene.draw_gc);
    try connection.writeAll(io, scene.line);
    try connection.writeAll(io, scene.rectangle);
    try connection.writeAll(io, scene.arc);
    try connection.writeAll(io, scene.filled_arc);
    try connection.writeAll(io, scene.text);
}

fn runEventLoop(
    connection: *x11.Connection,
    io: std.Io,
    reader: anytype,
    byte_order: x11.Setup.ByteOrder,
    gc_id: u32,
    scene: Scene,
) !void {
    var message: [32]u8 = undefined;

    while (true) {
        try reader.interface.readSliceAll(&message);

        const event = try x11.Event.parse(&message, byte_order);

        switch (event) {
            .key_press => |key| {
                std.debug.print(
                    "KeyPress: keycode {}; exiting\n",
                    .{key.detail},
                );

                const free_gc = x11.GC.Free{ .gc_id = gc_id };
                var free_gc_buffer: [x11.GC.Free.size]u8 = undefined;
                const free_gc_bytes = try free_gc.encode(
                    &free_gc_buffer,
                    byte_order,
                );
                try connection.writeAll(io, free_gc_bytes);

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
            .expose => |expose| {
                std.debug.print(
                    "Expose {}x{} at ({}, {}); redrawing\n",
                    .{ expose.width, expose.height, expose.x, expose.y },
                );
                try drawScene(connection, io, scene);
            },
            .map_notify => std.debug.print("MapNotify event\n", .{}),
            .configure_notify => |configure_notify| std.debug.print(
                "ConfigureNotify {}x{} at ({}, {})\n",
                .{
                    configure_notify.width,
                    configure_notify.height,
                    configure_notify.x,
                    configure_notify.y,
                },
            ),
            .unmap_notify => std.debug.print("UnmapNotify event\n", .{}),
            .destroy_notify => std.debug.print("DestroyNotify event\n", .{}),
            .unknown => |unknown| std.debug.print(
                "X11 message type {}\n",
                .{unknown.response_type},
            ),
        }
    }
}

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

            const fill = x11.Draw.PolyFillRectangle{
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

            var fill_buffer: [x11.Draw.PolyFillRectangle.base_size + x11.Draw.PolyFillRectangle.rectangle_size]u8 = undefined;
            const fill_bytes = try fill.encode(
                &fill_buffer,
                setup.byte_order,
            );
            const green_gc = x11.GC.Change{
                .gc_id = gc_id,
                .foreground = 0x00ff00,
            };

            var green_gc_buffer: [16]u8 = undefined;
            const green_gc_bytes = try green_gc.encode(
                &green_gc_buffer,
                setup.byte_order,
            );

            const change_gc = x11.GC.Change{
                .gc_id = gc_id,
                .foreground = 0xff0000,
                .line_width = 6,
            };

            var change_gc_buffer: [24]u8 = undefined;
            const change_gc_bytes = try change_gc.encode(
                &change_gc_buffer,
                setup.byte_order,
            );
            const line = x11.Draw.PolyLine{
                .drawable = window_id,
                .gc = gc_id,
                .points = &.{
                    .{ .x = 50, .y = 50 },
                    .{ .x = 500, .y = 350 },
                    .{ .x = 700, .y = 100 },
                },
            };

            var line_buffer: [x11.Draw.PolyLine.base_size + 3 * x11.Draw.PolyLine.point_size]u8 = undefined;
            const line_bytes = try line.encode(
                &line_buffer,
                setup.byte_order,
            );
            const outline = x11.Draw.PolyRectangle{
                .drawable = window_id,
                .gc = gc_id,
                .rectangles = &.{
                    .{
                        .x = 450,
                        .y = 400,
                        .width = 200,
                        .height = 120,
                    },
                },
            };

            var outline_buffer: [x11.Draw.PolyRectangle.base_size + x11.Draw.PolyRectangle.rectangle_size]u8 = undefined;
            const outline_bytes = try outline.encode(
                &outline_buffer,
                setup.byte_order,
            );
            const arc = x11.Draw.PolyArc{
                .drawable = window_id,
                .gc = gc_id,
                .arcs = &.{
                    .{
                        .x = 300,
                        .y = 250,
                        .width = 150,
                        .height = 150,
                        .angle1 = 0,
                        .angle2 = 360 * 64,
                    },
                },
            };

            var arc_buffer: [x11.Draw.PolyArc.base_size + x11.Draw.PolyArc.arc_size]u8 = undefined;
            const arc_bytes = try arc.encode(
                &arc_buffer,
                setup.byte_order,
            );
            const filled_arc = x11.Draw.PolyFillArc{
                .drawable = window_id,
                .gc = gc_id,
                .arcs = &.{
                    .{
                        .x = 500,
                        .y = 250,
                        .width = 120,
                        .height = 120,
                        .angle1 = 0,
                        .angle2 = 360 * 64,
                    },
                },
            };

            var filled_arc_buffer: [x11.Draw.PolyFillArc.base_size + x11.Draw.PolyFillArc.arc_size]u8 = undefined;
            const filled_arc_bytes = try filled_arc.encode(
                &filled_arc_buffer,
                setup.byte_order,
            );
            const text = x11.Draw.ImageText8{
                .drawable = window_id,
                .gc = gc_id,
                .x = 100,
                .y = 550,
                .text = "Hello from x11.zig!",
            };

            var text_buffer: [64]u8 = undefined;
            const text_bytes = try text.encode(
                &text_buffer,
                setup.byte_order,
            );
            const scene = Scene{
                .green_gc = green_gc_bytes,
                .fill = fill_bytes,
                .draw_gc = change_gc_bytes,
                .line = line_bytes,
                .rectangle = outline_bytes,
                .arc = arc_bytes,
                .filled_arc = filled_arc_bytes,
                .text = text_bytes,
            };

            try drawScene(&connection, init.io, scene);

            std.debug.print(
                "Drew rectangle, line, outline, circle, and filled circle\n",
                .{},
            );

            try runEventLoop(
                &connection,
                init.io,
                &reader,
                setup.byte_order,
                gc_id,
                scene,
            );
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
