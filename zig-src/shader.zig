const c = @import("c.zig");
const std = @import("std");
const console = @import("console.zig");
usingnamespace @import("opengl.zig");
usingnamespace @import("maths.zig");

pub const Shader = struct {
    prog_id: c_uint,
    num_textures: u32,

    pub fn new(prog_id: c_uint, num_textures: u32) Shader {
        return Shader{ .prog_id = prog_id, .num_textures = num_textures };
    }

    pub fn set_int(self: Shader, opengl: *OpenGL, uniform_name: [*c]const u8, value: i32) void {
        const location = self.get_location(opengl, uniform_name);
        if (location != -1) {
            opengl.glUniform1i(location, value);
        }
    }

    pub fn set_float(self: Shader, opengl: *OpenGL, uniform_name: [*c]const u8, value: f32) void {
        const location = self.get_location(opengl, uniform_name);
        if (location != -1) {
            opengl.glUniform1f(location, value);
        }
    }

    pub fn set_vec4(self: Shader, opengl: *OpenGL, uniform_name: [*c]const u8, value: [4]f32) void {
        const location = self.get_location(opengl, uniform_name);
        if (location != -1) {
            var pointer = value;
            opengl.glUniform4fv(location, 1, &pointer);
        }
    }

    pub fn set_vec2(self: Shader, opengl: *OpenGL, uniform_name: [*c]const u8, value: [2]f32) void {
        const location = self.get_location(opengl, uniform_name);
        if (location != -1) {
            var pointer = value;
            opengl.glUniform2fv(location, 1, &pointer);
        }
    }

    pub fn set_mat4(self: Shader, opengl: *OpenGL, uniform_name: [*c]const u8, value: Matrix4) void {
        const location = self.get_location(opengl, uniform_name);
        if (location != -1) {
            var data = value.columns;
            opengl.glUniformMatrix4fv(location, 1, c.GL_FALSE, @alignCast(4, &data[0][0]));
        }
    }

    pub fn set_texture(self: Shader, opengl: *OpenGL, uniform_name: [*c]const u8, tex_slot: u16, tex_id: c_uint) void {
        const location = self.get_location(opengl, uniform_name);
        if (location != -1) {
            if (tex_slot < self.num_textures) {
                opengl.glUniform1i(location, tex_slot);
                opengl.glActiveTexture(c.GL_TEXTURE0 + tex_slot);
                opengl.glBindTexture(c.GL_TEXTURE_2D, tex_id);
            }
        }
    }

    fn get_location(self: Shader, opengl: *OpenGL, uniform_name: [*c]const u8) c.GLint {
        const uniform = opengl.glGetUniformLocation(self.prog_id, uniform_name);
        if (uniform == -1) {
            console.debug("{s} uniform location could not be found!\n", .{uniform_name});
        }
        return uniform;
    }
};
