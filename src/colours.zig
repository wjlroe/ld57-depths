const std = @import("std");
const console = @import("console.zig");
const Vec4 = @import("maths.zig").Vec4;

pub const RED = colour_from_hex("#ff0000");
pub const GREEN = colour_from_hex("#00ff00");
pub const BLUE = colour_from_hex("#0000ff");
pub const BLACK = colour_from_hex("#000000");
pub const TRANSPARENT = Vec4(f32){ .array = [_]f32{ 0.0, 0.0, 0.0, 0.0 } };

pub fn colour_from_hex(hex: []const u8) Vec4(f32) {
    var numbers: [3]u8 = undefined;
    std.fmt.hexToBytes(numbers[0..], hex[1..]) catch unreachable;
    const colour = Vec4(f32){
        .rgba = .{
            .r = @intToFloat(f32, numbers[0]) / 256.0,
            .g = @intToFloat(f32, numbers[1]) / 256.0,
            .b = @intToFloat(f32, numbers[2]) / 256.0,
            .a = 1.0,
        },
    };
    return colour;
}
