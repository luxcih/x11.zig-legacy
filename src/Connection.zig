//! Transport layer for a single connection to an X server.
//!
//! Connection owns the byte stream used to communicate with an X server.
//! It does not interpret the X11 protocol; higher layers build on its reader
//! and writer to exchange protocol messages.

const std = @import("std");
const builtin = @import("builtin");
const Display = @import("Display.zig");

const Connection = @This();

stream: std.Io.net.Stream,

/// Connects to an X server identified by a display name.
pub fn connect(io: std.Io, display_name: []const u8) !Connection {
    const display = try Display.parse(display_name);

    return switch (display.separator) {
        .double_colon => error.UnsupportedTransport,
        .colon => if (display.host.len == 0)
            connectLocal(io, display)
        else
            connectTcp(io, display),
    };
}

/// Connects to a local X server through its Unix-domain socket.
fn connectLocal(
    io: std.Io,
    display: Display,
) !Connection {
    const temp_dir = if (builtin.os.tag == .android)
        std.posix.getenv("TMPDIR") orelse "/tmp"
    else
        "/tmp";

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &path_buffer,
        "{s}/.X11-unix/X{}",
        .{ temp_dir, display.display_number },
    );

    const address = try std.Io.net.UnixAddress.init(path);
    const stream = try address.connect(io);

    return .{ .stream = stream };
}

/// Connects to a remote X server through TCP.
fn connectTcp(
    io: std.Io,
    display: Display,
) !Connection {
    const port = std.math.add(
        u16,
        6000,
        std.math.cast(u16, display.display_number) orelse return error.InvalidDisplayNumber,
    ) catch return error.InvalidDisplayNumber;

    const host: std.Io.net.HostName = try .init(display.host);
    const stream = try host.connect(io, port, .{ .mode = .stream });

    return .{ .stream = stream };
}

/// Returns a buffered writer for outgoing data on this connection.
pub fn writer(
    self: *Connection,
    io: std.Io,
    buffer: []u8,
) std.Io.net.Stream.Writer {
    return self.stream.writer(io, buffer);
}

/// Returns a buffered reader for incoming data from this connection.
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
