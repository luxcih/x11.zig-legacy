const std = @import("std");

pub const XidAllocator = struct {
    pub const Error = error{
        Exhausted,
    };

    base: u32,
    mask: u32,
    next_index: u64 = 0,

    pub fn init(base: u32, mask: u32) XidAllocator {
        return .{
            .base = base,
            .mask = mask,
        };
    }

    pub fn next(self: *XidAllocator) Error!u32 {
        const capacity = @as(u64, 1) << @popCount(self.mask);
        if (self.next_index >= capacity)
            return error.Exhausted;

        const id = self.base | applyMask(self.mask, self.next_index);
        self.next_index += 1;

        return id;
    }

    fn applyMask(mask: u32, index: u64) u32 {
        var result: u32 = 0;
        var source_bit: u6 = 0;
        var destination_bit: u6 = 0;

        while (destination_bit < 32) : (destination_bit += 1) {
            const destination_mask = @as(u32, 1) << destination_bit;

            if (mask & destination_mask == 0)
                continue;

            if (index & (@as(u64, 1) << source_bit) != 0)
                result |= destination_mask;

            source_bit += 1;
        }

        return result;
    }
};

test "allocate contiguous XIDs" {
    var allocator = XidAllocator.init(0x20000000, 0x00000003);

    try std.testing.expectEqual(
        @as(u32, 0x20000000),
        try allocator.next(),
    );
    try std.testing.expectEqual(
        @as(u32, 0x20000001),
        try allocator.next(),
    );
    try std.testing.expectEqual(
        @as(u32, 0x20000002),
        try allocator.next(),
    );
    try std.testing.expectEqual(
        @as(u32, 0x20000003),
        try allocator.next(),
    );
    try std.testing.expectError(error.Exhausted, allocator.next());
}

test "allocate sparse-mask XIDs" {
    var allocator = XidAllocator.init(0x10000000, 0x00000005);

    try std.testing.expectEqual(
        @as(u32, 0x10000000),
        try allocator.next(),
    );
    try std.testing.expectEqual(
        @as(u32, 0x10000001),
        try allocator.next(),
    );
    try std.testing.expectEqual(
        @as(u32, 0x10000004),
        try allocator.next(),
    );
    try std.testing.expectEqual(
        @as(u32, 0x10000005),
        try allocator.next(),
    );
}
