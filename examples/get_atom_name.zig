const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    const request = x11.Atom.GetName{ .atom = 39 };
    var request_buffer: [x11.Atom.GetName.request_size]u8 = undefined;
    try session.connection.writeAll(init.io, try request.encode(&request_buffer, session.byte_order));

    var read_buffer: [256]u8 = undefined;
    var reader = session.connection.reader(init.io, &read_buffer);
    const header = try session.connection.readResponseHeader(&reader);
    const name_length = switch (session.byte_order) {
        .little => @as(u16, header[8]) | (@as(u16, header[9]) << 8),
        .big => (@as(u16, header[8]) << 8) | @as(u16, header[9]),
    };
    const padded = std.mem.alignForward(usize, @as(usize, name_length), 4);
    const body = try init.arena.allocator().alloc(u8, padded);
    try reader.interface.readSliceAll(body);

    const reply = try x11.Atom.GetName.Reply.parse(&header, body, session.byte_order);
    std.debug.print("atom {d}: {s}\n", .{ request.atom, reply.name });
}
