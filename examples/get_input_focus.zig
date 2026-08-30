const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    var request_buffer: [x11.Input.GetInputFocus.size]u8 = undefined;
    try session.connection.writeAll(init.io, try x11.Input.GetInputFocus.encode(&request_buffer, session.byte_order));

    var read_buffer: [64]u8 = undefined;
    var reader = session.connection.reader(init.io, &read_buffer);
    const reply_bytes = try session.connection.readResponseHeader(reader);

    const reply = try x11.Input.GetInputFocus.Reply.parse(&reply_bytes, session.byte_order);
    std.debug.print("Input focus: window=0x{x}, revert_to={s}\n", .{ reply.focus, @tagName(reply.revert_to) });
}
