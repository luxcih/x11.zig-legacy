const std = @import("std");
const Setup = @import("Setup.zig").Setup;
const SetupSuccess = @import("SetupSuccess.zig").SetupSuccess;
const PixmapFormat = @import("PixmapFormat.zig").PixmapFormat;
const Screen = @import("Screen.zig").Screen;
const Depth = @import("Depth.zig").Depth;
const VisualType = @import("VisualType.zig").VisualType;

pub const SetupInfo = struct {
    pub const ParseError = error{
        BodyTooShort,
    };

    pub const ParsedDepth = struct {
        depth: Depth,
        visuals: []VisualType,
    };

    pub const ParsedScreen = struct {
        screen: Screen,
        depths: []ParsedDepth,
    };

    success: SetupSuccess,
    pixmap_formats: []PixmapFormat,
    screens: []ParsedScreen,

    pub fn parse(
        allocator: std.mem.Allocator,
        body: []const u8,
        byte_order: Setup.ByteOrder,
    ) !SetupInfo {
        const success = try SetupSuccess.parse(body, byte_order);

        const pixmap_formats = try allocator.alloc(
            PixmapFormat,
            success.pixmap_format_count,
        );
        errdefer allocator.free(pixmap_formats);

        const formats_offset = success.pixmapFormatsOffset();
        const formats_length = success.pixmapFormatsLength();
        if (formats_offset + formats_length > body.len)
            return error.BodyTooShort;

        for (pixmap_formats, 0..) |*format, index| {
            const offset = formats_offset + index * PixmapFormat.size;
            format.* = try PixmapFormat.parse(
                body[offset .. offset + PixmapFormat.size],
            );
        }

        const screens = try allocator.alloc(
            ParsedScreen,
            success.screen_count,
        );
        errdefer allocator.free(screens);

        var parsed_screens: usize = 0;
        errdefer {
            for (screens[0..parsed_screens]) |parsed_screen| {
                for (parsed_screen.depths) |parsed_depth| {
                    allocator.free(parsed_depth.visuals);
                }
                allocator.free(parsed_screen.depths);
            }
        }

        var screen_offset = success.screensOffset();

        while (parsed_screens < screens.len) : (parsed_screens += 1) {
            if (screen_offset + Screen.size > body.len)
                return error.BodyTooShort;

            const screen = try Screen.parse(
                body[screen_offset .. screen_offset + Screen.size],
                byte_order,
            );

            const depths = try allocator.alloc(
                ParsedDepth,
                screen.depth_count,
            );
            errdefer allocator.free(depths);

            var parsed_depths: usize = 0;
            errdefer {
                for (depths[0..parsed_depths]) |parsed_depth| {
                    allocator.free(parsed_depth.visuals);
                }
            }

            var depth_offset = screen_offset + Screen.size;

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

                const visuals = try allocator.alloc(
                    VisualType,
                    depth.visual_count,
                );
                errdefer allocator.free(visuals);

                const visuals_offset = depth_offset + depth.visualsOffset();

                for (visuals, 0..) |*visual, index| {
                    const offset = visuals_offset + index * VisualType.size;
                    visual.* = try VisualType.parse(
                        body[offset .. offset + VisualType.size],
                        byte_order,
                    );
                }

                depths[parsed_depths] = .{
                    .depth = depth,
                    .visuals = visuals,
                };

                depth_offset += total_length;
            }

            screens[parsed_screens] = .{
                .screen = screen,
                .depths = depths,
            };

            screen_offset = depth_offset;
        }

        return .{
            .success = success,
            .pixmap_formats = pixmap_formats,
            .screens = screens,
        };
    }

    pub fn deinit(self: *SetupInfo, allocator: std.mem.Allocator) void {
        for (self.screens) |parsed_screen| {
            for (parsed_screen.depths) |parsed_depth| {
                allocator.free(parsed_depth.visuals);
            }
            allocator.free(parsed_screen.depths);
        }

        allocator.free(self.screens);
        allocator.free(self.pixmap_formats);
    }
};
