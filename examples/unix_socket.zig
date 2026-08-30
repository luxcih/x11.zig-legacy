const std = @import("std");

pub fn main() !void {
    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer threaded.deinit();

    const io = threaded.io();

    const tmpdir = std.posix.getenv("TMPDIR") orelse return error.MissingTmpDir;

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &path_buffer,
        "{s}/.X11-unix/X1",
        .{tmpdir},
    );

    const address = try std.Io.net.UnixAddress.init(path);

    var stream = try address.connect(io);
    defer stream.socket.close(io);

    std.debug.print("Connected to the X server socket at {s}.\n", .{path});
}
