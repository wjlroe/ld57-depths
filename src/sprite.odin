package main

import "core:log"
import "core:math"

Frame :: struct {
	duration: f64,
	name: string,
	rect: rectangle2s,
	coords: v2s,
}

// TODO: parse sprite JSON from aseprite
Sprite :: struct {
	debug_name: cstring,
	texture_name: string,
	frames: []Frame,
	num_frames: int,
	current_frame: int,
	frame_layout: v2s, // x,y or columns/rows
	frame_time: f64,
	tex_dim: v2s,
	frame_dim: v2s,
	resource: ^Resource,
}

sprite_as_render_group :: proc(sprite: ^Sprite, renderer: ^Renderer, position: rectangle2, z: f32, debug_name: cstring) -> Render_Group {
	current_frame := sprite.frames[sprite.current_frame]
	sx := f32(sprite.frame_dim.x) / f32(sprite.tex_dim.x)
	sy := f32(sprite.frame_dim.y) / f32(sprite.tex_dim.y)
	tx : f32 = 0.0
	ty : f32 = 0.0
	if sprite.num_frames > 0 {
		tx = f32(current_frame.coords.x) / f32(sprite.frame_layout.x)
		ty = f32(current_frame.coords.y) / f32(sprite.frame_layout.y)
	}
	scale := scale_matrix(sx, sy, 1.0)
	translation := translation_matrix(tx, ty, 0.0)
	tex_transform := translation * scale
	render_group := texture_as_render_group(renderer, sprite.texture_name, debug_name, position, tex_transform, z)
	return render_group
}

split_into_frames :: proc(sprite: ^Sprite, num_x: int, num_y: int, duration: f64) {
	sprite.frame_layout.x = num_x
	sprite.frame_layout.y = num_y
	sprite.frame_dim.x = int(math.round(f32(sprite.tex_dim.x) / f32(num_x)))
	sprite.frame_dim.y = int(math.round(f32(sprite.tex_dim.y) / f32(num_y)))
	sprite.num_frames = num_x * num_y
	sprite.frames = make([]Frame, sprite.num_frames)
	for y in 0..<num_y {
		for x in 0..<num_x {
			idx := num_y * y + x
			sprite.frames[idx].duration = duration
			sprite.frames[idx].rect = rect_min_dim(v2s{x * sprite.frame_dim.x, y * sprite.frame_dim.y}, sprite.frame_dim)
			sprite.frames[idx].coords = v2s{x, y}
		}
	}
}

update_sprite :: proc(sprite: ^Sprite, dt: f64) {
	current_frame := sprite.frames[sprite.current_frame]
	new_time := sprite.frame_time + dt
	if new_time > current_frame.duration {
		overflow := new_time - current_frame.duration
		sprite.current_frame = (sprite.current_frame + 1) % sprite.num_frames
		sprite.frame_time = overflow
	} else {
		sprite.frame_time = new_time
	}
}
