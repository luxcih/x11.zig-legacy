//! X11 graphics contexts and their server-side drawing state.
//!
//! A graphics context (GC) stores how drawing operations behave: colors, raster
//! operations, line styles, fill behavior, fonts, clipping, and related state.
//! Drawing requests reference a GC instead of repeating that state every time.
//!
//! Values represents the protocol LISTofVALUE mechanism shared by CreateGC and
//! ChangeGC, centralizing mask construction and required wire ordering.
//!
const std = @import("std");
const Wire = @import("Wire.zig");
const Endian = std.builtin.Endian;

const GC = @This();

/// X11 GX raster operations.
pub const Function = enum(u32) {
    clear = 0,
    and_ = 1,
    and_reverse = 2,
    copy = 3,
    and_inverted = 4,
    noop = 5,
    xor = 6,
    or_ = 7,
    nor = 8,
    equiv = 9,
    invert = 10,
    or_reverse = 11,
    copy_inverted = 12,
    or_inverted = 13,
    nand = 14,
    set = 15,
};

/// Selects how lines are rendered between endpoints.
pub const LineStyle = enum(u32) { solid = 0, on_off_dash = 1, double_dash = 2 };
/// Selects how the ends of lines are rendered.
pub const CapStyle = enum(u32) { not_last = 0, butt = 1, round = 2, projecting = 3 };
/// Selects how connected line segments join.
pub const JoinStyle = enum(u32) { miter = 0, round = 1, bevel = 2 };
/// Selects how closed areas are filled.
pub const FillStyle = enum(u32) { solid = 0, tiled = 1, stippled = 2, opaque_stippled = 3 };
pub const FillRule = enum(u32) { even_odd = 0, winding = 1 };
pub const SubwindowMode = enum(u32) { clip_by_children = 0, include_inferiors = 1 };
pub const ArcMode = enum(u32) { chord = 0, pie_slice = 1 };

/// X11 graphics-context values.
///
/// Each non-null field contributes one CARD32 slot to the protocol value list.
/// Values are always encoded in increasing mask-bit order.
pub const Values = struct {
    function: ?Function = null,
    plane_mask: ?u32 = null,
    foreground: ?u32 = null,
    background: ?u32 = null,
    line_width: ?u32 = null,
    line_style: ?LineStyle = null,
    cap_style: ?CapStyle = null,
    join_style: ?JoinStyle = null,
    fill_style: ?FillStyle = null,
    fill_rule: ?FillRule = null,
    tile: ?u32 = null,
    stipple: ?u32 = null,
    tile_stipple_x_origin: ?i16 = null,
    tile_stipple_y_origin: ?i16 = null,
    font: ?u32 = null,
    subwindow_mode: ?SubwindowMode = null,
    graphics_exposures: ?bool = null,
    clip_x_origin: ?i16 = null,
    clip_y_origin: ?i16 = null,
    clip_mask: ?u32 = null,
    dash_offset: ?u16 = null,
    dashes: ?u8 = null,
    arc_mode: ?ArcMode = null,

    /// Returns the X11 value mask whose set bits correspond to non-null fields.
    pub fn valueMask(self: Values) u32 {
        var mask: u32 = 0;
        inline for (std.meta.fields(Values), 0..) |field, bit| {
            if (@field(self, field.name) != null)
                mask |= @as(u32, 1) << @intCast(bit);
        }
        return mask;
    }

    /// Returns the number of bytes occupied by the selected CARD32 value slots.
    pub fn encodedLength(self: Values) usize {
        return @popCount(self.valueMask()) * 4;
    }

    pub fn encode(self: Values, buffer: []u8, endian: Endian) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length)
            return error.BufferTooSmall;

        var offset: usize = 0;

        if (self.function) |value| {
            Wire.writeU32(buffer[offset..][0..4], @intFromEnum(value), endian);
            offset += 4;
        }
        if (self.plane_mask) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.foreground) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.background) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.line_width) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.line_style) |value| {
            Wire.writeU32(buffer[offset..][0..4], @intFromEnum(value), endian);
            offset += 4;
        }
        if (self.cap_style) |value| {
            Wire.writeU32(buffer[offset..][0..4], @intFromEnum(value), endian);
            offset += 4;
        }
        if (self.join_style) |value| {
            Wire.writeU32(buffer[offset..][0..4], @intFromEnum(value), endian);
            offset += 4;
        }
        if (self.fill_style) |value| {
            Wire.writeU32(buffer[offset..][0..4], @intFromEnum(value), endian);
            offset += 4;
        }
        if (self.fill_rule) |value| {
            Wire.writeU32(buffer[offset..][0..4], @intFromEnum(value), endian);
            offset += 4;
        }
        if (self.tile) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.stipple) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.tile_stipple_x_origin) |value| {
            Wire.writeU32(buffer[offset..][0..4], @as(u32, @bitCast(@as(i32, value))), endian);
            offset += 4;
        }
        if (self.tile_stipple_y_origin) |value| {
            Wire.writeU32(buffer[offset..][0..4], @as(u32, @bitCast(@as(i32, value))), endian);
            offset += 4;
        }
        if (self.font) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.subwindow_mode) |value| {
            Wire.writeU32(buffer[offset..][0..4], @intFromEnum(value), endian);
            offset += 4;
        }
        if (self.graphics_exposures) |value| {
            Wire.writeU32(buffer[offset..][0..4], if (value) 1 else 0, endian);
            offset += 4;
        }
        if (self.clip_x_origin) |value| {
            Wire.writeU32(buffer[offset..][0..4], @as(u32, @bitCast(@as(i32, value))), endian);
            offset += 4;
        }
        if (self.clip_y_origin) |value| {
            Wire.writeU32(buffer[offset..][0..4], @as(u32, @bitCast(@as(i32, value))), endian);
            offset += 4;
        }
        if (self.clip_mask) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.dash_offset) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.dashes) |value| {
            Wire.writeU32(buffer[offset..][0..4], value, endian);
            offset += 4;
        }
        if (self.arc_mode) |value| {
            Wire.writeU32(buffer[offset..][0..4], @intFromEnum(value), endian);
            offset += 4;
        }

        return buffer[0..offset];
    }
};

pub const EncodeError = error{};

/// Creates a graphics-context resource for use with a drawable.
pub const Create = struct {
    pub const opcode = 55;
    pub const size: usize = 16;

    drawable: u32,
    gc_id: u32,
    values: Values = .{},

    pub fn encodedLength(self: Create) usize {
        return size + self.values.encodedLength();
    }

    pub fn encode(self: Create, buffer: []u8, endian: Endian) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length) return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU32(buffer[4..8], self.gc_id, endian);
        Wire.writeU32(buffer[8..12], self.drawable, endian);
        Wire.writeU32(buffer[12..16], self.values.valueMask(), endian);
        _ = try self.values.encode(buffer[size..length], endian);
        return buffer[0..length];
    }
};

/// Changes selected values of an existing graphics context.
pub const Change = struct {
    pub const opcode = 56;
    pub const base_size: usize = 12;

    gc_id: u32,
    values: Values = .{},

    pub fn encodedLength(self: Change) usize {
        return base_size + self.values.encodedLength();
    }

    pub fn encode(self: Change, buffer: []u8, endian: Endian) EncodeError![]const u8 {
        const length = self.encodedLength();
        if (buffer.len < length) return error.BufferTooSmall;

        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(length / 4), endian);
        Wire.writeU32(buffer[4..8], self.gc_id, endian);
        Wire.writeU32(buffer[8..12], self.values.valueMask(), endian);
        _ = try self.values.encode(buffer[base_size..length], endian);
        return buffer[0..length];
    }
};

/// Releases a graphics-context resource on the X server.
pub const Free = struct {
    pub const opcode = 60;
    pub const size: usize = 8;

    gc_id: u32,

    pub fn encode(self: Free, buffer: []u8, endian: Endian) EncodeError![]const u8 {
        if (buffer.len < size) return error.BufferTooSmall;
        buffer[0] = opcode;
        buffer[1] = 0;
        Wire.writeU16(buffer[2..4], @intCast(size / 4), endian);
        Wire.writeU32(buffer[4..8], self.gc_id, endian);
        return buffer[0..size];
    }
};

test "GC Values encodes mask bits in protocol order" {
    const values = Values{
        .function = .xor,
        .foreground = 0x11223344,
        .line_width = 3,
        .clip_y_origin = -2,
        .dashes = 5,
    };
    try std.testing.expectEqual(@as(u32, (1 << 0) | (1 << 2) | (1 << 4) | (1 << 18) | (1 << 21)), values.valueMask());
    var buffer: [20]u8 = undefined;
    const encoded = try values.encode(&buffer, .big);
    try std.testing.expectEqualSlices(u8, &.{
        0,    0,    0,    6,
        0x11, 0x22, 0x33, 0x44,
        0,    0,    0,    3,
        0xff, 0xff, 0xff, 0xfe,
        0,    0,    0,    5,
    }, encoded);
}

test "CreateGC uses shared Values" {
    const request = Create{
        .drawable = 0x01020304,
        .gc_id = 0x05060708,
        .values = .{ .foreground = 0x00ff00, .line_width = 6 },
    };
    var buffer: [24]u8 = undefined;
    const encoded = try request.encode(&buffer, .little);
    try std.testing.expectEqualSlices(u8, &.{
        55, 0,   6, 0,
        8,  7,   6, 5,
        4,  3,   2, 1,
        20, 0,   0, 0,
        0,  255, 0, 0,
        6,  0,   0, 0,
    }, encoded);
}

test "ChangeGC uses shared Values" {
    const request = Change{
        .gc_id = 0x01020304,
        .values = .{ .background = 0x11223344, .graphics_exposures = true, .dash_offset = 7 },
    };
    var buffer: [24]u8 = undefined;
    const encoded = try request.encode(&buffer, .big);
    try std.testing.expectEqualSlices(u8, &.{
        56,   0,    0,    6,
        1,    2,    3,    4,
        0,    17,   0,    8,
        0x11, 0x22, 0x33, 0x44,
        0,    0,    0,    1,
        0,    0,    0,    7,
    }, encoded);
}

test "FreeGC request" {
    const request = Free{ .gc_id = 0x01020304 };
    var buffer: [Free.size]u8 = undefined;
    const encoded = try request.encode(&buffer, .big);
    try std.testing.expectEqualSlices(u8, &.{ 60, 0, 0, 2, 1, 2, 3, 4 }, encoded);
}
