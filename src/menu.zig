const std = @import("std");
const Font = @import("fonts.zig").Font;
const TextLabel = @import("text_label.zig").TextLabel;
const Renderer = @import("opengl_renderer.zig").Renderer;
const Rect = @import("rect.zig").Rect;
const layout = @import("layout.zig");
const colours = @import("colours.zig");
const command = @import("command.zig");
const Game = @import("game.zig").Game;
const maths = @import("maths.zig");
const Vec2 = maths.Vec2;
const console = @import("console.zig");

fn prepare_menu_label(label: *TextLabel, renderer: *Renderer) void {
    std.debug.assert((label.contents[0] >= 32) and (label.contents[0] <= 126));
    if (renderer.debug_render) {
        for (renderer.outline_as_render_group("textLabelOutline", label.bounding_box, colours.BLUE, 0.8, 1.0)) |group| {
            renderer.push_render_group(group);
        }
        for (label.debug_render_groups.items) |render_group| {
            renderer.push_render_group(render_group);
        }
    }
    for (label.render_groups.items) |render_group| {
        renderer.push_render_group(render_group);
    }
}

pub const ItemParams = struct {
    text: []const u8,
    activate_cmd: command.Command,
};

pub const MenuItem = struct {
    label: TextLabel,
    activate_cmd: command.Command,

    pub fn new(allocator: *std.mem.Allocator, text: []const u8, font: *Font, colour: colours.Colour, activate_cmd: command.Command, renderer: *Renderer) !MenuItem {
        const label = try TextLabel.new(text, font, colour, renderer, allocator);
        return MenuItem{
            .label = label,
            .activate_cmd = activate_cmd,
        };
    }

    fn prepare_render(self: *MenuItem, renderer: *Renderer) void {
        prepare_menu_label(&self.label, renderer);
    }
};

pub const Menu = struct {
    title: TextLabel,
    items: std.ArrayList(MenuItem),
    selected_item: ?usize,
    selected_colour: colours.Colour,
    unselected_colour: colours.Colour,
    allocator: *std.mem.Allocator,
    renderer: *Renderer,

    pub fn new(allocator: *std.mem.Allocator, title_text: []const u8, items: []const ItemParams, selected_colour: colours.Colour, unselected_colour: colours.Colour, renderer: *Renderer) !Menu {
        const title = try TextLabel.new(title_text, &renderer.title_font, colours.BLUE, renderer, allocator);
        var menu = Menu{
            .title = title,
            .items = std.ArrayList(MenuItem).init(allocator),
            .selected_item = null, // in case there are no items to select
            .selected_colour = selected_colour,
            .unselected_colour = unselected_colour,
            .allocator = allocator,
            .renderer = renderer,
        };
        for (items) |item_params, idx| {
            if (idx == 0) {
                menu.selected_item = 0;
            }
            try menu.items.append(try MenuItem.new(allocator, item_params.text, &renderer.menu_item_font, menu.unselected_colour, item_params.activate_cmd, renderer));
        }
        return menu;
    }

    pub fn update_layout(self: *Menu) !void {
        var bounding_boxes_array = std.ArrayList(*Rect).init(self.allocator);
        defer bounding_boxes_array.deinit();
        try bounding_boxes_array.append(&self.title.bounding_box);
        for (self.items.items) |*menu_item| {
            try bounding_boxes_array.append(&menu_item.label.bounding_box);
        }
        const bounding_boxes = bounding_boxes_array.toOwnedSlice();
        layout.layout_vertically(bounding_boxes, 2.0);
        layout.center_vertically(bounding_boxes, self.renderer.viewport_rect);
        layout.center_horizontally(bounding_boxes, self.renderer.viewport_rect);
        try self.update_text_labels();
    }

    fn update_text_labels(self: *Menu) !void {
        try self.title.update_render_groups(self.allocator, self.renderer);
        for (self.items.items) |*menu_item, idx| {
            if (idx == self.selected_item) {
                menu_item.label.colour = self.selected_colour;
            } else {
                menu_item.label.colour = self.unselected_colour;
            }
            try menu_item.label.update_render_groups(self.allocator, self.renderer);
        }
    }

    pub fn prepare_render(self: *Menu, dt: f64) void {
        if (self.renderer.debug_render) {
            self.renderer.push_render_group(self.renderer.horizontal_line_as_render_group("middleY", self.renderer.viewport_rect.center[1], colours.RED, 0.9));
            self.renderer.push_render_group(self.renderer.vertical_line_as_render_group("middleX", self.renderer.viewport_rect.center[0], colours.RED, 0.9));
        }
        prepare_menu_label(&self.title, self.renderer);
        for (self.items.items) |*menu_item| {
            menu_item.prepare_render(self.renderer);
        }
    }

    pub fn mouse_click(self: *Menu, mouse_position: Vec2(f32)) ?command.Command {
        for (self.items.items) |menu_item, idx| {
            if (menu_item.label.bounding_box.overlaps_point(mouse_position)) {
                return menu_item.activate_cmd;
            }
        }
        return null;
    }

    pub fn process_command(self: *Menu, cmd: command.Command) ?command.Command {
        switch (cmd) {
            command.Command.Down => {
                if (self.selected_item) |*selected_item| {
                    if (selected_item.* < (self.items.items.len - 1)) {
                        selected_item.* += 1;
                        self.update_text_labels() catch unreachable;
                    }
                } else {
                    self.selected_item = 0;
                    self.update_text_labels() catch unreachable;
                }
            },
            command.Command.Up => {
                if (self.selected_item) |*selected_item| {
                    if (selected_item.* > 0) {
                        selected_item.* -= 1;
                        self.update_text_labels() catch unreachable;
                    }
                } else {
                    self.selected_item = self.items.items.len - 1;
                    self.update_text_labels() catch unreachable;
                }
            },
            command.Command.Enter => {
                if (self.selected_item) |selected_item| {
                    return self.items.items[selected_item].activate_cmd;
                }
            },
            else => {},
        }

        return null;
    }
};
