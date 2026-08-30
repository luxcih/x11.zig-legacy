const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    const request = x11.Window.GetWindowAttributes{ .window_id = session.root };
    var request_buffer: [x11.Window.GetWindowAttributes.size]u8 = undefined;
    try session.connection.writeAll(init.io, try request.encode(&request_buffer, session.byte_order));

    var read_buffer: [64]u8 = undefined;
    var reader = session.connection.reader(init.io, &read_buffer);
    var reply_bytes: [x11.Window.GetWindowAttributes.reply_size]u8 = undefined;
    try reader.interface.readSliceAll(&reply_bytes);

    const reply = try x11.Window.GetWindowAttributes.Reply.parse(&reply_bytes, session.byte_order);
    std.debug.print("Root attributes: visual=0x{x}, class={}, map_state={}, override_redirect={}\n", .{
        reply.visual, reply.class, reply.map_state, reply.override_redirect,
    });
}
