const std = @import("std");
const c = @import("c.zig");
const Renderer = @import("opengl_renderer.zig").Renderer;
const render_group = @import("render_group.zig");
const Rect = @import("rect.zig").Rect;
const colours = @import("colours.zig");
const maths = @import("maths.zig");
const console = @import("console.zig");

pub const TextLabel = struct {
    contents_ptr: usize,
    contents: []const u8,
    // render_groups: std.ArrayList(render_group.RenderGroup),

    pub fn new(contents: []const u8, renderer: *Renderer, allocator: *std.mem.Allocator) !TextLabel {
        var label = TextLabel{
            .contents = contents[0..],
            .contents_ptr = undefined,
            // .render_groups = std.ArrayList(render_group.RenderGroup).init(allocator),
        };
        label.contents_ptr = @ptrToInt(label.contents.ptr);
        label.check_contents("TextLabel.new");
        // try label.update_render_groups(allocator, renderer);
        return label;
    }

    pub fn check_contents(self: *const TextLabel, message: []const u8) void {
        console.debug("[TextLabel.check_contents/{}] contents.ptr: {}, self.contents_ptr: {}\n", .{ message, @ptrToInt(self.contents.ptr), self.contents_ptr });
        std.debug.assert(@ptrToInt(self.contents.ptr) == self.contents_ptr);
        console.debug("[TextLabel.check_contents/{}] text_label: {x}\n", .{ message, self.contents[0] });
        console.debug("[TextLabel.check_contents/{}] contents: '{}', ({x}, {x}), len: ({}, {})\n", .{ message, self.contents[0..4], self.contents[0..4], "Pong", self.contents.len, "Pong".len });
        // console.debug("[TextLabel.check_contents/{}] null: {}\n", .{ message, self.contents[4] });
        std.debug.assert(std.mem.eql(u8, self.contents, "Pong"));
        console.debug("[TextLabel.check_contents/{}] contents.ptr: {}, self.contents_ptr: {}\n", .{ message, @ptrToInt(self.contents.ptr), self.contents_ptr });
    }

    pub fn update_render_groups(self: *TextLabel, allocator: *std.mem.Allocator, renderer: *Renderer) !void {
        // TODO: assume centered within viewport!
        _ = self.render_groups.toOwnedSlice(); // clear down the existing items

        var positions = std.ArrayList(Rect).init(allocator);

        var x: f32 = 0.0;
        var y: f32 = 0.0;
        var x0: c_int = undefined;
        var y0: c_int = undefined;
        var x1: c_int = undefined;
        var y1: c_int = undefined;
        var advance: c_int = undefined;
        var lsb: c_int = undefined;

        const pixel_height = renderer.font.font_size;
        const scale = c.stbtt_ScaleForPixelHeight(&renderer.font.info, pixel_height);
        var ascent: c_int = undefined;
        var descent: c_int = undefined;
        var line_gap: c_int = undefined;
        c.stbtt_GetFontVMetrics(&renderer.font.info, &ascent, &descent, &line_gap);
        const line_height = scale * (@intToFloat(f32, ascent) - @intToFloat(f32, descent) + @intToFloat(f32, line_gap));
        const tex_dim = @intToFloat(f32, renderer.font.texture_dim);
        var total_width: f32 = 0.0;

        var line_it = (try std.unicode.Utf8View.init(self.contents)).iterator();
        while (line_it.nextCodepoint()) |char_u21| {
            const character = @intCast(c_int, char_u21);
            console.debug("character: {x} ({d}), c_int: {x} ({d})\n", .{ char_u21, char_u21, character, character });
            const glyph_idx = c.stbtt_FindGlyphIndex(&renderer.font.info, character);
            c.stbtt_GetGlyphHMetrics(&renderer.font.info, glyph_idx, &advance, &lsb);
            c.stbtt_GetGlyphBitmapBox(&renderer.font.info, glyph_idx, scale, scale, &x0, &y0, &x1, &y1);
            const maybe_packed_char = renderer.font.packed_char(@intCast(usize, character));
            if (maybe_packed_char) |packed_char| {
                var font_render_group = render_group.RenderGroup.new_quad(allocator, &renderer.quad_shader, &renderer.gl_quad, "charInFont");
                font_render_group.depth_testing = false;
                font_render_group.set_float("u_Z", 0.8);
                font_render_group.set_vec4("color", colours.BLUE);
                font_render_group.set_int("sample_texture", 1);
                font_render_group.set_mat4("tex_transform", maths.Matrix4.identity());
                font_render_group.set_texture("texture1", .{ .slot = 0, .texture_id = renderer.font.texture_id });

                const width = @intToFloat(f32, x1 - x0);
                total_width += width;
                const left_edge_x: f32 = x;
                const right_edge_x: f32 = x + width;
                const height = @intToFloat(f32, y1 - y0);
                const left_edge_y: f32 = y + line_height - height + @intToFloat(f32, y1);
                const right_edge_y: f32 = y + line_height + @intToFloat(f32, y1);
                const pos = Rect.from_top_left_bottom_right(left_edge_x, left_edge_y, right_edge_x, right_edge_y);
                try positions.append(pos);
                const packed_char_rect = Rect.from_top_left_bottom_right(@intToFloat(f32, packed_char.x0) / tex_dim, @intToFloat(f32, packed_char.y0) / tex_dim, @intToFloat(f32, packed_char.x1) / tex_dim, @intToFloat(f32, packed_char.y1) / tex_dim);
                const tex_transform = packed_char_rect.within_texture_coords();
                font_render_group.set_mat4("tex_transform", tex_transform);
                try self.render_groups.append(font_render_group);

                x += @intToFloat(f32, advance) * scale;
            }
        }
        const width = x;
        const height = scale * (@intToFloat(f32, ascent) - @intToFloat(f32, descent));
        console.debug("line_height: {d: >3}, height: {d: >3}, scale: {d: >3}, ascent: {d: >3}, descent: {d: >3}, line_gap: {d: >3}\n", .{ line_height, height, scale, ascent, descent, line_gap });

        // recalc positions
        const x_offset = renderer.viewport_rect.center[0] - (total_width / 2.0);
        const y_offset = renderer.viewport_rect.center[1] - height;

        // create render groups
        for (positions.items) |untransformed_pos, i| {
            var pos = untransformed_pos;
            pos.center[0] += x_offset;
            pos.center[1] += y_offset;
            var transform_matrix: maths.Matrix4 = pos.transform_within(renderer.viewport_rect);
            self.render_groups.items[i].set_mat4("pos_transform", transform_matrix);
        }
    }
};
