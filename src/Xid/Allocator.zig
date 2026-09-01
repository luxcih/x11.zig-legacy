//! Client-side allocation of X11 resource identifiers.
//!
//! During setup, the X server grants each client a resource-ID base and mask.
//! The client can then allocate valid IDs locally for resources such as windows,
//! pixmaps, and graphics contexts without asking the server for every ID.

const std = @import("std");
const Xid = @import("../Xid.zig").Xid;

const Allocator = @This();
pub const Error = error{
    Exhausted,
};

base: u32,
mask: u32,
next_index: u64 = 0,

pub fn init(base: u32, mask: u32) Allocator {
    return .{
        .base = base,
        .mask = mask,
    };
}

/// Allocates the next resource ID permitted by the server-provided mask.
pub fn next(self: *Allocator) Error!Xid {
    if (self.next_index > self.mask)
        return error.Exhausted;

    const id: Xid = self.base | self.next_index;
    self.next_index += 1;

    return id;
}

test "allocate contiguous XIDs" {
    var allocator = Allocator.init(0x20000000, 0x00000003);

    try std.testing.expectEqual(@as(Xid, 0x20000000), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x20000001), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x20000002), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x20000003), try allocator.next());
    try std.testing.expectError(error.Exhausted, allocator.next());
}

