//! A native X11 client library written in Zig.
//!
//! The public API is organized around the major parts of the X11 protocol:
//! connection and setup, resource allocation, windows, events, graphics,
//! and drawing.

pub const ByteOrder = @import("ByteOrder.zig").ByteOrder;

pub const Display = @import("Display.zig");
pub const Connection = @import("Connection.zig");

pub const Setup = @import("Setup.zig");
pub const SetupResponse = @import("SetupResponse.zig").SetupResponse;
pub const SetupInfo = @import("SetupInfo.zig");

pub const PixmapFormat = @import("PixmapFormat.zig");
pub const Screen = @import("Screen.zig");
pub const Depth = @import("Depth.zig");
pub const VisualType = @import("VisualType.zig");

pub const XidAllocator = @import("XidAllocator.zig");

pub const Window = @import("Window.zig");
pub const GC = @import("GC.zig");
pub const Draw = @import("Draw.zig");

pub const Event = @import("Event.zig").Event;
pub const Error = @import("Error.zig").Error;
pub const Response = @import("Response.zig");
pub const Input = @import("Input.zig");

pub const Atom = @import("Atom.zig");
