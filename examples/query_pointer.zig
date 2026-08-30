const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    const request = x11.Window.QueryPointer{ .window_id = session.root };
    var request_buffer: [x11.Window.QueryPointer.size]u8 = undefined;
    try session.connection.writeAll(
        init.io,
        try request.encode(&request_buffer, session.byte_order),
    );

    var read_buffer: [64]u8 = undefined;
    var reader = session.connection.reader(init.io, &read_buffer);
    const reply_bytes = try session.connection.readResponseHeader(&reader);
    const pointer = try x11.Window.QueryPointer.Reply.parse(
        &reply_bytes,
        session.byte_order,
    );

    std.debug.print(
        "Pointer: root ({}, {}), window ({}, {}), child {x}, mask {x}\n",
        .{ pointer.root_x, pointer.root_y, pointer.win_x, pointer.win_y, pointer.child, pointer.mask },
    );
}
