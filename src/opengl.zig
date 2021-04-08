const std = @import("std");
const c = @import("c.zig");
const console = @import("console.zig");

pub const OpenGL = struct {
    // Info about device
    max_texture_size: c_int,

    // OpenGL functions
    glGetError: fn () c.GLenum,
    glEnable: fn (c.GLenum) void,
    glDisable: fn (c.GLenum) void,
    glGetString: fn (c.GLenum) [*c]u8,
    glGenVertexArrays: fn (c.GLsizei, [*c]c_uint) void,
    glGenBuffers: fn (c.GLsizei, [*c]c_uint) void,
    glBindVertexArray: fn (c.GLuint) void,
    glBindBuffer: fn (c.GLenum, c.GLuint) void,
    glBufferData: fn (c.GLenum, c.GLsizeiptr, ?*const c_void, c.GLenum) void,
    glBufferSubData: fn (c.GLenum, c.GLintptr, c.GLsizeiptr, ?*const c_void) void,
    glMapBuffer: fn (c.GLenum, c.GLenum) ?*c_void,
    glUnmapBuffer: fn (c.GLenum) c.GLboolean,
    glVertexAttribPointer: fn (c.GLuint, c.GLint, c.GLenum, c.GLboolean, c.GLsizei, ?*const c_void) void,
    glEnableVertexAttribArray: fn (c.GLuint) void,
    glCreateShader: fn (c.GLenum) c.GLuint,
    glShaderSource: fn (c.GLuint, c.GLsizei, *const [*c]const u8, [*c]c.GLint) void,
    glCompileShader: fn (c.GLuint) void,
    glGetShaderiv: fn (c.GLuint, c.GLenum, *c_int) void,
    glGetShaderInfoLog: fn (c.GLuint, c.GLsizei, ?*c.GLsizei, [*]u8) void,
    glCreateProgram: fn () c.GLuint,
    glAttachShader: fn (c.GLuint, c.GLuint) void,
    glLinkProgram: fn (c.GLuint) void,
    glValidateProgram: fn (c.GLuint) void,
    glGetProgramiv: fn (c.GLuint, c.GLenum, *c_int) void,
    glGetProgramInfoLog: fn (c.GLuint, c.GLsizei, ?*c.GLsizei, [*]u8) void,
    glDeleteShader: fn (c.GLuint) void,
    glDrawElements: fn (c.GLenum, c.GLsizei, c.GLenum, ?*const c_void) void,
    glUseProgram: fn (c.GLuint) void,
    glUniform1i: fn (c.GLint, c.GLint) void,
    glUniform1f: fn (c.GLint, c.GLfloat) void,
    glUniform2fv: fn (c.GLint, c.GLsizei, [*c]c.GLfloat) void,
    glUniform4fv: fn (c.GLint, c.GLsizei, [*c]c.GLfloat) void,
    glUniformMatrix3fv: fn (c.GLint, c.GLsizei, c.GLboolean, [*c]c.GLfloat) void,
    glUniformMatrix4fv: fn (c.GLint, c.GLsizei, c.GLboolean, [*c]c.GLfloat) void,
    glGetUniformLocation: fn (c.GLuint, [*c]const u8) c.GLint,
    glActiveTexture: fn (c.GLenum) void,
    glGenTextures: fn (c.GLsizei, [*c]c.GLuint) void,
    glBindTexture: fn (c.GLenum, c.GLuint) void,
    glGetIntegerv: fn (c.GLenum, [*c]c.GLint) void,
    glBlendFunc: fn (c.GLenum, c.GLenum) void,
    glTexImage2D: fn (c.GLenum, c.GLint, c.GLint, c.GLsizei, c.GLsizei, c.GLint, c.GLenum, c.GLenum, *const c.GLvoid) void,
    glTexParameteri: fn (c.GLenum, c.GLenum, c.GLint) void,
    glClearColor: fn (c.GLclampf, c.GLclampf, c.GLclampf, c.GLclampf) void,
    glClear: fn (c.GLbitfield) void,
    glFlush: fn () void,
    glDepthFunc: fn (c.GLenum) void,
    glGenerateMipmap: fn (c.GLenum) void,
    glViewport: fn (c.GLint, c.GLint, c.GLsizei, c.GLsizei) void,
    glBindAttribLocation: fn (c.GLuint, c.GLuint, [*c]const u8) void,

    // OpenGL 4.3
    glPushDebugGroup: fn (c.GLenum, c.GLuint, c.GLsizei, [*c]const u8) void,
    glPopDebugGroup: fn () void,

    pub fn init(self: *OpenGL) void {
        self.glGetIntegerv(c.GL_MAX_TEXTURE_SIZE, &self.max_texture_size);
    }

    pub fn print_info(self: *OpenGL) void {
        const gl_version = self.glGetString(c.GL_VERSION);
        self.check_gl_error("after glGetString");
        if (@ptrToInt(gl_version) != 0) {
            console.debug("OpenGL version supported by this platform: {s}\n", .{gl_version});
        }
        console.debug("Max texture size is: {}\n", .{self.max_texture_size});
    }

    pub fn check_gl_error(self: *OpenGL, info: []const u8) void {
        var loop_limit: u32 = 10;

        while (loop_limit > 0) {
            const gl_error = self.glGetError();
            switch (gl_error) {
                c.GL_NO_ERROR => {
                    // console.debug("[{}] No error\n", .{info});
                },
                c.GL_INVALID_ENUM => {
                    console.debug("[{}] GL Error! GL_INVALID_ENUM\n", .{info});
                },
                c.GL_INVALID_VALUE => {
                    console.debug("[{}] GL Error! GL_INVALID_VALUE\n", .{info});
                },
                c.GL_INVALID_OPERATION => {
                    console.debug("[{}] GL Error! GL_INVALID_OPERATION\n", .{info});
                },
                // c.GL_INVALID_FRAMEBUFFER_OPERATION => {
                //     console.debug("[{}] GL Error! GL_INVALID_FRAMEBUFFER_OPERATION\n", .{info});
                // },
                c.GL_OUT_OF_MEMORY => {
                    console.debug("[{}] GL Error! GL_OUT_OF_MEMORY\n", .{info});
                },
                //c.GL_STACK_UNDERFLOW => {
                //    console.debug("[{}] GL Error! GL_STACK_UNDERFLOW\n", .{info});
                //},
                //c.GL_STACK_OVERFLOW => {
                //    console.debug("[{}] GL Error! GL_STACK_OVERFLOW\n", .{info});
                //},
                else => {
                    console.debug("[{}] GL Error! Unknown error code {}\n", .{ info, gl_error });
                },
            }
            loop_limit -= 1;
        }
    }
};
