//! Representation of the remote X server established during connection setup.

const std = @import("std");
const Endian = std.builtin.Endian;
const Wire = @import("Wire.zig");
const PixmapFormat = @import("PixmapFormat.zig");
const Screen = @import("Screen.zig");
const Depth = @import("Depth.zig");
const VisualType = @import("VisualType.zig");

const Server = @This();

pub const ParsedDepth = struct {
    depth: Depth,
    visuals: []VisualType,

    pub fn deinit(self: ParsedDepth, allocator: std.mem.Allocator) void {
        allocator.free(self.visuals);
    }
};

pub const ParsedScreen = struct {
    screen: Screen,
    depths: []ParsedDepth,

    pub fn deinit(self: ParsedScreen, allocator: std.mem.Allocator) void {
        for (self.depths) |depth| depth.deinit(allocator);
        allocator.free(self.depths);
    }
};

release_number: u32,
motion_buffer_size: u32,
vendor: []const u8,
maximum_request_length: u16,
image_byte_order: u8,
bitmap_bit_order: u8,
bitmap_scanline_unit: u8,
bitmap_scanline_pad: u8,
min_keycode: u8,
max_keycode: u8,
pixmap_formats: []PixmapFormat,
screens: []ParsedScreen,

pub fn parse(
    allocator: std.mem.Allocator,
    body: []const u8,
    endian: Endian,
) !Server {
    if (body.len < 32) return error.BodyTooShort;

    const vendor_length = Wire.readU16(body[16..18], endian);
    const maximum_request_length = Wire.readU16(body[18..20], endian);
    const screen_count = body[20];
    const pixmap_format_count = body[21];

    const vendor_end = 32 + @as(usize, vendor_length);
    if (vendor_end > body.len) return error.BodyTooShort;

    const pixmap_formats_offset = paddedLength(vendor_end);
    const pixmap_formats_length = @as(usize, pixmap_format_count) * PixmapFormat.size;
    const screens_offset = pixmap_formats_offset + pixmap_formats_length;
    if (screens_offset > body.len) return error.BodyTooShort;

    const pixmap_formats = try parsePixmapFormats(
        allocator,
        body,
        pixmap_formats_offset,
        pixmap_format_count,
    );
    errdefer allocator.free(pixmap_formats);

    const screens = try allocator.alloc(ParsedScreen, screen_count);
    var parsed_screens: usize = 0;
    errdefer {
        for (screens[0..parsed_screens]) |screen| screen.deinit(allocator);
        allocator.free(screens);
    }

    var screen_offset = screens_offset;
    while (parsed_screens < screens.len) : (parsed_screens += 1) {
        const parsed = try parseScreen(allocator, body, screen_offset, endian);
        screens[parsed_screens] = parsed.screen;
        screen_offset = parsed.next_offset;
    }

    return .{
        .release_number = Wire.readU32(body[0..4], endian),
        .motion_buffer_size = Wire.readU32(body[12..16], endian),
        .vendor = body[32..vendor_end],
        .maximum_request_length = maximum_request_length,
        .image_byte_order = body[22],
        .bitmap_bit_order = body[23],
        .bitmap_scanline_unit = body[24],
        .bitmap_scanline_pad = body[25],
        .min_keycode = body[26],
        .max_keycode = body[27],
        .pixmap_formats = pixmap_formats,
        .screens = screens,
    };
}

pub fn deinit(self: *Server, allocator: std.mem.Allocator) void {
    for (self.screens) |screen| screen.deinit(allocator);
    allocator.free(self.screens);
    allocator.free(self.pixmap_formats);
}

fn parsePixmapFormats(
    allocator: std.mem.Allocator,
    body: []const u8,
    offset: usize,
    count: u8,
) ![]PixmapFormat {
    const length = @as(usize, count) * PixmapFormat.size;
    if (offset + length > body.len) return error.BodyTooShort;

    const formats = try allocator.alloc(PixmapFormat, count);
    errdefer allocator.free(formats);

    for (formats, 0..) |*format, index| {
        const format_offset = offset + index * PixmapFormat.size;
        format.* = try PixmapFormat.parse(
            body[format_offset .. format_offset + PixmapFormat.size],
        );
    }

    return formats;
}

fn parseScreen(
    allocator: std.mem.Allocator,
    body: []const u8,
    offset: usize,
    endian: Endian,
) !struct { screen: ParsedScreen, next_offset: usize } {
    if (offset + Screen.size > body.len) return error.BodyTooShort;

    const screen = try Screen.parse(body[offset .. offset + Screen.size], endian);

    const depths = try allocator.alloc(ParsedDepth, screen.depth_count);
    var parsed_depths: usize = 0;
    errdefer {
        for (depths[0..parsed_depths]) |depth| depth.deinit(allocator);
        allocator.free(depths);
    }

    var depth_offset = offset + Screen.size;
    while (parsed_depths < depths.len) : (parsed_depths += 1) {
        if (depth_offset + Depth.size > body.len) return error.BodyTooShort;

        const depth = try Depth.parse(
            body[depth_offset .. depth_offset + Depth.size],
            endian,
        );

        const total_length = depth.totalLength();
        if (depth_offset + total_length > body.len) return error.BodyTooShort;

        const visuals = try parseVisuals(
            allocator,
            body,
            depth,
            depth_offset + depth.visualsOffset(),
            endian,
        );

        depths[parsed_depths] = .{ .depth = depth, .visuals = visuals };
        depth_offset += total_length;
    }

    return .{
        .screen = .{ .screen = screen, .depths = depths },
        .next_offset = depth_offset,
    };
}

fn parseVisuals(
    allocator: std.mem.Allocator,
    body: []const u8,
    depth: Depth,
    offset: usize,
    endian: Endian,
) ![]VisualType {
    const visuals = try allocator.alloc(VisualType, depth.visual_count);
    errdefer allocator.free(visuals);

    for (visuals, 0..) |*visual, index| {
        const visual_offset = offset + index * VisualType.size;
        visual.* = try VisualType.parse(
            body[visual_offset .. visual_offset + VisualType.size],
            endian,
        );
    }

    return visuals;
}

fn paddedLength(length: usize) usize {
    return (length + 3) & ~@as(usize, 3);
}
