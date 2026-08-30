//! A native X11 client library written in Zig.

pub const Display = @import("Display.zig").Display;
pub const Connection = @import("Connection.zig").Connection;
pub const Setup = @import("Setup.zig").Setup;
pub const SetupResponse = @import("SetupResponse.zig").SetupResponse;
pub const SetupSuccess = @import("SetupSuccess.zig").SetupSuccess;
pub const PixmapFormat = @import("PixmapFormat.zig").PixmapFormat;
pub const Screen = @import("Screen.zig").Screen;
pub const Depth = @import("Depth.zig").Depth;
pub const VisualType = @import("VisualType.zig").VisualType;
pub const SetupInfo = @import("SetupInfo.zig").SetupInfo;
