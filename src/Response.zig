//! Classification of the fixed-size headers sent by an X server.
//!
//! The first byte determines whether an incoming 32-byte message is an error,
//! reply, or event. Request-specific code interprets replies after classification.

const std = @import("std");

/// A fixed-size X11 server response header.
pub const size: usize = 32;

/// The category of a message received from an X11 server.
pub const Type = enum {
    protocol_error,
    reply,
    event,

    pub fn classify(response_type: u8) Type {
        return switch (response_type & 0x7f) {
            0 => .protocol_error,
            1 => .reply,
            else => .event,
        };
    }
};

test "classify X11 response types" {
    try std.testing.expectEqual(Type.protocol_error, Type.classify(0));
    try std.testing.expectEqual(Type.reply, Type.classify(1));
    try std.testing.expectEqual(Type.event, Type.classify(2));
    try std.testing.expectEqual(Type.event, Type.classify(127));

    // The high bit marks a synthetic event.
    try std.testing.expectEqual(Type.event, Type.classify(0x82));
}


/// Classifies a complete 32-byte X11 response header.
///
/// Replies may carry additional data after this header; the request-specific
/// reply parser remains responsible for interpreting that data.
pub fn classify(bytes: []const u8) error{InvalidLength}!Type {
    if (bytes.len != size) return error.InvalidLength;
    return Type.classify(bytes[0]);
}

test "classify a complete X11 response header" {
    var bytes: [size]u8 = [_]u8{0} ** size;

    bytes[0] = 0;
    try std.testing.expectEqual(Type.protocol_error, try classify(&bytes));

    bytes[0] = 1;
    try std.testing.expectEqual(Type.reply, try classify(&bytes));

    bytes[0] = 12;
    try std.testing.expectEqual(Type.event, try classify(&bytes));
}

test "reject incorrectly sized response header" {
    try std.testing.expectError(error.InvalidLength, classify(&.{ 1 }));
}

test "synthetic bit does not change reply or error classification" {
    // The high bit is meaningful for events only, but classification strips it
    // uniformly before determining the response category.
    try std.testing.expectEqual(Type.protocol_error, Type.classify(0x80));
    try std.testing.expectEqual(Type.reply, Type.classify(0x81));
}

test "classify synthetic event response header" {
    var bytes: [size]u8 = [_]u8{0} ** size;
    bytes[0] = 0x8c;

    try std.testing.expectEqual(Type.event, try classify(&bytes));
}
