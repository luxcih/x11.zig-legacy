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
            "Expose {}x{}: this is where redrawScene() runs\n",
            .{ expose.width, expose.height },
        ),
        else => unreachable,
    }
}
