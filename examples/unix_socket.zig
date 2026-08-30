const std = @import("std");
const x11 = @import("x11");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const display = try x11.Display.parse(":0");

    const tmpdir = init.environ_map.get("TMPDIR") orelse
        return error.MissingTmpDir;

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &path_buffer,
        "{s}/.X11-unix/X{}",
        .{ tmpdir, display.number },
    );

    const address = try std.Io.net.UnixAddress.init(path);

    var stream = try address.connect(io);
    defer stream.socket.close(io);

    std.debug.print("Connected to display {} at {s}.\n", .{
        display.number,
        path,
    });
}
