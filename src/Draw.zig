const std = @import("std");
const Setup = @import("Setup.zig").Setup;

pub const Rectangle = struct {
    x: i16,
    y: i16,
    width: u16,
    height: u16,
};

pub const Fill = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 70;
    pub const base_size: usize = 12;
    pub const rectangle_size: usize = 8;

    drawable: u32,
    gc: u32,
    rectangles: []const Rectangle,

    pub fn encodedLength(self: Fill) usize {
        return base_size + self.rectangles.len * rectangle_size;
    }

    pub fn encode(
        self: Fill,
        buffer: []u8,
        byte_order: Setup.ByteOrder,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        writeU32(buffer[4..8], self.drawable, byte_order);
        writeU32(buffer[8..12], self.gc, byte_order);

        var offset: usize = base_size;
        for (self.rectangles) |rectangle| {
            writeU16(buffer[offset .. offset + 2], @bitCast(rectangle.x), byte_order);
            writeU16(buffer[offset + 2 .. offset + 4], @bitCast(rectangle.y), byte_order);
            writeU16(buffer[offset + 4 .. offset + 6], rectangle.width, byte_order);
            writeU16(buffer[offset + 6 .. offset + 8], rectangle.height, byte_order);
            offset += rectangle_size;
        }

        return buffer[0..offset];
    }
};

fn writeU16(bytes: []u8, value: u16, byte_order: Setup.ByteOrder) void {
    switch (byte_order) {
        .little => std.mem.writeInt(u16, bytes[0..2], value, .little),
        .big => std.mem.writeInt(u16, bytes[0..2], value, .big),
    }
}

fn writeU32(bytes: []u8, value: u32, byte_order: Setup.ByteOrder) void {
    switch (byte_order) {
        .little => std.mem.writeInt(u32, bytes[0..4], value, .little),
        .big => std.mem.writeInt(u32, bytes[0..4], value, .big),
    }
}

test "encode little-endian PolyFillRectangle request" {
    const request = Fill{
        .drawable = 0x01020304,
        .gc = 0x05060708,
        .rectangles = &.{
            .{ .x = 10, .y = -20, .width = 640, .height = 480 },
        },
    };

    var buffer: [20]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        70, 0,
        5, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
        10, 0,
        236, 255,
        128, 2,
        224, 1,
    }, encoded);
}


pub const Point = struct {
    x: i16,
    y: i16,
};

pub const Line = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 65;
    pub const base_size: usize = 12;
    pub const point_size: usize = 4;

    pub const CoordinateMode = enum(u8) {
        origin = 0,
        previous = 1,
    };

    drawable: u32,
    gc: u32,
    points: []const Point,
    coordinate_mode: CoordinateMode = .origin,

    pub fn encodedLength(self: Line) usize {
        return base_size + self.points.len * point_size;
    }

    pub fn encode(
        self: Line,
        buffer: []u8,
        byte_order: Setup.ByteOrder,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = @intFromEnum(self.coordinate_mode);
        writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        writeU32(buffer[4..8], self.drawable, byte_order);
        writeU32(buffer[8..12], self.gc, byte_order);

        var offset: usize = base_size;
        for (self.points) |point| {
            writeU16(buffer[offset .. offset + 2], @bitCast(point.x), byte_order);
            writeU16(buffer[offset + 2 .. offset + 4], @bitCast(point.y), byte_order);
            offset += point_size;
        }

        return buffer[0..offset];
    }
};

test "encode little-endian PolyLine request" {
    const request = Line{
        .drawable = 0x01020304,
        .gc = 0x05060708,
        .points = &.{
            .{ .x = 10, .y = -20 },
            .{ .x = 30, .y = 40 },
        },
    };

    var buffer: [20]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        65, 0,
        5, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
        10, 0,
        236, 255,
        30, 0,
        40, 0,
    }, encoded);
}
