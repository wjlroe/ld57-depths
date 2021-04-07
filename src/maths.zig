const std = @import("std");
const testing = std.testing;
const console = @import("console.zig");

pub fn Vec2(comptime T: type) type {
    return packed union {
        const Self = @This();

        xy: packed struct {
            x: T,
            y: T,
        },
        array: [2]T,

        pub fn new_point(x: T, y: T) Self {
            return Self{
                .xy = .{ .x = x, .y = y },
            };
        }
    };
}

pub fn Vec4(comptime T: type) type {
    return packed union {
        const Self = @This();

        xyzw: packed struct {
            x: T,
            y: T,
            z: T,
            w: T,
        },
        rgba: packed struct {
            r: T,
            g: T,
            b: T,
            a: T,
        },
        array: [4]T,

        pub fn new_point(x: T, y: T, z: T, w: T) Self {
            return Self{
                .xyzw = .{
                    .x = x,
                    .y = y,
                    .z = z,
                    .w = w,
                },
            };
        }

        pub fn new_xy(x: T, y: T) Self {
            return Self{
                .xyzw = .{
                    .x = x,
                    .y = y,
                    .z = 0.0,
                    .w = 1.0,
                },
            };
        }

        pub fn new_colour(r: T, g: T, b: T, a: T) Self {
            return Self{ .rgba = .{ .r = r, .g = g, .b = b, .a = a } };
        }

        pub fn print_to_string(self: Self, allocator: *std.mem.Allocator) ![]const u8 {
            const vec = self.xyzw;
            return std.fmt.allocPrint(allocator, "Vec4( {d:.5}, {d:.5}, {d:.5}, {d:.5} )", .{ vec.x, vec.y, vec.z, vec.w });
        }

        pub fn print(self: Self, allocator: *std.mem.Allocator) !void {
            const as_string = try self.print_to_string(allocator);
            defer allocator.free(as_string);
            console.debug("{}\n", .{as_string});
        }
    };
}

test "vec4 union" {
    var colour = Vec4(f32).new_colour(0.5, 0.4, 0.3, 0.2);
    var point = Vec4(f32).new_point(0.5, 0.4, 0.3, 0.2);
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

pub fn mat4_times_vec4(matrix: Matrix4, vector: Vec4(f32)) Vec4(f32) {
    const vec = vector.xyzw;
    return Vec4(f32).new_point(
        matrix.columns[0][0] * vec.x + matrix.columns[1][0] * vec.y + matrix.columns[2][0] * vec.z + matrix.columns[3][0] * vec.w,
        matrix.columns[0][1] * vec.x + matrix.columns[1][1] * vec.y + matrix.columns[2][1] * vec.z + matrix.columns[3][1] * vec.w,
        matrix.columns[0][2] * vec.x + matrix.columns[1][2] * vec.y + matrix.columns[2][2] * vec.z + matrix.columns[3][2] * vec.w,
        matrix.columns[0][3] * vec.x + matrix.columns[1][3] * vec.y + matrix.columns[2][3] * vec.z + matrix.columns[3][3] * vec.w,
    );
}

test "matrix4 times vec4" {
    const identity = Matrix4.identity();
    const input = Vec4(f32).new_point(0.4, 0.2, 0.8, 0.5);
    testing.expectEqual(input.array, mat4_times_vec4(identity, input).array);

    const zero = Matrix4.zero();
    testing.expectEqual(Vec4(f32).new_point(0.0, 0.0, 0.0, 0.0).xyzw, mat4_times_vec4(zero, input).xyzw);
}

test "scaling" {
    const scale = Matrix4.scale(0.5, 0.5, 1.0);
    const input = Vec4(f32).new_point(1.0, 1.0, 1.0, 1.0);
    const expected = Vec4(f32).new_point(0.5, 0.5, 1.0, 1.0);
    testing.expectEqual(expected.xyzw, mat4_times_vec4(scale, input).xyzw);
}

test "translating" {
    const translation = Matrix4.translation(-0.2, 0.3, 0.4);
    const input = Vec4(f32).new_point(0.7, 0.1, 0.2, 1.0);
    const expected = Vec4(f32).new_point(0.5, 0.4, 0.6, 1.0);
    testing.expectEqual(expected.xyzw, mat4_times_vec4(translation, input).xyzw);
}

fn is_vec4_equal(comptime T: type, in_vec1: Vec4(T), in_vec2: Vec4(T), name: []const u8) bool {
    var equal = true;
    const vec1 = in_vec1.xyzw;
    const vec2 = in_vec2.xyzw;
    if (vec1.x != vec2.x) {
        equal = false;
        // std.debug.warn("[{}] x coord different: expected: {d: >3} vs. actual: {d: >3}\n", .{name, vec1.x, vec2.x});
    }
    if (vec1.y != vec2.y) {
        equal = false;
        // std.debug.warn("[{}] y coord different: expected: {d: >3} vs. actual: {d: >3}\n", .{name, vec1.y, vec2.y});
    }
    if (vec1.z != vec2.z) {
        equal = false;
        // std.debug.warn("[{}] z coord different: expected: {d: >3} vs. actual: {d: >3}\n", .{name, vec1.z, vec2.z});
    }
    if (vec1.w != vec2.w) {
        equal = false;
        // std.debug.warn("[{}] w coord different: expected: {d: >3} vs. actual: {d: >3}\n", .{name, vec1.w, vec2.w});
    }
    return equal;
}

test "circle points" {
    var all_good = true;
    const TestData = struct {
        in_x: f32,
        in_y: f32,
        expected_x: f32,
        expected_y: f32,
        name: []const u8,
    };
    const values = [_]TestData{
        .{.in_x = 0.5, .in_y = 0.5, .expected_x = 0.0, .expected_y = 0.0, .name = "middle point"},
        .{.in_x = 1.0, .in_y = 1.0, .expected_x = 1.0, .expected_y = 1.0, .name = "bottom right"},
    };
    const tex_scale = Matrix4.scale(2.0, 2.0, 1.0);
    const tex_translation = Matrix4.translation(-1.0, -1.0, 0.0);
    const tex_transform = tex_translation.mul(tex_scale);
    for (values) |value_slice| {
        const input = Vec4(f32).new_xy(value_slice.in_x, value_slice.in_y);
        const expected = Vec4(f32).new_xy(value_slice.expected_x, value_slice.expected_y);
        const actual = mat4_times_vec4(tex_transform, input);
        if (!is_vec4_equal(f32, expected, actual, value_slice.name)) {
            all_good = false;
            std.debug.warn("\nBAD: {}. in: [{d: >3},{d: >3}], expected: [{d: >3},{d: >3}], actual: [{d: >3},{d: >3}]\n", .{value_slice.name, value_slice.in_x, value_slice.in_y, value_slice.expected_x, value_slice.expected_y, actual.xyzw.x, actual.xyzw.y});
        }
    }
    testing.expect(all_good);
}
