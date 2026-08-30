const std = @import("std");

pub fn main() !void {
    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer threaded.deinit();

    const io = threaded.io();

    const address = try std.Io.net.UnixAddress.init("/tmp/.X11-unix/X0");

    var stream = try address.connect(io);
    defer stream.socket.close(io);

    std.debug.print("Connected to the X server socket.\n", .{});
}
