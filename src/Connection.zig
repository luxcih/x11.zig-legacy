const std = @import("std");

pub const Connection = struct {
    stream: std.Io.net.Stream,

    pub fn init(stream: std.Io.net.Stream) Connection {
        return .{
            .stream = stream,
        };
    }

    pub fn close(self: *Connection, io: std.Io) void {
        self.stream.socket.close(io);
    }
};
