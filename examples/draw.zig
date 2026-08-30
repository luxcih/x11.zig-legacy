const std = @import("std");
const x11 = @import("x11");

pub fn main() !void {
    const line = x11.Draw.PolyLine{
        .drawable = 1,
        .gc = 2,
        .points = &.{ .{ .x = 10, .y = 10 }, .{ .x = 200, .y = 100 } },
    };
    var line_buffer: [x11.Draw.PolyLine.base_size + 2 * x11.Draw.PolyLine.point_size]u8 = undefined;
    const line_bytes = try line.encode(&line_buffer, .little);

    const text = x11.Draw.ImageText8{
        .drawable = 1,
        .gc = 2,
        .x = 10,
        .y = 30,
        .text = "x11.zig",
    };
    var text_buffer: [32]u8 = undefined;
    const text_bytes = try text.encode(&text_buffer, .little);

    std.debug.print(
        "PolyLine: {} bytes\nImageText8: {} bytes\n",
        .{ line_bytes.len, text_bytes.len },
    );
}
