const std = @import("std");
const command = @import("command.zig");
const Renderer = @import("opengl_renderer.zig").Renderer;
const TextLabel = @import("text_label.zig").TextLabel;
const console = @import("console.zig");
const colours = @import("colours.zig");

const GAME_TITLE: []const u8 = "Pong";
const START_GAME: []const u8 = "Start Game";
const QUIT_GAME: []const u8 = "Quit";

pub const Game = struct {
    running: bool = true,
    debug_render: bool = false,
    renderer: *Renderer,
    allocator: *std.mem.Allocator,
    text_labels: [3]TextLabel,

    pub fn new(allocator: *std.mem.Allocator, renderer: *Renderer) !*Game {
        var game = try allocator.create(Game);
        game.renderer = renderer;
        game.allocator = allocator;
        game.text_labels = [_]TextLabel{
            try TextLabel.new(GAME_TITLE, renderer, allocator),
            try TextLabel.new(START_GAME, renderer, allocator),
            try TextLabel.new(QUIT_GAME, renderer, allocator),
        };
        return game;
    }

    pub fn prepare_render(self: *Game, dt: f64) void {
        if (self.debug_render) {
            self.renderer.push_render_group(self.renderer.horizontal_line_as_render_group("middleY", self.renderer.viewport_rect.center[1], colours.RED, 0.9));
            self.renderer.push_render_group(self.renderer.vertical_line_as_render_group("middleX", self.renderer.viewport_rect.center[0], colours.RED, 0.9));
        }
        for (self.text_labels) |*label| {
            std.debug.assert((label.contents[0] >= 32) and (label.contents[0] <= 126));
            for (label.render_groups.items) |render_group| {
                self.renderer.push_render_group(render_group);
            }
        }
    }

    pub fn process_command(self: *Game, cmd: command.Command) void {
        switch (cmd) {
            command.CommandTag.Quit => {
                self.running = false;
            },
            command.CommandTag.ToggleDebug => {
                self.debug_render = !self.debug_render;
            },
        }
    }
};
