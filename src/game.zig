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

const GAME_TITLE: []const u8 = "Pong";
const START_GAME: []const u8 = "Start Game";
const QUIT_GAME: []const u8 = "Quit";

const GameStateTag = enum {
    Menu,
    Pong,
};

const GameState = union(GameStateTag) {
    Menu: void,
    Pong: void,
};

pub const Game = struct {
    running: bool,
    debug_render: bool,
    renderer: *Renderer,
    allocator: *std.mem.Allocator,
    text_labels: [3]TextLabel,
    selected_menu_item_idx: usize,
    mouse_position: Vec2(f32),
    game_state: GameState,

    pub fn new(allocator: *std.mem.Allocator, renderer: *Renderer) !*Game {
        var game = try allocator.create(Game);
        game.running = true;
        game.debug_render = false;
        game.mouse_position = Vec2(f32).new_point(0.0, 0.0);
        game.renderer = renderer;
        game.allocator = allocator;
        game.text_labels = [_]TextLabel{
            try TextLabel.new(GAME_TITLE, &renderer.title_font, colours.BLUE, renderer, allocator),
            try TextLabel.new(START_GAME, &renderer.menu_item_font, colours.BLUE, renderer, allocator),
            try TextLabel.new(QUIT_GAME, &renderer.menu_item_font, colours.BLUE, renderer, allocator),
        };
        game.selected_menu_item_idx = 1;
        game.game_state = GameState.Menu;
        try game.update_layout();
        return game;
    }

    pub fn deinit(self: *Game) void {
        const allocator = self.allocator;
        allocator.destroy(self);
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
        try self.update_text_labels();
    }

    fn update_text_labels(self: *Game) !void {
        for (self.text_labels) |*label, idx| {
            if (idx == self.selected_menu_item_idx) {
                label.colour = colours.LIGHT_TEXT;
            } else {
                label.colour = colours.BLUE;
            }
            try label.update_render_groups(self.allocator, self.renderer);
        }
    }

    pub fn update_mouse_position(self: *Game, xpos: f64, ypos: f64) void {
        self.mouse_position.xy.x = @floatCast(f32, xpos);
        self.mouse_position.xy.y = @floatCast(f32, ypos);
    }

    fn mouse_click(self: *Game) void {
        switch (self.game_state) {
            GameStateTag.Menu => {
                if (self.text_labels[2].bounding_box.overlaps_point(self.mouse_position)) {
                    self.running = false;
                }
            },
            else => {},
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
            command.CommandTag.LeftClick => {
                self.mouse_click();
            },
            command.CommandTag.Down => {
                switch (self.game_state) {
                    GameState.Menu => {
                        if (self.selected_menu_item_idx < self.text_labels.len - 1) {
                            self.selected_menu_item_idx += 1;
                            self.update_text_labels() catch unreachable;
                        }
                    },
                    else => {},
                }
            },
            command.CommandTag.Up => {
                switch (self.game_state) {
                    GameState.Menu => {
                        if (self.selected_menu_item_idx > 1) {
                            self.selected_menu_item_idx -= 1;
                            self.update_text_labels() catch unreachable;
                        }
                    },
                    else => {},
                }
            },
            command.CommandTag.Enter => {
                if (self.game_state == .Menu) {
                    if (self.selected_menu_item_idx == 2) { // Quit
                        self.running = false;
                    } else if (self.selected_menu_item_idx == 1) { // start game
                        console.debug("starting game\n", .{});
                        self.game_state = GameState.Pong;
                    }
                }
            },
            else => {},
        }
    }
};
