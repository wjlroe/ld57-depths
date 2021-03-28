const std = @import("std");
const c = @import("c.zig");
const console = @import("console.zig");
usingnamespace @import("opengl.zig");

// y-coord flipped due to stb textures being upside-down
// TODO: flip them via a reflection matrix instead?
const quad_vertices = [_]f32{
    -1.0, 1.0,  0.0, 0.0, // 0: top-left
    -1.0, -1.0, 0.0, 1.0, // 1: bottom-left
    1.0,  -1.0, 1.0, 1.0, // 2: bottom-right
    1.0,  1.0,  1.0, 0.0, // 3: top-right
};

const quad_pos_len: c_uint = 2;
const quad_tex_len: c_uint = 2;
const quad_stride: c_uint = quad_pos_len + quad_tex_len;

const quad_indices = [_]c_uint{
    0, 1, 2, 2, 3, 0,
};

pub const GLQuad = struct {
    vertices: [16]f32,
    indices: [6]c_uint,
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,
    num: c_int,

    pub fn new(allocator: *std.mem.Allocator, opengl: *OpenGL) !GLQuad {
        const pos_loc = 0;
        const tex_loc = 1;
        var gl_quad: GLQuad = undefined;
        gl_quad.num = quad_indices.len;
        std.mem.copy(f32, &gl_quad.vertices, quad_vertices[0..]);
        std.mem.copy(c_uint, &gl_quad.indices, quad_indices[0..]);

        opengl.glGenVertexArrays(1, &gl_quad.vao);

        opengl.glGenBuffers(1, &gl_quad.vbo);

        opengl.glBindVertexArray(gl_quad.vao);

        opengl.glBindBuffer(c.GL_ARRAY_BUFFER, gl_quad.vbo);
        opengl.glBufferData(c.GL_ARRAY_BUFFER, quad_stride * quad_vertices.len * @sizeOf(@TypeOf(gl_quad.vertices[0])), &gl_quad.vertices, c.GL_STATIC_DRAW);

        opengl.glGenBuffers(1, &gl_quad.ebo);
        opengl.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, gl_quad.ebo);
        opengl.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, quad_indices.len * @sizeOf(@TypeOf(gl_quad.indices[0])), &gl_quad.indices, c.GL_STATIC_DRAW);

        opengl.glVertexAttribPointer(pos_loc, quad_pos_len, c.GL_FLOAT, c.GL_FALSE, quad_stride * @sizeOf(@TypeOf(gl_quad.vertices[0])), @intToPtr(?*const c_void, 0));
        opengl.glEnableVertexAttribArray(pos_loc);
        opengl.glVertexAttribPointer(tex_loc, quad_tex_len, c.GL_FLOAT, c.GL_FALSE, quad_stride * @sizeOf(@TypeOf(gl_quad.vertices[0])), @intToPtr(?*const c_void, (quad_pos_len * @sizeOf(@TypeOf(gl_quad.vertices[0])))));
        opengl.glEnableVertexAttribArray(tex_loc);

        opengl.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
        opengl.glBindVertexArray(0);

        return gl_quad;
    }

    pub fn reset_quad_data(self: *GLQuad, opengl: *OpenGL, s0: f32, t0: f32, s1: f32, t1: f32) void {
        opengl.glBindVertexArray(self.vao);

        // 0: top-left
        self.vertices[2] = s0;
        self.vertices[3] = t0;
        // 1: bottom-left
        self.vertices[6] = s0;
        self.vertices[7] = t1;
        // 2: bottom-right
        self.vertices[10] = s1;
        self.vertices[11] = t1;
        // 3: top-right
        self.vertices[14] = s1;
        self.vertices[15] = t0;

        opengl.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        opengl.check_gl_error("after glBindBuffer");
        //opengl.glBufferData(c.GL_ARRAY_BUFFER, quad_stride * quad_vertices.len * @sizeOf(@TypeOf(self.vertices[0])), &self.vertices, c.GL_STATIC_DRAW);
        opengl.glBufferData(c.GL_ARRAY_BUFFER, quad_stride * quad_vertices.len * @sizeOf(@TypeOf(self.vertices[0])), null, c.GL_STATIC_DRAW);

        var buffer_data = @ptrCast([*]f32, @alignCast(8, opengl.glMapBuffer(c.GL_ARRAY_BUFFER, c.GL_READ_WRITE).?));
        opengl.check_gl_error("after glMapBuffer");
        //std.mem.copy(u8, buffer_data, self.vertices[0..self.vertices.len]);
        buffer_data[2] = s0;
        buffer_data[3] = t0;
        // 1: bottom-left
        buffer_data[6] = s0;
        buffer_data[7] = t1;
        // 2: bottom-right
        buffer_data[10] = s1;
        buffer_data[11] = t1;
        // 3: top-right
        buffer_data[14] = s1;
        buffer_data[15] = t0;

        if (opengl.glUnmapBuffer(c.GL_ARRAY_BUFFER) != c.GL_TRUE) {
            console.debug("glUnmapBuffer failed!\n", .{});
        }
        opengl.check_gl_error("after glUnmapBuffer");
        //if (@ptrToInt(buffer_data) != 0) {
        //}
        //opengl.glBufferSubData(c.GL_ARRAY_BUFFER, 0, quad_stride * quad_vertices.len * @sizeOf(@TypeOf(self.vertices[0])), &self.vertices);
        //opengl.check_gl_error("after glBufferData");
    }

    pub fn draw(self: *GLQuad, opengl: *OpenGL, shader_program: c_uint) void {
        opengl.glBindVertexArray(self.vao);

        var prog_success: c_int = undefined;
        opengl.glValidateProgram(shader_program);
        opengl.glGetProgramiv(shader_program, c.GL_VALIDATE_STATUS, &prog_success);
        if (prog_success != c.GL_TRUE) {
            var infolen: usize = 0;
            var infolog: [1024]u8 = undefined;
            opengl.glGetProgramInfoLog(shader_program, 1024, @ptrCast(*c_int, &infolen), &infolog);
            const program_error = infolog[0..infolen];
            console.debug("Error from OpenGL:\n{}\n", .{program_error});
        }

        opengl.glDrawElements(c.GL_TRIANGLES, self.num, c.GL_UNSIGNED_INT, @intToPtr(?*const c_void, 0));
        opengl.check_gl_error("after glDrawElements");
    }
};
