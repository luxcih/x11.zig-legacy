//! Demonstrates how an Expose event triggers application redraw logic.
//! For a live redraw loop, see demo.zig.

const std = @import("std");
const x11 = @import("x11");

pub fn main() !void {
    const event = try x11.Event.parse(&.{
        12, 0, 0, 0,
        1, 0, 0, 0,
        0, 0, 0, 0,
        128, 2, 224, 1,
        0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, .little);

    switch (event) {
        .expose => |expose| std.debug.print(
            "Expose {}x{}: a real client would redraw here\n",
            .{ expose.width, expose.height },
        ),
        else => unreachable,
    }
}
