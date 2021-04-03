const std = @import("std");
const command = @import("command.zig");
const Renderer = @import("opengl_renderer.zig").Renderer;
const TextLabel = @import("text_label.zig").TextLabel;
const console = @import("console.zig");
const colours = @import("colours.zig");
const Rect = @import("rect.zig").Rect;
const layout = @import("layout.zig");

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
        try game.update_layout();
        return game;
    }

    fn update_layout(self: *Game) !void {
        var bounding_boxes = &[_]*Rect{
            &self.text_labels[0].bounding_box,
            &self.text_labels[1].bounding_box,
            &self.text_labels[2].bounding_box,
        };
        layout.layout_vertically(bounding_boxes, 2.0);
        layout.center_vertically(bounding_boxes, self.renderer.viewport_rect);
        layout.center_horizontally(bounding_boxes, self.renderer.viewport_rect);
        for (self.text_labels) |*label| {
            try label.update_render_groups(self.allocator, self.renderer);
        }
    }

    pub fn prepare_render(self: *Game, dt: f64) void {
        if (self.debug_render) {
            self.renderer.push_render_group(self.renderer.horizontal_line_as_render_group("middleY", self.renderer.viewport_rect.center[1], colours.RED, 0.9));
            self.renderer.push_render_group(self.renderer.vertical_line_as_render_group("middleX", self.renderer.viewport_rect.center[0], colours.RED, 0.9));
        }
        for (self.text_labels) |*label| {
            std.debug.assert((label.contents[0] >= 32) and (label.contents[0] <= 126));
            if (self.debug_render) {
                for (self.renderer.outline_as_render_group("textLabelOutline", label.bounding_box, colours.BLUE, 0.8, 1.0)) |group| {
                    self.renderer.push_render_group(group);
                }
            }
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
