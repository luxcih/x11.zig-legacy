const std = @import("std");
const Wire = @import("Wire.zig");
const Endian = std.builtin.Endian;

const Atom = @This();

pub const Intern = struct {
    pub const EncodeError = error{
        BufferTooSmall,
        NameTooLong,
    };

    pub const ParseError = error{
        InvalidLength,
        InvalidResponse,
    };

    pub const opcode = 16;
    pub const header_size: usize = 8;
    pub const reply_size: usize = 32;

    name: []const u8,
    only_if_exists: bool = false,

    pub fn encodedLength(self: Intern) usize {
        return header_size + std.mem.alignForward(usize, self.name.len, 4);
    }

    pub fn encode(
        self: Intern,
        buffer: []u8,
        endian: Endian,
    ) EncodeError![]const u8 {
        if (self.name.len > std.math.maxInt(u16))
            return error.NameTooLong;

        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        @memset(buffer[0..length], 0);

        buffer[0] = opcode;
        buffer[1] = @intFromBool(self.only_if_exists);
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU16(buffer[4..6], @intCast(self.name.len), endian);
        buffer[6] = 0;
        buffer[7] = 0;
        @memcpy(buffer[8 .. 8 + self.name.len], self.name);

        return buffer[0..length];
    }

    pub const Reply = struct {
        atom: u32,

        pub fn parse(bytes: []const u8, endian: Endian) ParseError!Reply {
            if (bytes.len != reply_size)
                return error.InvalidLength;
            if (bytes[0] != 1)
                return error.InvalidResponse;

            return .{
                .atom = Wire.readU32(bytes[8..12], endian),
            };
        }
    };
};

pub const GetName = struct {
    pub const EncodeError = error{BufferTooSmall};
    pub const ParseError = error{InvalidLength, InvalidResponse};

    pub const opcode = 17;
    pub const request_size = 8;
    pub const reply_size = 32;

    atom: u32,

    pub fn encode(
        self: GetName,
        buffer: []u8,
        endian: Endian,
    ) EncodeError![]const u8 {
        if (buffer.len < request_size)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], 2, endian);
        Wire.writeU32(buffer[4..8], self.atom, endian);

        return buffer[0..request_size];
    }

    pub const Reply = struct {
        name: []const u8,

        pub fn parse(
            header: []const u8,
            body: []const u8,
            endian: Endian,
        ) ParseError!Reply {
            if (header.len != reply_size)
                return error.InvalidLength;
            if (header[0] != 1)
                return error.InvalidResponse;

            const name_length: usize =
                @as(usize, Wire.readU16(header[8..10], endian));
            if (body.len < name_length)
                return error.InvalidLength;

            return .{
                .name = body[0..name_length],
            };
        }
    };
};

test "encode little-endian InternAtom" {
    const request = Atom.Intern{
        .name = "WM_PROTOCOLS",
    };

    var buffer: [20]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        16, 0,
        5, 0,
        12, 0,
        0, 0,
        'W', 'M', '_', 'P',
        'R', 'O', 'T', 'O',
        'C', 'O', 'L', 'S',
    }, encoded);
}

test "encode InternAtom with padding" {
    const request = Atom.Intern{
        .name = "ABC",
        .only_if_exists = true,
    };

    var buffer: [12]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        16, 1,
        3, 0,
        3, 0,
        0, 0,
        'A', 'B', 'C', 0,
    }, encoded);
}

test "parse little-endian InternAtom reply" {
    var bytes: [Atom.Intern.reply_size]u8 = [_]u8{0} ** Atom.Intern.reply_size;
    bytes[0] = 1;
    Wire.writeU32(bytes[8..12], 0x01020304, .little);

    const reply = try Atom.Intern.Reply.parse(&bytes, .little);
    try std.testing.expectEqual(@as(u32, 0x01020304), reply.atom);
}


test "encode little-endian GetAtomName" {
    const request = Atom.GetName{ .atom = 0x01020304 };

    var buffer: [Atom.GetName.request_size]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        17, 0,
        2, 0,
        4, 3, 2, 1,
    }, encoded);
}

test "encode big-endian GetAtomName" {
    const request = Atom.GetName{ .atom = 0x01020304 };

    var buffer: [Atom.GetName.request_size]u8 = undefined;
    const encoded = try request.encode(&buffer, .big);

    try std.testing.expectEqualSlices(u8, &.{
        17, 0,
        0, 2,
        1, 2, 3, 4,
    }, encoded);
}

test "parse GetAtomName reply" {
    var header: [Atom.GetName.reply_size]u8 =
        [_]u8{0} ** Atom.GetName.reply_size;
    header[0] = 1;
    Wire.writeU16(header[8..10], 12, .little);

    const reply = try Atom.GetName.Reply.parse(
        &header,
        "WM_PROTOCOLS",
        .little,
    );
    try std.testing.expectEqualStrings("WM_PROTOCOLS", reply.name);
}

test "GetAtomName rejects a short name body" {
    var header: [Atom.GetName.reply_size]u8 =
        [_]u8{0} ** Atom.GetName.reply_size;
    header[0] = 1;
    Wire.writeU16(header[8..10], 12, .little);

    try std.testing.expectError(
        error.InvalidLength,
        Atom.GetName.Reply.parse(&header, "SHORT", .little),
    );
}
