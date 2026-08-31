const std = @import("std");
const x11 = @import("x11");

pub fn main() !void {
    const display = try x11.Display.parse("tcp/example.org:0.1");

    std.debug.print(
        \\protocol: {s}
        \\host: {s}
        \\separator: {s}
        \\number: {}
        \\screen: {}
        \\
    , .{
        display.protocol orelse "(none)",
        display.host,
        @tagName(display.separator),
        display.display_number,
        display.screen_number,
    });
}
