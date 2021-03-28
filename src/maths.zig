const std = @import("std");
const testing = std.testing;
const console = @import("console.zig");

pub const Vec4 = packed union {
    xyzw: packed struct {
        x: f32,
        y: f32,
        z: f32,
        w: f32,
    },
    rgba: packed struct {
        r: f32,
        g: f32,
        b: f32,
        a: f32,
    },
    array: [4]f32,

    pub fn new_point(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return Vec4{
            .xyzw = .{
                .x = x,
                .y = y,
                .z = z,
                .w = w,
            },
        };
    }

    pub fn new_colour(r: f32, g: f32, b: f32, a: f32) Vec4 {
        return Vec4{ .rgba = .{ .r = r, .g = g, .b = b, .a = a } };
    }

    pub fn print_to_string(self: Vec4, allocator: *std.mem.Allocator) ![]const u8 {
        const vec = self.xyzw;
        return std.fmt.allocPrint(allocator, "Vec4( {d:.5}, {d:.5}, {d:.5}, {d:.5} )", .{ vec.x, vec.y, vec.z, vec.w });
    }

    pub fn print(self: Vec4, allocator: *std.mem.Allocator) !void {
        const as_string = try self.print_to_string(allocator);
        defer allocator.free(as_string);
        console.debug("{}\n", .{as_string});
    }
};

test "vec4 union" {
    var colour = Vec4.new_colour(0.5, 0.4, 0.3, 0.2);
    var point = Vec4.new_point(0.5, 0.4, 0.3, 0.2);
    testing.expectEqual(colour.array, point.array);
    testing.expectEqual(colour.xyzw, point.xyzw);
    testing.expectEqual(colour.rgba, point.rgba);
}

pub const Matrix4 = packed struct {
    columns: [4][4]f32,

    pub fn new(n00: f32, n01: f32, n02: f32, n03: f32, n10: f32, n11: f32, n12: f32, n13: f32, n20: f32, n21: f32, n22: f32, n23: f32, n30: f32, n31: f32, n32: f32, n33: f32) Matrix4 {
        var matrix: Matrix4 = undefined;
        matrix.columns[0][0] = n00;
        matrix.columns[0][1] = n01;
        matrix.columns[0][2] = n02;
        matrix.columns[0][3] = n03;
        matrix.columns[1][0] = n10;
        matrix.columns[1][1] = n11;
        matrix.columns[1][2] = n12;
        matrix.columns[1][3] = n13;
        matrix.columns[2][0] = n20;
        matrix.columns[2][1] = n21;
        matrix.columns[2][2] = n22;
        matrix.columns[2][3] = n23;
        matrix.columns[3][0] = n30;
        matrix.columns[3][1] = n31;
        matrix.columns[3][2] = n32;
        matrix.columns[3][3] = n33;
        return matrix;
    }

    pub fn identity() Matrix4 {
        return new(1.0, 0.0, 0.0, 0.0, // col 0
            0.0, 1.0, 0.0, 0.0, // col 1
            0.0, 0.0, 1.0, 0.0, // col 2
            0.0, 0.0, 0.0, 1.0); // col 3
    }

    pub fn zero() Matrix4 {
        return new(0.0, 0.0, 0.0, 0.0, // col 0
            0.0, 0.0, 0.0, 0.0, // col 1
            0.0, 0.0, 0.0, 0.0, // col 2
            0.0, 0.0, 0.0, 0.0); // col 3
    }

    pub fn scale(x: f32, y: f32, z: f32) Matrix4 {
        return new(x, 0.0, 0.0, 0.0, // col 0
            0.0, y, 0.0, 0.0, // col 1
            0.0, 0.0, z, 0.0, // col 2
            0.0, 0.0, 0.0, 1.0); // col 3
    }

    pub fn translation(x: f32, y: f32, z: f32) Matrix4 {
        return new(1.0, 0.0, 0.0, 0.0, // col 0
            0.0, 1.0, 0.0, 0.0, // col 1
            0.0, 0.0, 1.0, 0.0, //col 2
            x, y, z, 1.0); // col 3
    }

    pub fn mul(self: Matrix4, other: Matrix4) Matrix4 {
        var mat = zero();

        const indices = [_]u32{ 0, 1, 2, 3 };
        inline for (indices) |row| {
            inline for (indices) |col| {
                inline for (indices) |i| {
                    mat.columns[col][row] += self.columns[i][row] * other.columns[col][i];
                }
            }
        }

        return mat;
    }

    pub fn print(self: Matrix4) void {
        const indices = [_]u32{ 0, 1, 2, 3 };
        inline for (indices) |row| {
            inline for (indices) |col| {
                if (self.columns[col][row] >= 0.0) {
                    console.debug(" ", .{});
                }
                console.debug("{d:.5}", .{self.columns[col][row]});
                if (col < 3) {
                    console.debug(", ", .{});
                }
            }
            console.debug("\n", .{});
        }
    }
};

test "matrix4 identity" {
    const identity = Matrix4.identity();
    const matrix = identity.columns;
    for (matrix) |col, col_idx| {
        for (col) |cell, row_idx| {
            if (row_idx == col_idx) {
                testing.expectEqual(@as(f32, 1.0), cell);
            } else {
                testing.expectEqual(@as(f32, 0.0), cell);
            }
        }
    }
}

pub fn mat4_times_vec4(matrix: Matrix4, vector: Vec4) Vec4 {
    const vec = vector.xyzw;
    return Vec4.new_point(
        matrix.columns[0][0] * vec.x + matrix.columns[1][0] * vec.y + matrix.columns[2][0] * vec.z + matrix.columns[3][0] * vec.w,
        matrix.columns[0][1] * vec.x + matrix.columns[1][1] * vec.y + matrix.columns[2][1] * vec.z + matrix.columns[3][1] * vec.w,
        matrix.columns[0][2] * vec.x + matrix.columns[1][2] * vec.y + matrix.columns[2][2] * vec.z + matrix.columns[3][2] * vec.w,
        matrix.columns[0][3] * vec.x + matrix.columns[1][3] * vec.y + matrix.columns[2][3] * vec.z + matrix.columns[3][3] * vec.w,
    );
}

test "matrix4 times vec4" {
    const identity = Matrix4.identity();
    const input = Vec4.new_point(0.4, 0.2, 0.8, 0.5);
    testing.expectEqual(input.array, mat4_times_vec4(identity, input).array);

    const zero = Matrix4.zero();
    testing.expectEqual(Vec4.new_point(0.0, 0.0, 0.0, 0.0).xyzw, mat4_times_vec4(zero, input).xyzw);
}

test "scaling" {
    const scale = Matrix4.scale(0.5, 0.5, 1.0);
    const input = Vec4.new_point(1.0, 1.0, 1.0, 1.0);
    const expected = Vec4.new_point(0.5, 0.5, 1.0, 1.0);
    testing.expectEqual(expected.xyzw, mat4_times_vec4(scale, input).xyzw);
}

test "translating" {
    const translation = Matrix4.translation(-0.2, 0.3, 0.4);
    const input = Vec4.new_point(0.7, 0.1, 0.2, 1.0);
    const expected = Vec4.new_point(0.5, 0.4, 0.6, 1.0);
    testing.expectEqual(expected.xyzw, mat4_times_vec4(translation, input).xyzw);
}
