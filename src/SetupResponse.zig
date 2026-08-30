const std = @import("std");
const Wire = @import("Wire.zig");
const ByteOrder = @import("ByteOrder.zig").ByteOrder;

pub const SetupResponse = union(enum) {
    failed: Failed,
    success: Success,
    authenticate: Authenticate,

    pub const ParseError = error{
        InvalidStatus,
    };

    pub const Failed = struct {
        reason_length: u8,
        major_version: u16,
        minor_version: u16,
        additional_length: u16,
    };

    pub const Success = struct {
        major_version: u16,
        minor_version: u16,
        additional_length: u16,
    };

    pub const Authenticate = struct {
        additional_length: u16,
    };

    pub fn parsePrefix(
        prefix: [8]u8,
        byte_order: ByteOrder,
    ) ParseError!SetupResponse {
        return switch (prefix[0]) {
            0 => .{ .failed = .{
                .reason_length = prefix[1],
                .major_version = Wire.readU16(prefix[2..4], byte_order),
                .minor_version = Wire.readU16(prefix[4..6], byte_order),
                .additional_length = Wire.readU16(prefix[6..8], byte_order),
            } },
            1 => .{ .success = .{
                .major_version = Wire.readU16(prefix[2..4], byte_order),
                .minor_version = Wire.readU16(prefix[4..6], byte_order),
                .additional_length = Wire.readU16(prefix[6..8], byte_order),
            } },
            2 => .{ .authenticate = .{
                .additional_length = Wire.readU16(prefix[6..8], byte_order),
            } },
            else => error.InvalidStatus,
        };
    }

    pub fn additionalBytes(self: SetupResponse) usize {
        return switch (self) {
            inline else => |response| @as(usize, response.additional_length) * 4,
        };
    }


};

test "parse big-endian setup response prefixes" {
    {
        const response = try SetupResponse.parsePrefix(
            .{ 1, 0, 0, 11, 0, 2, 0, 5 },
            .big,
        );

        switch (response) {
            .success => |success| {
                try std.testing.expectEqual(@as(u16, 11), success.major_version);
                try std.testing.expectEqual(@as(u16, 2), success.minor_version);
                try std.testing.expectEqual(@as(u16, 5), success.additional_length);
                try std.testing.expectEqual(@as(usize, 20), response.additionalBytes());
            },
            else => return error.TestUnexpectedResult,
        }
    }

    {
        const response = try SetupResponse.parsePrefix(
            .{ 0, 4, 0, 11, 0, 0, 0, 1 },
            .big,
        );

        switch (response) {
            .failed => |failed| {
                try std.testing.expectEqual(@as(u8, 4), failed.reason_length);
                try std.testing.expectEqual(@as(u16, 11), failed.major_version);
                try std.testing.expectEqual(@as(u16, 1), failed.additional_length);
            },
            else => return error.TestUnexpectedResult,
        }
    }

    {
        const response = try SetupResponse.parsePrefix(
            .{ 2, 0, 0, 0, 0, 0, 0, 2 },
            .big,
        );

        switch (response) {
            .authenticate => |authenticate| {
                try std.testing.expectEqual(@as(u16, 2), authenticate.additional_length);
                try std.testing.expectEqual(@as(usize, 8), response.additionalBytes());
            },
            else => return error.TestUnexpectedResult,
        }
    }
}

test "parse successful setup response prefix" {
    const response = try SetupResponse.parsePrefix(
        .{ 1, 0, 11, 0, 0, 0, 5, 0 },
        .little,
    );

    switch (response) {
        .success => |success| {
            try std.testing.expectEqual(@as(u16, 11), success.major_version);
            try std.testing.expectEqual(@as(u16, 0), success.minor_version);
            try std.testing.expectEqual(@as(u16, 5), success.additional_length);
            try std.testing.expectEqual(@as(usize, 20), response.additionalBytes());
        },
        else => return error.TestUnexpectedResult,
    }
}

test "parse failed setup response prefix" {
    const response = try SetupResponse.parsePrefix(
        .{ 0, 4, 11, 0, 0, 0, 1, 0 },
        .little,
    );

    switch (response) {
        .failed => |failed| {
            try std.testing.expectEqual(@as(u8, 4), failed.reason_length);
            try std.testing.expectEqual(@as(u16, 11), failed.major_version);
            try std.testing.expectEqual(@as(usize, 4), response.additionalBytes());
        },
        else => return error.TestUnexpectedResult,
    }
}

test "parse authenticate setup response prefix" {
    const response = try SetupResponse.parsePrefix(
        .{ 2, 0, 0, 0, 0, 0, 2, 0 },
        .little,
    );

    switch (response) {
        .authenticate => |authenticate| {
            try std.testing.expectEqual(@as(u16, 2), authenticate.additional_length);
            try std.testing.expectEqual(@as(usize, 8), response.additionalBytes());
        },
        else => return error.TestUnexpectedResult,
    }
}

test "reject invalid setup response status" {
    try std.testing.expectError(
        error.InvalidStatus,
        SetupResponse.parsePrefix(
            .{ 3, 0, 0, 0, 0, 0, 0, 0 },
            .little,
        ),
    );
}
