const std = @import("std");
const c = @import("c.zig");
const maths = @import("maths.zig");
usingnamespace @import("opengl.zig");
const GLQuad = @import("gl_quad.zig").GLQuad;
const Shader = @import("shader.zig").Shader;
const Renderer = @import("opengl_renderer.zig").Renderer;
const console = @import("console.zig");

const RenderElementType = enum {
    Quad,
};

const RenderElement = union(RenderElementType) {
    Quad: *GLQuad,
};

pub const TextureSlot = struct {
    slot: u16,
    texture_id: c_uint,
};

pub const RenderGroup = struct {
    name: []const u8,
    shader: *Shader,
    render_element: RenderElement,
    depth_testing: bool = true,
    inputs_vec4: std.AutoHashMap([*c]const u8, maths.Vec4(f32)),
    inputs_vec2: std.AutoHashMap([*c]const u8, maths.Vec2(f32)),
    inputs_mat4: std.AutoHashMap([*c]const u8, maths.Matrix4),
    inputs_int: std.AutoHashMap([*c]const u8, i32),
    inputs_float: std.AutoHashMap([*c]const u8, f32),
    inputs_texture: std.AutoHashMap([*c]const u8, TextureSlot),

    pub fn new_quad(allocator: *std.mem.Allocator, shader: *Shader, quad: *GLQuad, name: []const u8) RenderGroup {
        const group = RenderGroup{
            .name = name,
            .shader = shader,
            .render_element = RenderElement{ .Quad = quad },
            .inputs_vec4 = std.AutoHashMap([*c]const u8, maths.Vec4(f32)).init(allocator),
            .inputs_vec2 = std.AutoHashMap([*c]const u8, maths.Vec2(f32)).init(allocator),
            .inputs_mat4 = std.AutoHashMap([*c]const u8, maths.Matrix4).init(allocator),
            .inputs_int = std.AutoHashMap([*c]const u8, i32).init(allocator),
            .inputs_float = std.AutoHashMap([*c]const u8, f32).init(allocator),
            .inputs_texture = std.AutoHashMap([*c]const u8, TextureSlot).init(allocator),
        };
        return group;
    }

    pub fn deinit(self: *RenderGroup) void {
        self.inputs_vec4.deinit();
        self.inputs_vec2.deinit();
        self.inputs_mat4.deinit();
        self.inputs_int.deinit();
        self.inputs_float.deinit();
        self.inputs_texture.deinit();
    }

    pub fn set_mat4(self: *RenderGroup, name: [*c]const u8, value: maths.Matrix4) void {
        self.inputs_mat4.put(name, value) catch unreachable;
    }

    pub fn set_vec4(self: *RenderGroup, name: [*c]const u8, value: maths.Vec4(f32)) void {
        self.inputs_vec4.put(name, value) catch unreachable;
    }

    pub fn set_vec2(self: *RenderGroup, name: [*c]const u8, value: maths.Vec2(f32)) void {
        self.inputs_vec2.put(name, value) catch unreachable;
    }

    pub fn set_int(self: *RenderGroup, name: [*c]const u8, value: i32) void {
        self.inputs_int.put(name, value) catch unreachable;
    }

    pub fn set_float(self: *RenderGroup, name: [*c]const u8, value: f32) void {
        self.inputs_float.put(name, value) catch unreachable;
    }

    pub fn set_texture(self: *RenderGroup, name: [*c]const u8, texture_slot: TextureSlot) void {
        self.inputs_texture.put(name, texture_slot) catch unreachable;
    }

    pub fn render(self: *RenderGroup, renderer: *Renderer) void {
        renderer.push_debug_group(self.name);
        renderer.opengl.glUseProgram(self.shader.prog_id);

        if (self.depth_testing) {
            renderer.opengl.glEnable(c.GL_DEPTH_TEST);
        } else {
            renderer.opengl.glDisable(c.GL_DEPTH_TEST);
        }

        {
            var it = self.inputs_vec4.iterator();
            while (it.next()) |kv| {
                self.shader.set_vec4(renderer.opengl, kv.key, kv.value.array);
            }
        }
        {
            var it = self.inputs_vec2.iterator();
            while (it.next()) |kv| {
                self.shader.set_vec2(renderer.opengl, kv.key, kv.value.array);
            }
        }
        {
            var it = self.inputs_mat4.iterator();
            while (it.next()) |kv| {
                self.shader.set_mat4(renderer.opengl, kv.key, kv.value);
            }
        }
        {
            var it = self.inputs_int.iterator();
            while (it.next()) |kv| {
                self.shader.set_int(renderer.opengl, kv.key, kv.value);
            }
        }
        {
            var it = self.inputs_float.iterator();
            while (it.next()) |kv| {
                self.shader.set_float(renderer.opengl, kv.key, kv.value);
            }
        }
        {
            var it = self.inputs_texture.iterator();
            while (it.next()) |kv| {
                self.shader.set_texture(renderer.opengl, kv.key, kv.value.slot, kv.value.texture_id);
            }
        }

        switch (self.render_element) {
            RenderElementType.Quad => |gl_quad| {
                gl_quad.draw(renderer.opengl, self.shader.prog_id);
            },
        }
        renderer.pop_debug_group();
    }
};
