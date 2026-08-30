const std = @import("std");
const x11 = @import("x11");
const Wire = @import("../src/Wire.zig");
const common = @import("common.zig");

fn getAtomName(
    session: *common.Session,
    io: std.Io,
    atom: u32,
) ![]u8 {
    const request = x11.Atom.GetName{ .atom = atom };
    var request_buffer: [x11.Atom.GetName.request_size]u8 = undefined;
    try session.connection.writeAll(io, try request.encode(&request_buffer, session.byte_order));

    var read_buffer: [256]u8 = undefined;
    var reader = session.connection.reader(io, &read_buffer);
    const header = try session.connection.readResponseHeader(&reader);
    const reply = try x11.Atom.GetName.Reply.parsePrefix(&header, session.byte_order);

    const padded = std.mem.alignForward(usize, reply.name_length, 4);
    const name = try std.heap.page_allocator.alloc(u8, padded);
    try reader.interface.readSliceAll(name);
    return name[0..reply.name_length];
}

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    const request = x11.Window.ListProperties{ .window_id = session.root };
    var request_buffer: [x11.Window.ListProperties.request_size]u8 = undefined;
    try session.connection.writeAll(init.io, try request.encode(&request_buffer, session.byte_order));

    var read_buffer: [256]u8 = undefined;
    var reader = session.connection.reader(init.io, &read_buffer);
    const header = try session.connection.readResponseHeader(&reader);
    const count = Wire.readU16(header[8..10], session.byte_order);

    const atoms_bytes = try init.arena.allocator().alloc(u8, @as(usize, count) * 4);
    try reader.interface.readSliceAll(atoms_bytes);

    const reply = try x11.Window.ListProperties.Reply.parse(
        init.arena.allocator(),
        &header,
        atoms_bytes,
        session.byte_order,
    );
    defer reply.deinit(init.arena.allocator());

    for (reply.atoms) |atom| {
        const name = getAtomName(&session, init.io, atom) catch continue;
        defer std.heap.page_allocator.free(name.ptr[0 .. std.mem.alignForward(usize, name.len, 4)]);
        std.debug.print("0x{x}: {s}\n", .{ atom, name });
    }
}
