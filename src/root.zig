//! A native X11 client library written in Zig.
//!
//! The public API is organized around the major parts of the X11 protocol:
//! connection and setup, resource allocation, windows, events, graphics,
//! and drawing.

pub const ByteOrder = @import("ByteOrder.zig").ByteOrder;

pub const Display = @import("Display.zig").Display;
pub const Connection = @import("Connection.zig").Connection;

pub const Setup = @import("Setup.zig").Setup;
pub const SetupResponse = @import("SetupResponse.zig").SetupResponse;
pub const SetupInfo = @import("SetupInfo.zig").SetupInfo;

pub const PixmapFormat = @import("PixmapFormat.zig").PixmapFormat;
pub const Screen = @import("Screen.zig").Screen;
pub const Depth = @import("Depth.zig").Depth;
pub const VisualType = @import("VisualType.zig").VisualType;

pub const XidAllocator = @import("XidAllocator.zig").XidAllocator;

pub const Window = @import("Window.zig").Window;
pub const GC = @import("GC.zig").GC;
pub const Draw = @import("Draw.zig");

pub const Event = @import("Event.zig").Event;
pub const Error = @import("Error.zig").Error;
pub const Input = @import("Input.zig").Input;
