const std = @import("std");
const x11 = @import("x11");

pub fn main() !void {
    const create = x11.Window.Create{
        .depth = 0,
        .window_id = 1,
        .parent = 2,
        .x = 100,
        .y = 100,
        .width = 640,
        .height = 480,
        .background_pixel = 0xffffff,
    };

    var create_buffer: [x11.Window.Create.size + 4]u8 = undefined;
    const create_bytes = try create.encode(&create_buffer, .little);

    const map = x11.Window.Map{ .window_id = 1 };
    var map_buffer: [x11.Window.Map.size]u8 = undefined;
    const map_bytes = try map.encode(&map_buffer, .little);

    std.debug.print(
        "CreateWindow: {} bytes\nMapWindow: {} bytes\n",
        .{ create_bytes.len, map_bytes.len },
    );
}
