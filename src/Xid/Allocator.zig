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
next_index: u32 = 0,
shift: u5,

pub fn init(base: u32, mask: u32) Allocator {
    return .{
        .base = base,
        .mask = mask,
        .shift = @ctz(mask),
    };
}

/// Allocates the next resource ID permitted by the server-provided mask.
pub fn next(self: *Allocator) Error!Xid {
    const capacity = self.mask >> self.shift;
    if (self.next_index > capacity)
        return error.Exhausted;

    const id: Xid = self.base | (self.next_index << self.shift);
    self.next_index += 1;

    return id;
}

test "allocate low-bit XIDs" {
    var allocator = Allocator.init(0x20000000, 0x00000003);

    try std.testing.expectEqual(@as(Xid, 0x20000000), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x20000001), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x20000002), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x20000003), try allocator.next());
    try std.testing.expectError(error.Exhausted, allocator.next());
}


test "allocate shifted contiguous XIDs" {
    var allocator = Allocator.init(0x10000000, 0x0000001c);

    try std.testing.expectEqual(@as(Xid, 0x10000000), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x10000004), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x10000008), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x1000000c), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x10000010), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x10000014), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x10000018), try allocator.next());
    try std.testing.expectEqual(@as(Xid, 0x1000001c), try allocator.next());
    try std.testing.expectError(error.Exhausted, allocator.next());
}
