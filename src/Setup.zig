pub const Setup = struct {
    pub const ByteOrder = enum {
        little,
        big,
    };

    byte_order: ByteOrder = .little,
    major_version: u16 = 11,
    minor_version: u16 = 0,
    authorization_name: []const u8 = "",
    authorization_data: []const u8 = "",
};
