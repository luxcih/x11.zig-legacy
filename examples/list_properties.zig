const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    const request = x11.Window.ListProperties{
        .window_id = session.root,
    };

    var request_buffer: [x11.Window.ListProperties.request_size]u8 = undefined;
    try session.connection.writeAll(
        init.io,
        try request.encode(&request_buffer, session.byte_order),
    );

    var read_buffer: [64]u8 = undefined;
    var reader = session.connection.reader(init.io, &read_buffer);

    const header = try session.connection.readResponseHeader(&reader);
    const count = x11.Wire.readU16(header[8..10], session.byte_order);

    var atoms_bytes = try init.arena.allocator().alloc(u8, @as(usize, count) * 4);
    try reader.interface.readSliceAll(atoms_bytes);

    var reply = try x11.Window.ListProperties.Reply.parse(
        init.arena.allocator(),
        &header,
        atoms_bytes,
        session.byte_order,
    );

    for (reply.atoms) |atom| {
        std.debug.print("0x{x}\n", .{atom});
    }
}
