const std = @import("std");
const console = @import("console.zig");
const maths = @import("maths.zig");
const Matrix4 = maths.Matrix4;
const Vec4 = maths.Vec4;

pub const Rect = packed struct {
    center: [2]f32,
    bounds: [2]f32,

    pub fn new(center: [2]f32, bounds: [2]f32) Rect {
        return Rect{ .center = center, .bounds = bounds };
    }

    pub fn from_top_left_bottom_right(x0: f32, y0: f32, x1: f32, y1: f32) Rect {
        const width = x1 - x0;
        const height = y1 - y0;
        return Rect{ .center = [_]f32{ x0 + (width / 2.0), y0 + (height / 2.0) }, .bounds = [_]f32{ width, height } };
    }

    pub fn from_bounds(x: f32, y: f32) Rect {
        return Rect{ .center = [_]f32{ 0.0, 0.0 }, .bounds = [_]f32{ x, y } };
    }

    pub fn print_to_string(self: Rect, allocator: *std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "Center: [{d: >3.3},{d: >3.3}], bounds: [{d: >3.3},{d: >3.3}]", .{ self.center[0], self.center[1], self.bounds[0], self.bounds[1] });
    }

    pub fn print(self: Rect, allocator: *std.mem.Allocator) !void {
        const as_string = try self.print_to_string(allocator);
        defer allocator.free(as_string);
        console.debug("{}\n", .{as_string});
    }

    pub fn transform_within(self: Rect, outer: Rect) Matrix4 {
        const scale_matrix = Matrix4.scale(self.bounds[0] / outer.bounds[0], self.bounds[1] / outer.bounds[1], 1.0);
        const translation_matrix = Matrix4.translation((self.center[0] / outer.bounds[0]) * 2.0 - 1.0, -((self.center[1] / outer.bounds[1]) * 2.0 - 1.0), 0.0);
        return translation_matrix.mul(scale_matrix);
    }

    pub fn within_texture_coords(self: Rect) Matrix4 {
        const texture_rect = Rect.from_top_left_bottom_right(0.0, 0.0, 1.0, 1.0);
        const scale_matrix = Matrix4.scale(self.bounds[0] / texture_rect.bounds[0], self.bounds[1] / texture_rect.bounds[1], 1.0);
        // const translation_matrix = Matrix4.translation(self.center[0] / texture_rect.bounds[0], -self.center[1] / texture_rect.bounds[1], 0.0);
        const left_x = self.center[0] - self.bounds[0] / 2.0;
        // top means closer to 0 here
        const top_y = self.center[1] - self.bounds[1] / 2.0;
        const translation_matrix = Matrix4.translation(left_x / texture_rect.bounds[0], top_y / texture_rect.bounds[1], 0.0);
        // return scale_matrix.mul(translation_matrix);
        return translation_matrix.mul(scale_matrix);
    }
};

pub fn rect_to_transform_matrix(s0: f32, t0: f32, s1: f32, t1: f32) Matrix4 {
    const scale = Matrix4.scale(s1 - s0, t1 - t0, 1.0);
    const translation = Matrix4.translation(s0, t0, 0.0);
    return translation.mul(scale);
}
