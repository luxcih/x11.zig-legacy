//! Demonstrates parsing a raw X11 event.
//! For a live event loop, see demo.zig.

const std = @import("std");
const x11 = @import("x11");

pub fn main() !void {
    const event = try x11.Event.parse(&.{
        2,  38, 0,  0,
        0,  0,  0,  0,
        0,  0,  0,  0,
        0,  0,  0,  0,
        0,  0,  0,  0,
        10, 0,  20, 0,
        30, 0,  40, 0,
        0,  0,  1,  0,
    }, .little);

    switch (event) {
        .key_press => |key| std.debug.print(
            "Parsed KeyPress: keycode {} at ({}, {})\n",
            .{ key.detail, key.event_x, key.event_y },
        ),
        else => unreachable,
    }
}
