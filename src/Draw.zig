const std = @import("std");
const Setup = @import("Setup.zig").Setup;
const Wire = @import("Wire.zig");

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
        Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        Wire.writeU32(buffer[4..8], self.drawable, byte_order);
        Wire.writeU32(buffer[8..12], self.gc, byte_order);

        var offset: usize = base_size;
        for (self.rectangles) |rectangle| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(rectangle.x), byte_order);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(rectangle.y), byte_order);
            Wire.writeU16(buffer[offset + 4 .. offset + 6], rectangle.width, byte_order);
            Wire.writeU16(buffer[offset + 6 .. offset + 8], rectangle.height, byte_order);
            offset += rectangle_size;
        }

        return buffer[0..offset];
    }
};

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
        Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        Wire.writeU32(buffer[4..8], self.drawable, byte_order);
        Wire.writeU32(buffer[8..12], self.gc, byte_order);

        var offset: usize = base_size;
        for (self.points) |point| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(point.x), byte_order);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(point.y), byte_order);
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


pub const OutlineRectangle = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 67;
    pub const base_size: usize = 12;
    pub const rectangle_size: usize = 8;

    drawable: u32,
    gc: u32,
    rectangles: []const Rectangle,

    pub fn encodedLength(self: OutlineRectangle) usize {
        return base_size + self.rectangles.len * rectangle_size;
    }

    pub fn encode(
        self: OutlineRectangle,
        buffer: []u8,
        byte_order: Setup.ByteOrder,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        Wire.writeU32(buffer[4..8], self.drawable, byte_order);
        Wire.writeU32(buffer[8..12], self.gc, byte_order);

        var offset: usize = base_size;
        for (self.rectangles) |rectangle| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(rectangle.x), byte_order);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(rectangle.y), byte_order);
            Wire.writeU16(buffer[offset + 4 .. offset + 6], rectangle.width, byte_order);
            Wire.writeU16(buffer[offset + 6 .. offset + 8], rectangle.height, byte_order);
            offset += rectangle_size;
        }

        return buffer[0..offset];
    }
};

test "encode little-endian PolyRectangle request" {
    const request = OutlineRectangle{
        .drawable = 0x01020304,
        .gc = 0x05060708,
        .rectangles = &.{
            .{ .x = 10, .y = -20, .width = 640, .height = 480 },
        },
    };

    var buffer: [20]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        67, 0,
        5, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
        10, 0,
        236, 255,
        128, 2,
        224, 1,
    }, encoded);
}


pub const Arc = struct {
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    angle1: i16,
    angle2: i16,
};

pub const OutlineArc = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 68;
    pub const base_size: usize = 12;
    pub const arc_size: usize = 12;

    drawable: u32,
    gc: u32,
    arcs: []const Arc,

    pub fn encodedLength(self: OutlineArc) usize {
        return base_size + self.arcs.len * arc_size;
    }

    pub fn encode(
        self: OutlineArc,
        buffer: []u8,
        byte_order: Setup.ByteOrder,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        Wire.writeU32(buffer[4..8], self.drawable, byte_order);
        Wire.writeU32(buffer[8..12], self.gc, byte_order);

        var offset: usize = base_size;
        for (self.arcs) |arc| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(arc.x), byte_order);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(arc.y), byte_order);
            Wire.writeU16(buffer[offset + 4 .. offset + 6], arc.width, byte_order);
            Wire.writeU16(buffer[offset + 6 .. offset + 8], arc.height, byte_order);
            Wire.writeU16(buffer[offset + 8 .. offset + 10], @bitCast(arc.angle1), byte_order);
            Wire.writeU16(buffer[offset + 10 .. offset + 12], @bitCast(arc.angle2), byte_order);
            offset += arc_size;
        }

        return buffer[0..offset];
    }
};

test "encode little-endian PolyArc request" {
    const request = OutlineArc{
        .drawable = 0x01020304,
        .gc = 0x05060708,
        .arcs = &.{
            .{
                .x = 10,
                .y = -20,
                .width = 100,
                .height = 200,
                .angle1 = 0,
                .angle2 = 360 * 64,
            },
        },
    };

    var buffer: [24]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        68, 0,
        6, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
        10, 0,
        236, 255,
        100, 0,
        200, 0,
        0, 0,
        0, 90,
    }, encoded);
}


pub const FillArc = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 71;
    pub const base_size: usize = 12;
    pub const arc_size: usize = 12;

    drawable: u32,
    gc: u32,
    arcs: []const Arc,

    pub fn encodedLength(self: FillArc) usize {
        return base_size + self.arcs.len * arc_size;
    }

    pub fn encode(
        self: FillArc,
        buffer: []u8,
        byte_order: Setup.ByteOrder,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        Wire.writeU32(buffer[4..8], self.drawable, byte_order);
        Wire.writeU32(buffer[8..12], self.gc, byte_order);

        var offset: usize = base_size;
        for (self.arcs) |arc| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(arc.x), byte_order);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(arc.y), byte_order);
            Wire.writeU16(buffer[offset + 4 .. offset + 6], arc.width, byte_order);
            Wire.writeU16(buffer[offset + 6 .. offset + 8], arc.height, byte_order);
            Wire.writeU16(buffer[offset + 8 .. offset + 10], @bitCast(arc.angle1), byte_order);
            Wire.writeU16(buffer[offset + 10 .. offset + 12], @bitCast(arc.angle2), byte_order);
            offset += arc_size;
        }

        return buffer[0..offset];
    }
};

test "encode little-endian PolyFillArc request" {
    const request = FillArc{
        .drawable = 0x01020304,
        .gc = 0x05060708,
        .arcs = &.{
            .{
                .x = 10,
                .y = -20,
                .width = 100,
                .height = 200,
                .angle1 = 0,
                .angle2 = 360 * 64,
            },
        },
    };

    var buffer: [24]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        71, 0,
        6, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
        10, 0,
        236, 255,
        100, 0,
        200, 0,
        0, 0,
        0, 90,
    }, encoded);
}


pub const ImageText8 = struct {
    pub const EncodeError = error{
        BufferTooSmall,
        TextTooLong,
    };

    pub const opcode = 76;
    pub const base_size: usize = 16;
    pub const max_text_length: usize = 255;

    drawable: u32,
    gc: u32,
    x: i16,
    y: i16,
    text: []const u8,

    pub fn encodedLength(self: ImageText8) EncodeError!usize {
        if (self.text.len > max_text_length)
            return error.TextTooLong;

        const unpadded = base_size + self.text.len;
        return std.mem.alignForward(usize, unpadded, 4);
    }

    pub fn encode(
        self: ImageText8,
        buffer: []u8,
        byte_order: Setup.ByteOrder,
    ) EncodeError![]const u8 {
        const length = try self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = @intCast(self.text.len);
        Wire.writeU16(buffer[2..4], @intCast(length / 4), byte_order);
        Wire.writeU32(buffer[4..8], self.drawable, byte_order);
        Wire.writeU32(buffer[8..12], self.gc, byte_order);
        Wire.writeU16(buffer[12..14], @bitCast(self.x), byte_order);
        Wire.writeU16(buffer[14..16], @bitCast(self.y), byte_order);

        @memcpy(buffer[16 .. 16 + self.text.len], self.text);
        @memset(buffer[16 + self.text.len .. length], 0);

        return buffer[0..length];
    }
};

test "encode little-endian ImageText8 request" {
    const request = ImageText8{
        .drawable = 0x01020304,
        .gc = 0x05060708,
        .x = 10,
        .y = 20,
        .text = "Hi",
    };

    var buffer: [20]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);

    try std.testing.expectEqualSlices(u8, &.{
        76, 2,
        5, 0,
        4, 3, 2, 1,
        8, 7, 6, 5,
        10, 0,
        20, 0,
        'H', 'i', 0, 0,
    }, encoded);
}
