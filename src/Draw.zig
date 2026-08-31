//! Core X11 drawing primitives.
//!
//! Drawing requests operate on a drawable resource and reference a graphics
//! context (GC). The drawable determines where pixels are affected; the GC
//! determines how they are rendered.
//!
//! This module encodes geometric lists such as points, rectangles, and arcs
//! into the corresponding X11 core drawing requests.
//!
const std = @import("std");
const Wire = @import("Wire.zig");
const Endian = std.builtin.Endian;

/// A rectangle geometry record used by rectangle drawing requests.\npub const Rectangle = struct {
    x: i16,
    y: i16,
    width: u16,
    height: u16,
};

/// Fills one or more rectangles using the supplied graphics context.\npub const PolyFillRectangle = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 70;
    pub const base_size: usize = 12;
    pub const rectangle_size: usize = 8;

    drawable: u32,
    gc: u32,
    rectangles: []const Rectangle,

    pub fn encodedLength(self: PolyFillRectangle) usize {
        return base_size + self.rectangles.len * rectangle_size;
    }

    pub fn encode(
        self: PolyFillRectangle,
        buffer: []u8,
        endian: Endian,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU32(buffer[4..8], self.drawable, endian);
        Wire.writeU32(buffer[8..12], self.gc, endian);

        var offset: usize = base_size;
        for (self.rectangles) |rectangle| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(rectangle.x), endian);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(rectangle.y), endian);
            Wire.writeU16(buffer[offset + 4 .. offset + 6], rectangle.width, endian);
            Wire.writeU16(buffer[offset + 6 .. offset + 8], rectangle.height, endian);
            offset += rectangle_size;
        }

        return buffer[0..offset];
    }
};

test "encode big-endian drawing requests" {
    {
        const request = PolyLine{
            .drawable = 0x01020304,
            .gc = 0x05060708,
            .points = &.{ .{ .x = 10, .y = -20 } },
            .coordinate_mode = .previous,
        };
        var buffer: [16]u8 = undefined;
        const encoded = try request.encode(&buffer, .big);
        try std.testing.expectEqualSlices(u8, &.{
            65, 1, 0, 4,
            1, 2, 3, 4,
            5, 6, 7, 8,
            0, 10, 255, 236,
        }, encoded);
    }

    {
        const request = PolyRectangle{
            .drawable = 0x01020304,
            .gc = 0x05060708,
            .rectangles = &.{ .{ .x = 10, .y = -20, .width = 640, .height = 480 } },
        };
        var buffer: [20]u8 = undefined;
        const encoded = try request.encode(&buffer, .big);
        try std.testing.expectEqualSlices(u8, &.{
            67, 0, 0, 5,
            1, 2, 3, 4,
            5, 6, 7, 8,
            0, 10, 255, 236, 2, 128, 1, 224,
        }, encoded);
    }

    {
        const request = PolyArc{
            .drawable = 0x01020304,
            .gc = 0x05060708,
            .arcs = &.{ .{
                .x = 10, .y = -20, .width = 100, .height = 200,
                .angle1 = -64, .angle2 = 360 * 64,
            } },
        };
        var buffer: [24]u8 = undefined;
        const encoded = try request.encode(&buffer, .big);
        try std.testing.expectEqualSlices(u8, &.{
            68, 0, 0, 6,
            1, 2, 3, 4,
            5, 6, 7, 8,
            0, 10, 255, 236, 0, 100, 0, 200, 255, 192, 90, 0,
        }, encoded);
    }

    {
        const request = PolyFillRectangle{
            .drawable = 0x01020304,
            .gc = 0x05060708,
            .rectangles = &.{ .{ .x = 10, .y = -20, .width = 640, .height = 480 } },
        };
        var buffer: [20]u8 = undefined;
        const encoded = try request.encode(&buffer, .big);
        try std.testing.expectEqualSlices(u8, &.{
            70, 0, 0, 5,
            1, 2, 3, 4,
            5, 6, 7, 8,
            0, 10, 255, 236, 2, 128, 1, 224,
        }, encoded);
    }

    {
        const request = PolyFillArc{
            .drawable = 0x01020304,
            .gc = 0x05060708,
            .arcs = &.{ .{
                .x = 10, .y = -20, .width = 100, .height = 200,
                .angle1 = 0, .angle2 = 360 * 64,
            } },
        };
        var buffer: [24]u8 = undefined;
        const encoded = try request.encode(&buffer, .big);
        try std.testing.expectEqualSlices(u8, &.{
            71, 0, 0, 6,
            1, 2, 3, 4,
            5, 6, 7, 8,
            0, 10, 255, 236, 0, 100, 0, 200, 0, 0, 90, 0,
        }, encoded);
    }

    {
        const request = ImageText8{
            .drawable = 0x01020304,
            .gc = 0x05060708,
            .x = -10,
            .y = 20,
            .text = "Hi",
        };
        var buffer: [20]u8 = undefined;
        const encoded = try request.encode(&buffer, .big);
        try std.testing.expectEqualSlices(u8, &.{
            76, 2, 0, 5,
            1, 2, 3, 4,
            5, 6, 7, 8,
            255, 246, 0, 20,
            'H', 'i', 0, 0,
        }, encoded);
    }
}

test "encode little-endian PolyFillRectangle request" {
    const request = PolyFillRectangle{
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

/// Draws connected line segments from a list of points.\npub const PolyLine = struct {
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

    pub fn encodedLength(self: PolyLine) usize {
        return base_size + self.points.len * point_size;
    }

    pub fn encode(
        self: PolyLine,
        buffer: []u8,
        endian: Endian,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = @intFromEnum(self.coordinate_mode);
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU32(buffer[4..8], self.drawable, endian);
        Wire.writeU32(buffer[8..12], self.gc, endian);

        var offset: usize = base_size;
        for (self.points) |point| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(point.x), endian);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(point.y), endian);
            offset += point_size;
        }

        return buffer[0..offset];
    }
};

test "encode little-endian PolyLine request" {
    const request = PolyLine{
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


/// Draws the outlines of one or more rectangles.\npub const PolyRectangle = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 67;
    pub const base_size: usize = 12;
    pub const rectangle_size: usize = 8;

    drawable: u32,
    gc: u32,
    rectangles: []const Rectangle,

    pub fn encodedLength(self: PolyRectangle) usize {
        return base_size + self.rectangles.len * rectangle_size;
    }

    pub fn encode(
        self: PolyRectangle,
        buffer: []u8,
        endian: Endian,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU32(buffer[4..8], self.drawable, endian);
        Wire.writeU32(buffer[8..12], self.gc, endian);

        var offset: usize = base_size;
        for (self.rectangles) |rectangle| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(rectangle.x), endian);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(rectangle.y), endian);
            Wire.writeU16(buffer[offset + 4 .. offset + 6], rectangle.width, endian);
            Wire.writeU16(buffer[offset + 6 .. offset + 8], rectangle.height, endian);
            offset += rectangle_size;
        }

        return buffer[0..offset];
    }
};

test "encode little-endian PolyRectangle request" {
    const request = PolyRectangle{
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

/// Draws one or more arc outlines.\npub const PolyArc = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 68;
    pub const base_size: usize = 12;
    pub const arc_size: usize = 12;

    drawable: u32,
    gc: u32,
    arcs: []const Arc,

    pub fn encodedLength(self: PolyArc) usize {
        return base_size + self.arcs.len * arc_size;
    }

    pub fn encode(
        self: PolyArc,
        buffer: []u8,
        endian: Endian,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU32(buffer[4..8], self.drawable, endian);
        Wire.writeU32(buffer[8..12], self.gc, endian);

        var offset: usize = base_size;
        for (self.arcs) |arc| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(arc.x), endian);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(arc.y), endian);
            Wire.writeU16(buffer[offset + 4 .. offset + 6], arc.width, endian);
            Wire.writeU16(buffer[offset + 6 .. offset + 8], arc.height, endian);
            Wire.writeU16(buffer[offset + 8 .. offset + 10], @bitCast(arc.angle1), endian);
            Wire.writeU16(buffer[offset + 10 .. offset + 12], @bitCast(arc.angle2), endian);
            offset += arc_size;
        }

        return buffer[0..offset];
    }
};

test "encode little-endian PolyArc request" {
    const request = PolyArc{
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


/// Fills one or more arc shapes.\npub const PolyFillArc = struct {
    pub const EncodeError = error{
        BufferTooSmall,
    };

    pub const opcode = 71;
    pub const base_size: usize = 12;
    pub const arc_size: usize = 12;

    drawable: u32,
    gc: u32,
    arcs: []const Arc,

    pub fn encodedLength(self: PolyFillArc) usize {
        return base_size + self.arcs.len * arc_size;
    }

    pub fn encode(
        self: PolyFillArc,
        buffer: []u8,
        endian: Endian,
    ) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU32(buffer[4..8], self.drawable, endian);
        Wire.writeU32(buffer[8..12], self.gc, endian);

        var offset: usize = base_size;
        for (self.arcs) |arc| {
            Wire.writeU16(buffer[offset .. offset + 2], @bitCast(arc.x), endian);
            Wire.writeU16(buffer[offset + 2 .. offset + 4], @bitCast(arc.y), endian);
            Wire.writeU16(buffer[offset + 4 .. offset + 6], arc.width, endian);
            Wire.writeU16(buffer[offset + 6 .. offset + 8], arc.height, endian);
            Wire.writeU16(buffer[offset + 8 .. offset + 10], @bitCast(arc.angle1), endian);
            Wire.writeU16(buffer[offset + 10 .. offset + 12], @bitCast(arc.angle2), endian);
            offset += arc_size;
        }

        return buffer[0..offset];
    }
};

test "encode little-endian PolyFillArc request" {
    const request = PolyFillArc{
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
        endian: Endian,
    ) EncodeError![]const u8 {
        const length = try self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = @intCast(self.text.len);
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU32(buffer[4..8], self.drawable, endian);
        Wire.writeU32(buffer[8..12], self.gc, endian);
        Wire.writeU16(buffer[12..14], @bitCast(self.x), endian);
        Wire.writeU16(buffer[14..16], @bitCast(self.y), endian);

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
