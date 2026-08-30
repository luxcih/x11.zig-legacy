const std = @import("std");
const Display = @import("Display.zig").Display;

pub const Connection = struct {
    stream: std.Io.net.Stream,

    pub fn init(stream: std.Io.net.Stream) Connection {
        return .{
            .stream = stream,
        };
    }

    pub fn connectLocal(
        io: std.Io,
        display: Display,
        socket_dir: []const u8,
    ) !Connection {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const path = try std.fmt.bufPrint(
            &path_buffer,
            "{s}/X{}",
            .{ socket_dir, display.number },
        );

        const address = try std.Io.net.UnixAddress.init(path);
        const stream = try address.connect(io);

        return init(stream);
    }

    pub fn close(self: *Connection, io: std.Io) void {
        self.stream.socket.close(io);
    }
};
