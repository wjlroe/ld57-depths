const std = @import("std");
const console = @import("console.zig");
const Rect = @import("rect.zig").Rect;
const Matrix4 = @import("maths.zig").Matrix4;
const Resource = @import("resources.zig").Resource;
const RenderGroup = @import("render_group.zig").RenderGroup;
const Renderer = @import("opengl_renderer.zig").Renderer;

const floor_tiles_sprite_json = @embedFile("../assets/floor_tiles.json");
// const floor_tiles_texture = @embedFile("../assets/floor_tiles.png");

pub const Frame = struct {
    x: i64,
    y: i64,
    duration: f64,
    name: []const u8,
    rect: Rect,

    fn new(x: i64, y: i64, duration: f64, name: []const u8) Frame {
        return Frame{
            .x = x,
            .y = y,
            .duration = duration,
            .name = name,
            .rect = Rect.from_bounds(@intToFloat(f32, x), @intToFloat(f32, y)),
        };
    }
};

fn compare_frames(context: void, a: Frame, b: Frame) bool {
    return std.mem.order(u8, a.name, b.name) == std.math.Order.lt;
}

pub const Sprite = struct {
    frames: []Frame,
    current_frame: usize,
    frame_time: f64,
    width: i64,
    height: i64,
    frame_width: i64,
    frame_height: i64,
    rect: Rect,
    resource: Resource,

    pub fn new_from_json(allocator: *std.mem.Allocator, json: []const u8, resource: Resource) !Sprite {
        var p = std.json.Parser.init(allocator, false);
        defer p.deinit();

        var tree = try p.parse(json);
        defer tree.deinit();

        var sprite: Sprite = undefined;
        var frames = std.ArrayList(Frame).init(allocator);

        var root = tree.root;
        var frames_obj = root.Object.get("frames").?.Object;
        var frames_iter = frames_obj.iterator();
        var frame_width: i64 = undefined;
        var frame_height: i64 = undefined;
        while (frames_iter.next()) |frame_obj| {
            var frame_frame_obj = frame_obj.value.Object.get("frame").?.Object;
            const frame_x = frame_frame_obj.get("x").?.Integer;
            const frame_y = frame_frame_obj.get("y").?.Integer;
            frame_width = frame_frame_obj.get("w").?.Integer;
            frame_height = frame_frame_obj.get("h").?.Integer;
            const frame_duration = frame_obj.value.Object.get("duration").?.Integer;
            try frames.append(Frame.new(frame_x, frame_y, @intToFloat(f64, frame_duration), frame_obj.key));
        }
        var meta_obj = root.Object.get("meta").?.Object;
        var size_obj = meta_obj.get("size").?.Object;
        const sheet_width = size_obj.get("w").?.Integer;
        const sheet_height = size_obj.get("h").?.Integer;
        sprite.frame_width = frame_width;
        sprite.frame_height = frame_height;
        sprite.width = sheet_width;
        sprite.height = sheet_height;
        sprite.rect = Rect.from_bounds(@intToFloat(f32, sheet_width), @intToFloat(f32, sheet_height));
        sprite.frames = frames.toOwnedSlice();
        sprite.current_frame = 0;
        sprite.frame_time = 0.0;
        sprite.resource = resource;
        std.sort.sort(Frame, sprite.frames, {}, compare_frames);

        return sprite;
    }

    pub fn new_player(allocator: *std.mem.Allocator) !Sprite {
        const sprite = try Sprite.new_from_json(allocator, player_sprite_json);
        return sprite;
    }

    pub fn new_floor_tiles(allocator: *std.mem.Allocator) !Sprite {
        if (Resource.find("floor_tiles.png")) |resource| {
            var sprite = try Sprite.new_from_json(allocator, floor_tiles_sprite_json, resource);
            return sprite;
        }
        return error.ResourceNotFound;
    }

    pub fn add_time(self: *Sprite, dt: f64) void {
        self.frame_time += dt;
        if (self.frame_time >= self.frames[self.current_frame].duration) {
            self.current_frame = (self.current_frame + 1) % self.frames.len;
            self.frame_time = 0.0;
        }
    }

    pub fn get_current_frame(self: *Sprite) *Frame {
        return &self.frames[self.current_frame];
    }

    fn get_transform(self: *Sprite, do_flip: bool) Matrix4 {
        const frame = self.get_current_frame();
        const flip_factor: f32 = if (do_flip) -1.0 else 1.0;
        const sx = 1.0 / @intToFloat(f32, self.frames.len);
        const sy = 1.0;
        const tx = @intToFloat(f32, frame.x) / @intToFloat(f32, self.width);
        const ty = @intToFloat(f32, frame.y) / @intToFloat(f32, self.height);
        const transform = Matrix4.from_rows(sx, 0.0, 0.0, tx, // row 0
            0.0, sy, 0.0, ty, // row 1
            0.0, 0.0, 1.0, 0.0, // row 2
            0.0, 0.0, 0.0, 1.0); // row 3
        if (do_flip) {
            const flip_transform = Matrix4.from_rows(-sx, 0.0, 0.0, tx, // col 0
                0.0, sy, 0.0, ty, // col 1
                0.0, 0.0, 1.0, 0.0, // col 2
                0.0, 0.0, 0.0, 1.0); //col 3
            //return flip_transform.mul(transform);
            return flip_transform;
        } else {
            return transform;
        }
    }

    pub fn as_render_group(self: *Sprite, name: []const u8, renderer: *Renderer, position: Rect, z: f32) RenderGroup {
        const tex_transform = self.get_transform(false);
        return renderer.texture_as_render_group(name, position, z, tex_transform, self.resource.texture_id);
    }
};
