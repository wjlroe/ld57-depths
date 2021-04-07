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
const Pong = @import("pong.zig").Pong;

const GAME_TITLE: []const u8 = "Pong";
const START_GAME: []const u8 = "Start Game";
const QUIT_GAME: []const u8 = "Quit";

const GameModeTag = enum {
    InMenu,
    InGame,
};

const GameMode = union(GameModeTag) {
    InMenu: Menu,
    InGame: Pong,
};

pub const Game = struct {
    running: bool,
    renderer: *Renderer,
    allocator: *std.mem.Allocator,
    mouse_position: Vec2(f32),
    game_mode: GameMode,

    pub fn new(allocator: *std.mem.Allocator, renderer: *Renderer) !*Game {
        var game = try allocator.create(Game);
        game.running = true;
        game.mouse_position = Vec2(f32).new_point(0.0, 0.0);
        game.renderer = renderer;
        game.allocator = allocator;
        game.goto_menu();
        try game.update_layout();
        return game;
    }

    pub fn deinit(self: *Game) void {
        const allocator = self.allocator;
        allocator.destroy(self);
    }

    fn goto_menu(self: *Game) void {
        // FIXME: This doesn't make sense, the menu shouldn't overwrite the game!
        // switch (self.game_mode) {
        //     GameMode.InGame => |*pong| {
        //         pong.deinit();
        //     },
        //     else => {},
        // }
        const game_menu = Menu.new(self.allocator, GAME_TITLE, &[_]ItemParams{ .{ .text = START_GAME, .activate_cmd = command.Command.StartGame }, .{ .text = QUIT_GAME, .activate_cmd = command.Command.Quit } }, colours.LIGHT_TEXT, colours.BLUE, self.renderer) catch unreachable;
        self.game_mode = GameMode{ .InMenu = game_menu };
    }

    fn goto_pong(self: *Game) void {
        // FIXME: Why is the game cleaning up the menu?!
        switch (self.game_mode) {
            GameMode.InMenu => |*menu| {
                menu.deinit();
            },
            else => {},
        }
        const pong = Pong.new(self.allocator, self.renderer);
        self.game_mode = GameMode{ .InGame = pong };
    }

    fn update_layout(self: *Game) !void {
        switch (self.game_mode) {
            GameMode.InMenu => |*game_menu| {
                try game_menu.update_layout();
            },
            else => {},
        }
    }

    pub fn update_mouse_position(self: *Game, xpos: f64, ypos: f64) void {
        self.mouse_position.xy.x = @floatCast(f32, xpos);
        self.mouse_position.xy.y = @floatCast(f32, ypos);
    }

    fn mouse_click(self: *Game) void {
        switch (self.game_mode) {
            GameMode.InMenu => |*game_menu| {
                if (game_menu.mouse_click(self.mouse_position)) |cmd| {
                    self.process_command(cmd);
                }
            },
            else => {},
        }
    }

    pub fn prepare_render(self: *Game, dt: f64) void {
        switch (self.game_mode) {
            GameMode.InMenu => |*game_menu| {
                game_menu.prepare_render(dt);
            },
            else => {},
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
            command.Command.StartGame => {
                self.goto_pong();
            },
            else => {
                switch (self.game_mode) {
                    GameMode.InMenu => |*game_menu| {
                        if (game_menu.process_command(cmd)) |next_cmd| {
                            self.process_command(next_cmd);
                        }
                    },
                    else => {},
                }
            },
        }
    }
};
