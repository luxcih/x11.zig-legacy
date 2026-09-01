//! Representation of the remote X server established during connection setup.

const std = @import("std");
const Client = @import("Client.zig");
const Endian = std.builtin.Endian;
const Wire = @import("Wire.zig");
const PixmapFormat = @import("PixmapFormat.zig");
const ScreenRecord = @import("Screen.zig");
const DepthRecord = @import("Depth.zig");
const VisualType = @import("VisualType.zig");

const Server = @This();

const Header = struct {
    release_number: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    vendor_length: u16,
    maximum_request_length: u16,
    screen_count: u8,
    pixmap_format_count: u8,
    image_byte_order: u8,
    bitmap_bit_order: u8,
    bitmap_scanline_unit: u8,
    bitmap_scanline_pad: u8,
    min_keycode: u8,
    max_keycode: u8,

    pub const size = 32;

    pub fn parse(bytes: []const u8, endian: Endian) !Header {
        return .{
            .release_number = Wire.readU32(bytes[0..4], endian),
            .resource_id_base = Wire.readU32(bytes[4..8], endian),
            .resource_id_mask = Wire.readU32(bytes[8..12], endian),
            .motion_buffer_size = Wire.readU32(bytes[12..16], endian),
            .vendor_length = Wire.readU16(bytes[16..18], endian),
            .maximum_request_length = Wire.readU16(bytes[18..20], endian),
            .screen_count = bytes[20],
            .pixmap_format_count = bytes[21],
            .image_byte_order = bytes[22],
            .bitmap_bit_order = bytes[23],
            .bitmap_scanline_unit = bytes[24],
            .bitmap_scanline_pad = bytes[25],
            .min_keycode = bytes[26],
            .max_keycode = bytes[27],
        };
    }
};

pub const Depth = struct {
    depth: DepthRecord,
    visuals: []VisualType,

    pub fn deinit(self: Depth, allocator: std.mem.Allocator) void {
        allocator.free(self.visuals);
    }
};

pub const Screen = struct {
    screen: ScreenRecord,
    depths: []Depth,

    pub fn deinit(self: Screen, allocator: std.mem.Allocator) void {
        for (self.depths) |depth| depth.deinit(allocator);
        allocator.free(self.depths);
    }
};

resource_id_base: u32,
resource_id_mask: u32,

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
screens: []Screen,

pub fn receive(client: *Client) !Server {
    const header = try client.recv(Header);
    const allocator = client.allocator;

    const vendor = try allocator.alloc(u8, header.vendor_length);
    errdefer allocator.free(vendor);
    try client.read(vendor);

    const vendor_padding = paddedLength(@as(usize, header.vendor_length)) - vendor.len;
    if (vendor_padding != 0) {
        var padding: [3]u8 = undefined;
        try client.read(padding[0..vendor_padding]);
    }

    const pixmap_formats = try receivePixmapFormats(
        client,
        allocator,
        header.pixmap_format_count,
    );
    errdefer allocator.free(pixmap_formats);

    const screens = try allocator.alloc(Screen, header.screen_count);
    var received_screens: usize = 0;
    errdefer {
        for (screens[0..received_screens]) |screen| screen.deinit(allocator);
        allocator.free(screens);
    }

    while (received_screens < screens.len) : (received_screens += 1) {
        screens[received_screens] = try receiveScreen(client, allocator);
    }

    return .{
        .resource_id_base = header.resource_id_base,
        .resource_id_mask = header.resource_id_mask,
        .release_number = header.release_number,
        .motion_buffer_size = header.motion_buffer_size,
        .vendor = vendor,
        .maximum_request_length = header.maximum_request_length,
        .image_byte_order = header.image_byte_order,
        .bitmap_bit_order = header.bitmap_bit_order,
        .bitmap_scanline_unit = header.bitmap_scanline_unit,
        .bitmap_scanline_pad = header.bitmap_scanline_pad,
        .min_keycode = header.min_keycode,
        .max_keycode = header.max_keycode,
        .pixmap_formats = pixmap_formats,
        .screens = screens,
    };
}

fn receivePixmapFormats(
    client: *Client,
    allocator: std.mem.Allocator,
    count: u8,
) ![]PixmapFormat {
    const formats = try allocator.alloc(PixmapFormat, count);
    errdefer allocator.free(formats);

    for (formats) |*format| {
        format.* = try client.recv(PixmapFormat);
    }

    return formats;
}

fn receiveScreen(
    client: *Client,
    allocator: std.mem.Allocator,
) !Screen {
    const screen = try client.recv(ScreenRecord);

    const depths = try allocator.alloc(Depth, screen.depth_count);
    var received_depths: usize = 0;
    errdefer {
        for (depths[0..received_depths]) |depth| depth.deinit(allocator);
        allocator.free(depths);
    }

    while (received_depths < depths.len) : (received_depths += 1) {
        depths[received_depths] = try receiveDepth(client, allocator);
    }

    return .{ .screen = screen, .depths = depths };
}

fn receiveDepth(
    client: *Client,
    allocator: std.mem.Allocator,
) !Depth {
    const depth = try client.recv(DepthRecord);

    const visuals = try allocator.alloc(VisualType, depth.visual_count);
    errdefer allocator.free(visuals);

    for (visuals) |*visual| {
        visual.* = try client.recv(VisualType);
    }

    return .{ .depth = depth, .visuals = visuals };
}

pub fn deinit(self: *Server, allocator: std.mem.Allocator) void {
    for (self.screens) |screen| screen.deinit(allocator);
    allocator.free(self.screens);
    allocator.free(self.pixmap_formats);
    allocator.free(self.vendor);
}

fn paddedLength(length: usize) usize {
    return (length + 3) & ~@as(usize, 3);
}
