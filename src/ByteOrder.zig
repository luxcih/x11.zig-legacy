//! Endianness used by the X11 wire protocol.
//!
//! X11 supports the same little- and big-endian byte orders represented by
//! Zig's builtin Endian type.

const std = @import("std");

pub const ByteOrder = std.builtin.Endian;
