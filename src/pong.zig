const std = @import("std");
const Renderer = @import("opengl_renderer.zig").Renderer;
const RenderGroup = @import("render_group.zig").RenderGroup;

pub const Pong = struct {
    render_groups: std.ArrayList(RenderGroup),
    debug_render_groups: std.ArrayList(RenderGroup),
    allocator: *std.mem.Allocator,
    renderer: *Renderer,

    pub fn new(allocator: *std.mem.Allocator, renderer: *Renderer) Pong {
        return Pong{
            .allocator = allocator,
            .renderer = renderer,
            .render_groups = std.ArrayList(RenderGroup).init(allocator),
            .debug_render_groups = std.ArrayList(RenderGroup).init(allocator),
        };
    }

    pub fn deinit(self: *Pong) void {
        self.render_groups.deinit();
        self.debug_render_groups.deinit();
    }

    pub fn prepare_render(self: *Pong, dt: f64) void {
        for (self.render_groups.items) |render_group| {
            self.renderer.push_render_group(render_group);
        }
        for (self.debug_render_groups.items) |render_group| {
            self.renderer.push_render_group(render_group);
        }
    }
};
