const std = @import("std");
const command = @import("command.zig");
const Renderer = @import("opengl_renderer.zig").Renderer;
const TextLabel = @import("text_label.zig").TextLabel;
const console = @import("console.zig");
const colours = @import("colours.zig");

pub const Game = struct {
    running: bool = true,
    renderer: *Renderer,
    allocator: *std.mem.Allocator,
    text_label: TextLabel,

    pub fn new(allocator: *std.mem.Allocator, renderer: *Renderer) !*Game {
        var game = try allocator.create(Game);
        var text_label = try TextLabel.new("Pong", renderer, allocator);
        game.renderer = renderer;
        game.allocator = allocator;
        game.text_label = text_label;
        return game;
    }

    pub fn prepare_render(self: *Game, dt: f64) void {
        {
            self.renderer.push_render_group(self.renderer.horizontal_line_as_render_group("middleY", self.renderer.viewport_rect.center[1], colours.RED, 0.9));
            self.renderer.push_render_group(self.renderer.vertical_line_as_render_group("middleX", self.renderer.viewport_rect.center[0], colours.RED, 0.9));
        }
        for (self.text_label.render_groups.items) |render_group| {
            self.renderer.push_render_group(render_group);
        }
    }

    pub fn process_command(self: *Game, cmd: command.Command) void {
        switch (cmd) {
            command.CommandTag.Quit => {
                self.running = false;
            },
            else => {},
        }
    }
};
