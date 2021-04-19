const std = @import("std");
const command = @import("command.zig");
const Renderer = @import("opengl_renderer.zig").Renderer;
const TextLabel = @import("text_label.zig").TextLabel;
const console = @import("console.zig");
const colours = @import("colours.zig");
const Rect = @import("rect.zig").Rect;
const layout = @import("layout.zig");
const maths = @import("maths.zig");
const Vec2 = maths.Vec2;
const menu_module = @import("menu.zig");
const ItemParams = menu_module.ItemParams;
const Menu = menu_module.Menu;
const mesh = @import("mesh.zig");
const sprite = @import("sprite.zig");

pub const Game = struct {
    running: bool,
    renderer: *Renderer,
    allocator: *std.mem.Allocator,
    mouse_position: Vec2(f32),
    floor_tiles_sprite: sprite.Sprite,

    pub fn new(allocator: *std.mem.Allocator, renderer: *Renderer) !*Game {
        mesh.load_mesh("assets/cube.obj");
        var game = try allocator.create(Game);
        game.running = true;
        game.mouse_position = Vec2(f32).new_point(0.0, 0.0);
        game.renderer = renderer;
        game.allocator = allocator;
        game.floor_tiles_sprite = try sprite.Sprite.new_floor_tiles(allocator);
        try game.update_layout();
        return game;
    }

    pub fn deinit(self: *Game) void {
        const allocator = self.allocator;
        allocator.destroy(self);
    }

    fn update_layout(self: *Game) !void {
    }

    pub fn update_mouse_position(self: *Game, xpos: f64, ypos: f64) void {
        self.mouse_position.xy.x = @floatCast(f32, xpos);
        self.mouse_position.xy.y = @floatCast(f32, ypos);
    }

    fn mouse_click(self: *Game) void {
    }

    pub fn prepare_render(self: *Game, dt: f64) void {
        // TODO: render a bunch of tiles in a grid!
    }

    pub fn process_command(self: *Game, cmd: command.Command) void {
        switch (cmd) {
            command.Command.Quit => {
                self.running = false;
            },
            command.Command.ToggleDebug => {
                self.renderer.debug_render = !self.renderer.debug_render;
            },
            command.Command.LeftClick => {
                self.mouse_click();
            },
            else => {},
        }
    }
};
