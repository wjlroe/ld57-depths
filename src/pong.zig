const std = @import("std");
const Renderer = @import("opengl_renderer.zig").Renderer;
const RenderGroup = @import("render_group.zig").RenderGroup;
const maths = @import("maths.zig");
const Vec2 = maths.Vec2;
const Rect = @import("rect.zig").Rect;
const colours = @import("colours.zig");
const console = @import("console.zig");

pub const Pong = struct {
    ball_location: Vec2(f32), // x,y as percent within viewport
    render_groups: std.ArrayList(RenderGroup),
    debug_render_groups: std.ArrayList(RenderGroup),
    allocator: *std.mem.Allocator,
    renderer: *Renderer,

    pub fn new(allocator: *std.mem.Allocator, renderer: *Renderer) Pong {
        return Pong{
            .ball_location = Vec2(f32).new_point(50.0, 50.0), // middle of the 'window'
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
        console.debug("pong rendering!\n", .{});
        var circle_rect = Rect.new([_]f32{self.ball_location.xy.x * self.renderer.viewport_rect.bounds[0], self.ball_location.xy.y * self.renderer.viewport_rect.bounds[1]}, [_]f32{100.0, 100.0});
        self.renderer.push_render_group(
            self.renderer.circle_as_render_group("circle", circle_rect, colours.BLUE, 0.99)
        );
    }
};
