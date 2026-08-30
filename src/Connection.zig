const std = @import("std");
const Display = @import("Display.zig").Display;
const Response = @import("Response.zig");
const Event = @import("Event.zig").Event;
const ProtocolError = @import("Error.zig").Error;
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

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
        var writer = self.stream.writer(io, bytes);
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

    /// Reads one complete fixed-size X11 server response header.
    ///
    /// Replies may contain additional request-specific data after this header.
    pub fn readResponseHeader(
        self: *Connection,
        response_reader: anytype,
    ) ![Response.size]u8 {
        _ = self;

        var bytes: [Response.size]u8 = undefined;
        try response_reader.interface.readSliceAll(&bytes);
        return bytes;
    }

    /// A classified incoming X11 server message.
    ///
    /// Replies remain raw because their interpretation depends on the request
    /// that produced them.
    pub const Incoming = union(enum) {
        protocol_error: ProtocolError,
        reply: [Response.size]u8,
        event: Event,
    };

    /// Reads and classifies one incoming X11 server response.
    ///
    /// Events and protocol errors are parsed immediately. Replies are returned
    /// as their raw 32-byte header for request-specific parsing.
    pub fn readResponse(
        self: *Connection,
        response_reader: anytype,
        byte_order: ByteOrder,
    ) !Incoming {
        const bytes = try self.readResponseHeader(response_reader);

        return switch (try Response.classify(&bytes)) {
            .protocol_error => .{
                .protocol_error = try ProtocolError.parse(&bytes, byte_order),
            },
            .reply => .{ .reply = bytes },
            .event => .{
                .event = try Event.parse(&bytes, byte_order),
            },
        };
    }

    /// Closes the underlying connection.
    pub fn close(self: *Connection, io: std.Io) void {
        self.stream.socket.close(io);
    }
};


test "Connection.readResponse classifies a protocol error" {
    var bytes: [Response.size]u8 = [_]u8{0} ** Response.size;
    bytes[1] = 3;

    var stream = std.Io.fixedBufferStream(&bytes);
    var connection = Connection.init(undefined);

    const incoming = try connection.readResponse(&stream.reader(), .little);
    switch (incoming) {
        .protocol_error => |protocol_error| {
            try std.testing.expectEqual(@as(u8, 3), protocol_error.code);
        },
        else => return error.UnexpectedResponse,
    }
}

test "Connection.readResponse returns replies as raw headers" {
    var bytes: [Response.size]u8 = [_]u8{0} ** Response.size;
    bytes[0] = 1;

    var stream = std.Io.fixedBufferStream(&bytes);
    var connection = Connection.init(undefined);

    const incoming = try connection.readResponse(&stream.reader(), .little);
    switch (incoming) {
        .reply => |reply| {
            try std.testing.expectEqual(@as(u8, 1), reply[0]);
        },
        else => return error.UnexpectedResponse,
    }
}

test "Connection.readResponse parses events" {
    var bytes: [Response.size]u8 = [_]u8{0} ** Response.size;
    bytes[0] = 12;

    var stream = std.Io.fixedBufferStream(&bytes);
    var connection = Connection.init(undefined);

    const incoming = try connection.readResponse(&stream.reader(), .little);
    switch (incoming) {
        .event => |event| switch (event) {
            .expose => {},
            else => return error.UnexpectedEvent,
        },
        else => return error.UnexpectedResponse,
    }
}

