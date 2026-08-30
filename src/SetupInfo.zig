const ByteOrder = @import("ByteOrder.zig").ByteOrder;
const std = @import("std");
const SetupSuccess = @import("SetupSuccess.zig").SetupSuccess;
const PixmapFormat = @import("PixmapFormat.zig").PixmapFormat;
const Screen = @import("Screen.zig").Screen;
const Depth = @import("Depth.zig").Depth;
const VisualType = @import("VisualType.zig").VisualType;

pub const SetupInfo = struct {
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
            for (self.depths) |depth| {
                depth.deinit(allocator);
            }
            allocator.free(self.depths);
        }
    };

    success: SetupSuccess,
    pixmap_formats: []PixmapFormat,
    screens: []ParsedScreen,

    pub fn parse(
        allocator: std.mem.Allocator,
        body: []const u8,
        byte_order: ByteOrder,
    ) !SetupInfo {
        const success = try SetupSuccess.parse(body, byte_order);

        const pixmap_formats = try parsePixmapFormats(
            allocator,
            body,
            success,
        );
        errdefer allocator.free(pixmap_formats);

        const screens = try allocator.alloc(
            ParsedScreen,
            success.screen_count,
        );
        var parsed_screens: usize = 0;
        errdefer {
            for (screens[0..parsed_screens]) |screen| {
                screen.deinit(allocator);
            }
            allocator.free(screens);
        }

        var screen_offset = success.screensOffset();

        while (parsed_screens < screens.len) : (parsed_screens += 1) {
            const parsed = try parseScreen(
                allocator,
                body,
                screen_offset,
                byte_order,
            );

            screens[parsed_screens] = parsed.screen;
            screen_offset = parsed.next_offset;
        }

        return .{
            .success = success,
            .pixmap_formats = pixmap_formats,
            .screens = screens,
        };
    }

    pub fn deinit(self: *SetupInfo, allocator: std.mem.Allocator) void {
        for (self.screens) |screen| {
            screen.deinit(allocator);
        }

        allocator.free(self.screens);
        allocator.free(self.pixmap_formats);
    }

    fn parsePixmapFormats(
        allocator: std.mem.Allocator,
        body: []const u8,
        success: SetupSuccess,
    ) ![]PixmapFormat {
        const offset = success.pixmapFormatsOffset();
        const length = success.pixmapFormatsLength();

        if (offset + length > body.len)
            return error.BodyTooShort;

        const formats = try allocator.alloc(
            PixmapFormat,
            success.pixmap_format_count,
        );
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
        byte_order: ByteOrder,
    ) !struct { screen: ParsedScreen, next_offset: usize } {
        if (offset + Screen.size > body.len)
            return error.BodyTooShort;

        const screen = try Screen.parse(
            body[offset .. offset + Screen.size],
            byte_order,
        );

        const depths = try allocator.alloc(
            ParsedDepth,
            screen.depth_count,
        );
        var parsed_depths: usize = 0;
        errdefer {
            for (depths[0..parsed_depths]) |depth| {
                depth.deinit(allocator);
            }
            allocator.free(depths);
        }

        var depth_offset = offset + Screen.size;

        while (parsed_depths < depths.len) : (parsed_depths += 1) {
            if (depth_offset + Depth.size > body.len)
                return error.BodyTooShort;

            const depth = try Depth.parse(
                body[depth_offset .. depth_offset + Depth.size],
                byte_order,
            );

            const total_length = depth.totalLength();
            if (depth_offset + total_length > body.len)
                return error.BodyTooShort;

            const visuals = try parseVisuals(
                allocator,
                body,
                depth,
                depth_offset + depth.visualsOffset(),
                byte_order,
            );

            depths[parsed_depths] = .{
                .depth = depth,
                .visuals = visuals,
            };

            depth_offset += total_length;
        }

        return .{
            .screen = .{
                .screen = screen,
                .depths = depths,
            },
            .next_offset = depth_offset,
        };
    }

    fn parseVisuals(
        allocator: std.mem.Allocator,
        body: []const u8,
        depth: Depth,
        offset: usize,
        byte_order: ByteOrder,
    ) ![]VisualType {
        const visuals = try allocator.alloc(
            VisualType,
            depth.visual_count,
        );
        errdefer allocator.free(visuals);

        for (visuals, 0..) |*visual, index| {
            const visual_offset = offset + index * VisualType.size;
            visual.* = try VisualType.parse(
                body[visual_offset .. visual_offset + VisualType.size],
                byte_order,
            );
        }

        return visuals;
    }

};
