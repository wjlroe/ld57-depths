const c = @import("c.zig");
const std = @import("std");
const testing = std.testing;
const console = @import("console.zig");
const colours = @import("colours.zig");
usingnamespace @import("opengl.zig");
usingnamespace @import("shader_source.zig");
usingnamespace @import("gl_quad.zig");
usingnamespace @import("fonts.zig");
usingnamespace @import("rect.zig");
usingnamespace @import("shader.zig");
usingnamespace @import("maths.zig");
const RenderGroup = @import("render_group.zig").RenderGroup;
const RenderElement = @import("render_group.zig").RenderElement;
const RenderElementType = @import("render_group.zig").RenderElementType;
const resources = @import("resources.zig");

const ShaderError = error{
    CompilationFailed,
    LinkFailed,
    ProgramValidationFailed,
};

const quad_vertex_shader_source = ShaderSource.init("./shaders/quad_vert.glsl");
const quad_fragment_shader_source = ShaderSource.init("./shaders/quad_frag.glsl");
const circle_fragment_shader_source = ShaderSource.init("./shaders/circle_frag.glsl");

fn parse_errors(allocator: *std.mem.Allocator, compile_error: []const u8) anyerror![]CompileError {
    const ErrorState = enum {
        BeforeLineNum,
        LineNum,
        ColNum,
        Message,
    };
    var errors = std.ArrayList(CompileError).init(allocator);
    var current_error: CompileError = CompileError{};
    var buf = std.ArrayList(u8).init(allocator);
    var error_state = ErrorState.BeforeLineNum;

    for (compile_error) |compile_c| {
        switch (error_state) {
            .BeforeLineNum => if ((compile_c == ':') or (compile_c == '(')) {
                error_state = ErrorState.LineNum;
            },
            .LineNum => if ((compile_c == '(') or (compile_c == ')')) {
                current_error.line = try std.fmt.parseInt(usize, buf.items, 10);
                try buf.resize(0);
                if (compile_c == '(') {
                    error_state = ErrorState.ColNum;
                } else {
                    error_state = ErrorState.Message;
                }
            } else {
                try buf.append(compile_c);
            },
            .ColNum => if (compile_c == ')') {
                current_error.column = try std.fmt.parseInt(usize, buf.items, 10);
                try buf.resize(0);
                error_state = ErrorState.Message;
            } else {
                try buf.append(compile_c);
            },
            .Message => if ((compile_c == '\n') or (compile_c == 0)) {
                const message = std.mem.trimLeft(u8, buf.items, ": ");
                current_error.message = try std.mem.dupe(allocator, u8, message);
                try errors.append(current_error);
                try buf.resize(0);
                error_state = ErrorState.BeforeLineNum;
            } else {
                try buf.append(compile_c);
            },
        }
    }

    if ((error_state == .Message) and (buf.items.len > 0)) {
        const message = std.mem.trimLeft(u8, buf.items, ": ");
        current_error.message = try std.mem.dupe(allocator, u8, message);
        try errors.append(current_error);
    }

    return errors.items;
}

test "parse_errors from Linux" {
    const compile_error =
        \\0:4(1): error: syntax error, unexpected NEW_IDENTIFIER, expecting $end
        \\0:5(14): error: syntax error, unexpected NEW_IDENTIFIER, expecting '{'
    ;
    const errors = try parse_errors(std.heap.c_allocator, compile_error);
    testing.expectEqual(@as(usize, 2), errors.len);

    testing.expectEqual(@as(usize, 4), errors[0].line);
    testing.expectEqual(@as(usize, 1), errors[0].column);
    const expected_message = "error: syntax error, unexpected NEW_IDENTIFIER, expecting $end";
    testing.expectEqual(expected_message.len, errors[0].message.len);
    testing.expectEqualSlices(u8, expected_message, errors[0].message);

    testing.expectEqual(@as(usize, 5), errors[1].line);
    testing.expectEqual(@as(usize, 14), errors[1].column);
    testing.expectEqualSlices(u8, "error: syntax error, unexpected NEW_IDENTIFIER, expecting '{'", errors[1].message);
}

test "parse_errors from Windows" {
    const compile_error =
        \\0(4) : error C0000: syntax error, unexpected identifier, expecting '{' at token "alpha"
        \\0(13) : error C1503: undefined variable "alpha"
    ;
    const errors = try parse_errors(std.heap.c_allocator, compile_error);
    testing.expectEqual(@as(usize, 2), errors.len);

    testing.expectEqual(@as(usize, 4), errors[0].line);
    testing.expectEqual(@as(usize, 0), errors[0].column);
    testing.expectEqualSlices(u8, "error C0000: syntax error, unexpected identifier, expecting '{' at token \"alpha\"", errors[0].message);

    testing.expectEqual(@as(usize, 13), errors[1].line);
    testing.expectEqual(@as(usize, 0), errors[1].column);
    testing.expectEqualSlices(u8, "error C1503: undefined variable \"alpha\"", errors[1].message);
}

fn compile_shader(allocator: *std.mem.Allocator, opengl: *OpenGL, shader_type: c_uint, shader_source: *const ShaderSource) anyerror!c_uint {
    var shader_id: c_uint = undefined;
    var compile_success: c_int = undefined;
    var infolen: usize = 0;
    var infolog: [1024]u8 = undefined;
    const shader_cstr = try shader_source.c_str(allocator);
    defer allocator.free(shader_cstr);

    shader_id = opengl.glCreateShader(shader_type);
    opengl.glShaderSource(shader_id, 1, &shader_cstr.ptr, null);
    opengl.glCompileShader(shader_id);
    opengl.glGetShaderiv(shader_id, c.GL_COMPILE_STATUS, &compile_success);
    if (compile_success != c.GL_TRUE) {
        opengl.glGetShaderInfoLog(shader_id, 1024, @ptrCast(*c_int, &infolen), &infolog);
        const compile_error = infolog[0..infolen];
        console.debug("Error from OpenGL:\n{}\n", .{compile_error});
        const errors = try parse_errors(allocator, compile_error);
        console.debug("num of errors: {}\n", .{errors.len});
        const shader_src = try shader_source.print_source(allocator, errors);
        console.debug("!! Failed compile of shader {}:\n===\n{}", .{ shader_source.filename, shader_src });
        allocator.free(shader_src);
        return ShaderError.CompilationFailed;
    }

    return shader_id;
}

fn compile_shaders(allocator: *std.mem.Allocator, opengl: *OpenGL, vertex_shader: *const ShaderSource, fragment_shader: *const ShaderSource) !c_uint {
    const vert_id = try compile_shader(allocator, opengl, c.GL_VERTEX_SHADER, vertex_shader);
    const frag_id = try compile_shader(allocator, opengl, c.GL_FRAGMENT_SHADER, fragment_shader);

    const prog_id = opengl.glCreateProgram();
    opengl.glAttachShader(prog_id, vert_id);
    opengl.glAttachShader(prog_id, frag_id);
    // TODO: this is very specific to the names of attribs in the quad shaders, how else can we do this?
    opengl.glBindAttribLocation(prog_id, 0, "a_Pos");
    opengl.glBindAttribLocation(prog_id, 1, "a_Tex");
    opengl.glLinkProgram(prog_id);

    var prog_success: c_int = undefined;
    var infolen: usize = 0;
    var infolog: [1024]u8 = undefined;
    opengl.glGetProgramiv(prog_id, c.GL_LINK_STATUS, &prog_success);
    if (prog_success != c.GL_TRUE) {
        opengl.glGetProgramInfoLog(prog_id, 1024, @ptrCast(*c_int, &infolen), &infolog);
        const program_error = infolog[0..infolen];
        console.debug("Error from OpenGL:\n{}\n", .{program_error});
        return ShaderError.LinkFailed;
    }

    opengl.glDeleteShader(vert_id);
    opengl.glDeleteShader(frag_id);
    return prog_id;
}

pub const Renderer = struct {
    opengl: *OpenGL,
    title_font: Font,
    menu_item_font: Font,
    gl_quad: GLQuad,
    quad_shader: Shader,
    circle_shader: Shader,
    viewport: [4]c_int,
    viewport_rect: Rect,
    first_frame: bool,
    debug_render: bool,
    render_groups: std.ArrayList(RenderGroup),
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator, opengl: *OpenGL) !Renderer {
        c.stbi_set_flip_vertically_on_load(1);

        opengl.glEnable(c.GL_BLEND);
        opengl.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
        opengl.glEnable(c.GL_DEPTH_TEST);
        opengl.glEnable(c.GL_CULL_FACE);

        const quad_program = try compile_shaders(allocator, opengl, &quad_vertex_shader_source, &quad_fragment_shader_source);
        const circle_program = try compile_shaders(allocator, opengl, &quad_vertex_shader_source, &circle_fragment_shader_source);

        // var viewport_data = [4]c_int{ 0, 0, 0, 0 };
        // opengl.glGetIntegerv(c.GL_VIEWPORT, &viewport_data[0]);
        // console.debug("Viewport. width={}, height={}\n", .{ viewport_data[2], viewport_data[3] });

        var title_font = try Font.new_neuton(allocator, opengl, 200.0, 0);
        var menu_item_font = try Font.new_neuton(allocator, opengl, 100.0, 0);

        var gl_quad = try GLQuad.new(allocator, opengl);
        var renderer = Renderer{
            .opengl = opengl,
            .title_font = title_font,
            .menu_item_font = menu_item_font,
            .gl_quad = gl_quad,
            .quad_shader = Shader.new(quad_program, 1),
            .circle_shader = Shader.new(circle_program, 0),
            .viewport = [_]c_int{ 0, 0, 0, 0 },
            .viewport_rect = undefined,
            .first_frame = true,
            .debug_render = false,
            .render_groups = std.ArrayList(RenderGroup).init(allocator),
            .allocator = allocator,
        };

        return renderer;
    }

    pub fn deinit(self: *Renderer) void {
        self.title_font.deinit();
        self.menu_item_font.deinit();
        self.render_groups.deinit();
    }

    pub fn bind_image(self: *Renderer, resource: resources.Resource, repeat: bool) ?c_uint {
        var tex_name: c_uint = undefined;
        var width: c_int = undefined;
        var height: c_int = undefined;
        var num_channels: c_int = undefined;
        const data_length = @intCast(c_int, resource.length);
        const loaded_image_data = c.stbi_load_from_memory(resource.data, data_length, &width, &height, &num_channels, 0);
        if (loaded_image_data != 0) {
            defer c.stbi_image_free(loaded_image_data);
            self.opengl.glGenTextures(1, &tex_name);
            var format: u16 = c.GL_RGB;
            switch (num_channels) {
                1 => {
                    format = c.GL_RED;
                },
                3 => {
                    format = c.GL_RGB;
                },
                4 => {
                    format = c.GL_RGBA;
                },
                else => {},
            }
            self.opengl.glBindTexture(c.GL_TEXTURE_2D, tex_name);
            self.opengl.glTexImage2D(c.GL_TEXTURE_2D, 0, format, width, height, 0, format, c.GL_UNSIGNED_BYTE, loaded_image_data);
            self.opengl.glGenerateMipmap(c.GL_TEXTURE_2D);
            const repeat_mode: c_int = if (repeat) c.GL_REPEAT else c.GL_CLAMP_TO_EDGE;

            if (num_channels == 4) {
                self.opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, repeat_mode);
                self.opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, repeat_mode);
            } else {
                self.opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
                self.opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
            }
            if (!repeat) {
                self.opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST_MIPMAP_NEAREST);
                self.opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
            } else {
                self.opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
                self.opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
            }
            return tex_name;
        } else {
            console.debug("Failed to load texture data: {}\n", .{resource.file_name});
            return null;
        }
    }

    pub fn set_viewport(self: *Renderer, viewport: [4]c_int) void {
        if (!std.mem.eql(c_int, &viewport, &self.viewport)) {
            self.viewport = viewport;
            self.viewport_rect = Rect.from_top_left_bottom_right(0.0, 0.0, @intToFloat(f32, viewport[2]), @intToFloat(f32, viewport[3]));
            console.debug("viewport changed. viewport: ", .{});
            self.viewport_rect.print(self.allocator) catch unreachable;
            console.debug("\n", .{});
            self.opengl.glViewport(self.viewport[0], self.viewport[1], self.viewport[2], self.viewport[3]);
        }
    }

    pub fn render(self: *Renderer) !void {
        const b = colours.BLACK.rgba;
        self.opengl.glClearColor(b.r, b.g, b.b, b.a);
        self.opengl.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        self.render_render_groups();

        self.opengl.glFlush();

        self.first_frame = false;
    }

    pub fn push_render_group(self: *Renderer, group: RenderGroup) void {
        self.render_groups.append(group) catch unreachable;
    }

    fn render_render_groups(self: *Renderer) void {
        const groups = self.render_groups.toOwnedSlice();
        for (groups) |*render_group| {
            render_group.render(self);
            // FIXME: we can't free these if they are cached elsewhere
            // render_group.deinit();
        }
    }

    pub fn horizontal_line_as_render_group(self: *Renderer, name: []const u8, y: f32, colour: colours.Colour, z: f32) RenderGroup {
        const pos = Rect.new([_]f32{ self.viewport_rect.center[0], y }, [_]f32{ self.viewport_rect.bounds[0], 1 });
        var group = self.rect_as_render_group(name, pos, colour, z);
        return group;
    }

    pub fn vertical_line_as_render_group(self: *Renderer, name: []const u8, x: f32, colour: colours.Colour, z: f32) RenderGroup {
        const pos = Rect.new([_]f32{ x, self.viewport_rect.center[1] }, [_]f32{ 1, self.viewport_rect.bounds[1] });
        var group = self.rect_as_render_group(name, pos, colour, z);
        return group;
    }

    pub fn crosshair_as_render_group(self: *Renderer, name: []const u8, x: f32, y: f32, width: f32, colour: colours.Colour, z: f32) [2]RenderGroup {
        var hori = self.rect_as_render_group(name, Rect.new([_]f32{x, y}, [_]f32{ width, 1.0}), colour, z);
        hori.depth_testing = false;
        var vert = self.rect_as_render_group(name, Rect.new([_]f32{x, y}, [_]f32{ 1.0, width}), colour, z);
        vert.depth_testing = false;
        return [_]RenderGroup{hori, vert};
    }

    pub fn outline_as_render_group(self: *Renderer, name: []const u8, position: Rect, colour: colours.Colour, z: f32, thickness: f32) [2]RenderGroup {
        // TODO: group both quad renders into the one "group", so they are grouped via push debug group etc.
        var smaller_rect = position;
        smaller_rect.bounds[0] -= thickness * 2.0;
        smaller_rect.bounds[1] -= thickness * 2.0;
        return [_]RenderGroup{
            self.rect_as_render_group(name, smaller_rect, colours.TRANSPARENT, z - 0.001),
            self.rect_as_render_group(name, position, colour, z),
        };
    }

    pub fn rect_as_render_group(self: *Renderer, name: []const u8, position: Rect, colour: colours.Colour, z: f32) RenderGroup {
        var group = RenderGroup.new_quad(self.allocator, &self.quad_shader, &self.gl_quad, name);
        var transform_matrix: Matrix4 = position.transform_within(self.viewport_rect);
        group.set_vec4("color", colour);
        group.set_float("u_Z", z);
        group.set_float("gap_height", 0.0);
        group.set_mat4("pos_transform", transform_matrix);
        group.set_mat4("tex_transform", Matrix4.identity());
        group.set_int("sample_texture", 0);
        return group;
    }

    pub fn texture_as_render_group(self: *Renderer, name: []const u8, position: Rect, z: f32, tex_transform: Matrix4, tex_id: c_uint) RenderGroup {
        var group = RenderGroup.new_quad(self.allocator, &self.quad_shader, &self.gl_quad, name);
        var transform_matrix: Matrix4 = position.transform_within(self.viewport_rect);
        group.set_float("u_Z", z);
        group.set_float("gap_height", 0.0);
        group.set_mat4("pos_transform", transform_matrix);
        group.set_mat4("tex_transform", tex_transform);
        group.set_int("sample_texture", 2);
        return group;
    }

    pub fn circle_as_render_group(self: *Renderer, name: []const u8, position: Rect, colour: colours.Colour, z: f32) RenderGroup {
        var group = RenderGroup.new_quad(self.allocator, &self.circle_shader, &self.gl_quad, name);
        var transform_matrix: Matrix4 = position.transform_within(self.viewport_rect);
        group.set_vec4("color", colour);
        group.set_float("u_Z", z);
        group.set_mat4("pos_transform", transform_matrix);
        const tex_scale = Matrix4.scale(2.0, 2.0, 1.0);
        const tex_translation = Matrix4.translation(-1.0, -1.0, 0.0);
        const tex_transform = tex_translation.mul(tex_scale);
        group.set_mat4("tex_transform", tex_transform);
        return group;
    }

    pub fn push_debug_group(self: *Renderer, message: []const u8) void {
        if (self.opengl.gl_4_3_funcs) |gl_43| {
            gl_43.glPushDebugGroup(c.GL_DEBUG_SOURCE_APPLICATION, 1, @intCast(c_int, message.len), message.ptr);
        }
    }

    pub fn pop_debug_group(self: *Renderer) void {
        if (self.opengl.gl_4_3_funcs) |gl_43| {
            gl_43.glPopDebugGroup();
        }
    }

    pub fn debug_on_first_frame(self: *Renderer, comptime fmt: []const u8, args: anytype) void {
        if (self.first_frame) {
            console.debug(fmt, args);
        }
    }
};
