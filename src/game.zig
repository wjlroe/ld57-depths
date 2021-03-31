const std = @import("std");
const command = @import("command.zig");
const Renderer = @import("opengl_renderer.zig").Renderer;
const TextLabel = @import("text_label.zig").TextLabel;
const console = @import("console.zig");
const colours = @import("colours.zig");

const GAME_TITLE: []const u8 = "Pong";

pub const Game = struct {
    running: bool = true,
    renderer: *Renderer,
    allocator: *std.mem.Allocator,
    text_labels: []TextLabel,

    pub fn new(allocator: *std.mem.Allocator, renderer: *Renderer) !*Game {
        var game = try allocator.create(Game);
        var text_label = try TextLabel.new(GAME_TITLE, renderer, allocator);
        game.renderer = renderer;
        game.allocator = allocator;
        game.text_labels = &[_]TextLabel{
            text_label,
        };
        return game;
    }

    pub fn check_labels(self: *const Game, message: []const u8) void {
        console.debug("[{}] Gonna check labels are valid\n", .{message});
        std.debug.assert(std.mem.eql(u8, GAME_TITLE, "Pong"));
        var i: u32 = 0;
        for (self.text_labels) |*label| {
            // console.debug("[{}/{}] text_label: {x}\n", .{ message, i, label.contents[0] });
            // console.debug("[{}/{}] contents: '{}', ({x}, {x}), len: ({}, {})\n", .{ message, i, label.contents[0..4], label.contents[0..4], "Pong", label.contents.len, "Pong".len });
            // console.debug("[{}/{}] null: {}\n", .{ message, i, label.contents[4] });
            // std.debug.assert(std.mem.eql(u8, label.contents, "Pong"));
            // console.debug("[Game.check_labels/{}] contents.ptr: {}, self.contents_ptr: {}\n", .{ message, @ptrToInt(label.contents.ptr), label.contents_ptr });
            label.check_contents(message);
            // console.debug("[Game.check_labels/{}] contents.ptr: {}, self.contents_ptr: {}\n", .{ message, @ptrToInt(label.contents.ptr), label.contents_ptr });
            // std.debug.assert((label.contents[0] >= 32) and (label.contents[0] <= 126));
            i += 1;
        }
        for (self.text_labels) |*label| {
            label.check_contents(message);
        }
        std.debug.assert(std.mem.eql(u8, GAME_TITLE, "Pong"));
    }

    pub fn prepare_render(self: *Game, dt: f64) void {
        {
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
            else => {},
        }
    }
};
