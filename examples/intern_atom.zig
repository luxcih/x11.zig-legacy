const std = @import("std");
const x11 = @import("x11");
const common = @import("common.zig");

fn intern(session: *common.Session, io: std.Io, name: []const u8) !u32 {
    const request = x11.Atom.Intern{ .name = name };
    var request_buffer: [128]u8 = undefined;
    try session.connection.writeAll(io, try request.encode(&request_buffer, session.byte_order));

    var read_buffer: [64]u8 = undefined;
    var reader = session.connection.reader(io, &read_buffer);
    const header = try session.connection.readResponseHeader(&reader);
    const reply = try x11.Atom.Intern.Reply.parse(&header, session.byte_order);
    return reply.atom;
}

pub fn main(init: std.process.Init) !void {
    var session = try common.connectAndSetup(init);
    defer session.close(init.io);

    const atom = try intern(&session, init.io, "WM_NAME");
    std.debug.print("WM_NAME = 0x{x}\n", .{atom});
}
