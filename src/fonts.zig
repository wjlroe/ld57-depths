const std = @import("std");
const c = @import("c.zig");
const console = @import("console.zig");
const OpenGL = @import("opengl.zig").OpenGL;
const Rect = @import("rect.zig").Rect;

pub const Font = struct {
    info: c.stbtt_fontinfo,
    packed_chars: []c.stbtt_packedchar,
    texture_id: c_uint,
    first_character: usize,
    num_of_characters: usize,
    texture_dim: c_int,
    tex_rect: Rect,
    font_size: f32,
    font_index: c_int,
    allocator: *std.mem.Allocator,

    pub fn new_neuton(allocator: *std.mem.Allocator, opengl: *OpenGL, font_size: f32, font_index: c_int) !Font {
        var font: Font = undefined;
        font.first_character = 32;
        font.num_of_characters = 1024;
        font.font_size = font_size;
        font.font_index = font_index;
        font.allocator = allocator;
        if (c.stbtt_InitFont(&font.info, neuton_regular, font.font_index) == 0) {
            console.debug("Failed to InitFont!\n", .{});
            return error.FontInitError;
        }
        var pack_context: c.stbtt_pack_context = undefined;
        font.packed_chars = try allocator.alloc(c.stbtt_packedchar, font.num_of_characters + 1);
        font.texture_dim = 256;
        var tex_buffer: []u8 = try allocator.alloc(u8, @intCast(usize, font.texture_dim * font.texture_dim));
        defer allocator.free(tex_buffer);
        while (true) {
            font.tex_rect = Rect.from_top_left_bottom_right(0.0, 0.0, @intToFloat(f32, font.texture_dim), @intToFloat(f32, font.texture_dim));
            tex_buffer = try allocator.alloc(u8, @intCast(usize, font.texture_dim * font.texture_dim));
            if (c.stbtt_PackBegin(&pack_context, tex_buffer.ptr, font.texture_dim, font.texture_dim, 0, 1, null) == 0) {
                console.debug("Failed to PackBegin!\n", .{});
                return error.FontPackBeginError;
            }
            // stbtt_PackSetOversampling(&packContext, 1, 1);
            if (c.stbtt_PackFontRange(&pack_context, neuton_regular, font.font_index, font.font_size, @intCast(c_int, font.first_character), @intCast(c_int, font.num_of_characters), font.packed_chars.ptr) == 0) {
                font.texture_dim *= 2;
                allocator.free(tex_buffer);
            } else {
                c.stbtt_PackEnd(&pack_context);
                break;
            }
        }

        opengl.glGenTextures(1, &font.texture_id);
        opengl.check_gl_error("after glGenTextures");
        opengl.glBindTexture(c.GL_TEXTURE_2D, font.texture_id);
        opengl.check_gl_error("after glBindTexture");

        opengl.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, font.texture_dim, font.texture_dim, 0, c.GL_RED, c.GL_UNSIGNED_BYTE, tex_buffer.ptr);
        opengl.check_gl_error("after glTexImage2D");
        opengl.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        opengl.check_gl_error("after glTexParameteri");

        return font;
    }

    pub fn deinit(self: *Font) void {
        self.allocator.free(self.packed_chars);
    }

    pub fn packed_char(self: *Font, glyph_idx: usize) ?c.stbtt_packedchar {
        const index = @intCast(i32, glyph_idx) - @intCast(i32, self.first_character);
        if (index < 0) {
            return null;
        }
        if (index >= self.packed_chars.len) {
            return null;
        }
        return self.packed_chars[@intCast(usize, index)];
    }
};

const neuton_regular = @embedFile("../assets/fonts/neuton/Neuton-Regular.ttf");
