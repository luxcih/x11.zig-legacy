//! Demonstrates encoding graphics-context requests.
//! For a real GC used for drawing, see demo.zig.

const std = @import("std");
const x11 = @import("x11");

pub fn main() !void {
    const create = x11.GC.Create{
        .drawable = 1,
        .gc_id = 2,
        .values = .{ .foreground = 0xff0000 },
    };
    var create_buffer: [x11.GC.Create.size + 4]u8 = undefined;
    const create_bytes = try create.encode(&create_buffer, .little);

    const change = x11.GC.Change{
        .gc_id = 2,
        .values = .{
            .foreground = 0x00ff00,
            .line_width = 6,
        },
    };
    var change_buffer: [x11.GC.Change.base_size + 8]u8 = undefined;
    const change_bytes = try change.encode(&change_buffer, .little);

    const free = x11.GC.Free{ .gc_id = 2 };
    var free_buffer: [x11.GC.Free.size]u8 = undefined;
    const free_bytes = try free.encode(&free_buffer, .little);

    std.debug.print(
        "Encoded GC requests:\n  CreateGC: {} bytes\n  ChangeGC: {} bytes\n  FreeGC: {} bytes\n",
        .{ create_bytes.len, change_bytes.len, free_bytes.len },
    );
}
