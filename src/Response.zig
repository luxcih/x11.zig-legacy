const std = @import("std");

/// The category of a 32-byte message received from an X11 server.
pub const Type = enum {
    error,
    reply,
    event,

    pub fn classify(response_type: u8) Type {
        return switch (response_type & 0x7f) {
            0 => .error,
            1 => .reply,
            else => .event,
        };
    }
};

test "classify X11 response types" {
    try std.testing.expectEqual(Type.error, Type.classify(0));
    try std.testing.expectEqual(Type.reply, Type.classify(1));
    try std.testing.expectEqual(Type.event, Type.classify(2));
    try std.testing.expectEqual(Type.event, Type.classify(127));

    // The high bit marks a synthetic event.
    try std.testing.expectEqual(Type.event, Type.classify(0x82));
}
