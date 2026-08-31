//! Representation of the remote X server established during connection setup.

const std = @import("std");
const Client = @import("Client.zig");
const Endian = std.builtin.Endian;
const Wire = @import("Wire.zig");
const PixmapFormat = @import("PixmapFormat.zig");
const Screen = @import("Screen.zig");
const Depth = @import("Depth.zig");
const VisualType = @import("VisualType.zig");

const Server = @This();

pub const Setup = struct {
    server: Server,
    resource_id_base: u32,
    resource_id_mask: u32,
};

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

pub fn receive(client: *Client) !Setup {
    var header: [32]u8 = undefined;
    try client.read(&header);

    const allocator = client.allocator;
    const endian = client.endian;

    const vendor_length = Wire.readU16(header[16..18], endian);
    const maximum_request_length = Wire.readU16(header[18..20], endian);
    const screen_count = header[20];
    const pixmap_format_count = header[21];

    const vendor = try allocator.alloc(u8, vendor_length);
    errdefer allocator.free(vendor);
    try client.read(vendor);

    const vendor_padding = paddedLength(@as(usize, vendor_length)) - vendor.len;
    if (vendor_padding != 0) {
        var padding: [3]u8 = undefined;
        try client.read(padding[0..vendor_padding]);
    }

    const pixmap_formats = try receivePixmapFormats(
        client,
        allocator,
        pixmap_format_count,
    );
    errdefer allocator.free(pixmap_formats);

    const screens = try allocator.alloc(ParsedScreen, screen_count);
    var received_screens: usize = 0;
    errdefer {
        for (screens[0..received_screens]) |screen| screen.deinit(allocator);
        allocator.free(screens);
    }

    while (received_screens < screens.len) : (received_screens += 1) {
        screens[received_screens] = try receiveScreen(client, allocator);
    }

    return .{
        .server = .{
        .release_number = Wire.readU32(header[0..4], endian),
        .motion_buffer_size = Wire.readU32(header[12..16], endian),
        .vendor = vendor,
        .maximum_request_length = maximum_request_length,
        .image_byte_order = header[22],
        .bitmap_bit_order = header[23],
        .bitmap_scanline_unit = header[24],
        .bitmap_scanline_pad = header[25],
        .min_keycode = header[26],
        .max_keycode = header[27],
        .pixmap_formats = pixmap_formats,
        .screens = screens,
        },
        .resource_id_base = Wire.readU32(header[4..8], endian),
        .resource_id_mask = Wire.readU32(header[8..12], endian),
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
        var bytes: [PixmapFormat.size]u8 = undefined;
        try client.read(&bytes);
        format.* = try PixmapFormat.parse(&bytes);
    }

    return formats;
}

fn receiveScreen(
    client: *Client,
    allocator: std.mem.Allocator,
) !ParsedScreen {
    var bytes: [Screen.size]u8 = undefined;
    try client.read(&bytes);

    const screen = try Screen.parse(&bytes, client.endian);

    const depths = try allocator.alloc(ParsedDepth, screen.depth_count);
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
) !ParsedDepth {
    var bytes: [Depth.size]u8 = undefined;
    try client.read(&bytes);

    const depth = try Depth.parse(&bytes, client.endian);

    const visuals = try allocator.alloc(VisualType, depth.visual_count);
    errdefer allocator.free(visuals);

    for (visuals) |*visual| {
        var visual_bytes: [VisualType.size]u8 = undefined;
        try client.read(&visual_bytes);
        visual.* = try VisualType.parse(&visual_bytes, client.endian);
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
