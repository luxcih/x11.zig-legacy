const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    const request = x11.Window.GetGeometry{ .drawable = session.root };
    var request_buffer: [x11.Window.GetGeometry.size]u8 = undefined;
    try session.connection.writeAll(init.io, try request.encode(&request_buffer, session.byte_order));

    var read_buffer: [64]u8 = undefined;
    var reader = session.connection.reader(init.io, &read_buffer);
    const reply_bytes = try session.connection.readResponseHeader(reader);

    const geometry = try x11.Window.GetGeometry.Reply.parse(&reply_bytes, session.byte_order);
    std.debug.print("Root geometry: {}x{} at ({}, {}), depth {}, border {}\n", .{
        geometry.width, geometry.height, geometry.x, geometry.y, geometry.depth, geometry.border_width,
    });
}
