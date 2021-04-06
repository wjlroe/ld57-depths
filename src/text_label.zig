const std = @import("std");
const c = @import("c.zig");
const Renderer = @import("opengl_renderer.zig").Renderer;
const RenderGroup = @import("render_group.zig").RenderGroup;
const Rect = @import("rect.zig").Rect;
const colours = @import("colours.zig");
const maths = @import("maths.zig");
const Vec4 = maths.Vec4;
const console = @import("console.zig");
const Font = @import("fonts.zig").Font;

pub const TextLabel = struct {
    contents_ptr: usize,
    contents: []const u8,
    render_groups: std.ArrayList(RenderGroup),
    debug_render_groups: std.ArrayList(RenderGroup),
    bounding_box: Rect,
    font: *Font,
    colour: colours.Colour,

    pub fn new(contents: []const u8, font: *Font, colour: colours.Colour, renderer: *Renderer, allocator: *std.mem.Allocator) !TextLabel {
        var label = TextLabel{
            .contents = contents[0..],
            .contents_ptr = undefined,
            .render_groups = std.ArrayList(RenderGroup).init(allocator),
            .debug_render_groups = std.ArrayList(RenderGroup).init(allocator),
            .bounding_box = Rect{},
            .font = font,
            .colour = colour,
        };
        label.contents_ptr = @ptrToInt(label.contents.ptr);
        try label.update_render_groups(allocator, renderer);
        return label;
    }

    pub fn update_render_groups(self: *TextLabel, allocator: *std.mem.Allocator, renderer: *Renderer) !void {
        _ = self.render_groups.toOwnedSlice(); // clear down the existing items
        _ = self.debug_render_groups.toOwnedSlice();

        // The position of the bounding box can be changed to move this label around
        const xy = self.bounding_box.top_left();
        var x: f32 = xy[0];
        var y: f32 = xy[1];
        self.debug_crosshair_at(renderer, x, y, "topLeftLabel");
        var x0: c_int = undefined;
        var y0: c_int = undefined;
        var x1: c_int = undefined;
        var y1: c_int = undefined;
        var advance: c_int = undefined;
        var lsb: c_int = undefined;

        const pixel_height = self.font.font_size;
        const scale = c.stbtt_ScaleForPixelHeight(&self.font.info, pixel_height);
        var ascent: c_int = undefined;
        var descent: c_int = undefined;
        var line_gap: c_int = undefined;
        // TODO: move these into the renderer.font structure
        c.stbtt_GetFontVMetrics(&self.font.info, &ascent, &descent, &line_gap);
        const line_height = scale * (@intToFloat(f32, ascent) - @intToFloat(f32, descent) + @intToFloat(f32, line_gap));
        const tex_dim = @intToFloat(f32, self.font.texture_dim);

        var line_it = (try std.unicode.Utf8View.init(self.contents)).iterator();
        while (line_it.nextCodepoint()) |char_u21| {
            const character = @intCast(c_int, char_u21);
            const glyph_idx = c.stbtt_FindGlyphIndex(&self.font.info, character);
            c.stbtt_GetGlyphHMetrics(&self.font.info, glyph_idx, &advance, &lsb);
            c.stbtt_GetGlyphBitmapBox(&self.font.info, glyph_idx, scale, scale, &x0, &y0, &x1, &y1);
            const maybe_packed_char = self.font.packed_char(@intCast(usize, character));
            if (maybe_packed_char) |packed_char| {
                var font_render_group = RenderGroup.new_quad(allocator, &renderer.quad_shader, &renderer.gl_quad, "charInFont");
                font_render_group.depth_testing = false;
                font_render_group.set_float("u_Z", 0.8);
                font_render_group.set_vec4("color", self.colour);
                font_render_group.set_int("sample_texture", 1);
                font_render_group.set_mat4("tex_transform", maths.Matrix4.identity());
                font_render_group.set_texture("texture1", .{ .slot = 0, .texture_id = self.font.texture_id });

                const width = @intToFloat(f32, x1 - x0);
                const left_edge_x: f32 = x;
                const right_edge_x: f32 = x + width;
                const height = @intToFloat(f32, y1 - y0);
                if (character == 'P') {
                    std.debug.warn("height of P: {d: >3}, height*scale: {d: >3}\n", .{ height, height * scale });
                }
                const right_edge_y: f32 = y + line_height + @intToFloat(f32, y1);
                const left_edge_y: f32 = right_edge_y - height;
                self.debug_crosshair_at(renderer, left_edge_x, left_edge_y, "leftEdgeXY");
                self.debug_crosshair_at(renderer, right_edge_x, right_edge_y, "rightEdgeXY");
                const pos = Rect.from_top_left_bottom_right(left_edge_x, left_edge_y, right_edge_x, right_edge_y);
                // TODO: do we really wanna position within the viewport rect?
                var transform_matrix: maths.Matrix4 = pos.transform_within(renderer.viewport_rect);
                font_render_group.set_mat4("pos_transform", transform_matrix);
                const packed_char_rect = Rect.from_top_left_bottom_right(@intToFloat(f32, packed_char.x0) / tex_dim, @intToFloat(f32, packed_char.y0) / tex_dim, @intToFloat(f32, packed_char.x1) / tex_dim, @intToFloat(f32, packed_char.y1) / tex_dim);
                const tex_transform = packed_char_rect.within_texture_coords();
                font_render_group.set_mat4("tex_transform", tex_transform);
                try self.render_groups.append(font_render_group);

                x += @intToFloat(f32, advance) * scale;
            }
        }
        const width = x - xy[0];
        const height = scale * @intToFloat(f32, ascent);
        self.bounding_box.bounds = [_]f32{ width, height };
        console.debug("line_height: {d: >3}, height: {d: >3}, scale: {d: >3}, ascent: {d: >3}, descent: {d: >3}, line_gap: {d: >3}\n", .{ line_height, height, scale, ascent, descent, line_gap });
    }

    fn debug_crosshair_at(self: *TextLabel, renderer: *Renderer, x: f32, y: f32, name: [*c]const u8) void {
        for (renderer.crosshair_as_render_group(name, x, y, 30.0, colours.YELLOW, 0.7)) |render_group| {
            self.debug_render_groups.append(render_group) catch unreachable;
        }
    }
};
