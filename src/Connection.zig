const std = @import("std");
const Display = @import("Display.zig").Display;

pub const Connection = struct {
    stream: std.Io.net.Stream,

    pub fn init(stream: std.Io.net.Stream) Connection {
        return .{
            .stream = stream,
        };
    }

    /// Connects to a local X server through its Unix-domain socket.
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

    /// Writes an entire X11 protocol message and flushes it to the server.
    pub fn writeAll(
        self: *Connection,
        io: std.Io,
        bytes: []const u8,
    ) !void {
        var writer = self.stream.writer(io, &.{});
        try writer.interface.writeAll(bytes);
        try writer.interface.flush();
    }

    /// Returns a buffered reader for incoming X11 protocol messages.
    pub fn reader(
        self: *Connection,
        io: std.Io,
        buffer: []u8,
    ) std.Io.net.Stream.Reader {
        return self.stream.reader(io, buffer);
    }

    /// Closes the underlying connection.
    pub fn close(self: *Connection, io: std.Io) void {
        self.stream.socket.close(io);
    }
};
