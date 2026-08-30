const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    const request = x11.Window.QueryTree{ .window_id = session.root };
    var request_buffer: [x11.Window.QueryTree.size]u8 = undefined;
    try session.connection.writeAll(init.io, try request.encode(&request_buffer, session.byte_order));

    var read_buffer: [4096]u8 = undefined;
    var reader = session.connection.reader(init.io, &read_buffer);
    var header_bytes: [x11.Window.QueryTree.reply_header_size]u8 = undefined;
    try reader.interface.readSliceAll(&header_bytes);

    const header = try x11.Window.QueryTree.ReplyHeader.parse(&header_bytes, session.byte_order);
    const allocator = std.heap.page_allocator;
    const children_bytes = try allocator.alloc(u8, header.childrenBytes());
    defer allocator.free(children_bytes);
    try reader.interface.readSliceAll(children_bytes);

    const children = try x11.Window.QueryTree.parseChildren(allocator, children_bytes, header.children_count, session.byte_order);
    defer allocator.free(children);

    std.debug.print("Tree: root=0x{x}, parent=0x{x}, children={}\n", .{ header.root, header.parent, children.len });
}
