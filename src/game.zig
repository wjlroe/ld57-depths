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
        if (renderer.bind_image(game.floor_tiles_sprite.resource, false)) |texture_id| {
            game.floor_tiles_sprite.resource.texture_id = texture_id;
        } else {
            return error.CouldNotBindTexture;
        }
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
        // Tiles
        const tile_size = self.floor_tiles_sprite.frame_width * 2;
        {
            const tile_pos = Rect.from_top_left_bottom_right(100.0, 100.0, 100.0 + @intToFloat(f32, tile_size), 100.0 + @intToFloat(f32, tile_size));
            const z = 0.5;
            self.renderer.push_render_group(self.floor_tiles_sprite.as_render_group("floor_tile", self.renderer, tile_pos, z));
        }

        if (self.renderer.debug_render) {
            // grid stuff
            const window_width = @floatToInt(i32, self.renderer.viewport_rect.bounds[0]);
            const window_height = @floatToInt(i32, self.renderer.viewport_rect.bounds[1]);
            const tiles_wide = @divFloor(window_width, tile_size);
            const x_offset = @intToFloat(f32, @mod(window_width, tile_size)) / 2.0;
            const tiles_high = @divFloor(window_height, tile_size);
            const y_offset = @intToFloat(f32, @mod(window_height, tile_size)) / 2.0;
            const thickness = 1.0;
            const z = 0.2;
            const colour = colours.ORANGE;
            var tile_x: i32 = 0;
            var tile_y: i32 = 0;
            var x = x_offset;
            var y = y_offset;
            while (tile_y < tiles_high) {
                while (tile_x < tiles_wide) {
                    const position = Rect.from_top_left_bottom_right(x, y, x + @intToFloat(f32, tile_size), y + @intToFloat(f32, tile_size));
                    for (self.renderer.outline_as_render_group("grid", position, colour, z, thickness)) |render_group| {
                        self.renderer.push_render_group(render_group);
                    }
                    tile_x += 1;
                    x += @intToFloat(f32, tile_size);
                }
                tile_y += 1;
                tile_x = 0;
                x = x_offset;
                y += @intToFloat(f32, tile_size);
            }
        }
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
