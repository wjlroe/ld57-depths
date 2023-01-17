package main

Frame :: struct {
	duration: f32,
	name: string,
	rect: rectangle2,
}

// TODO: parse sprite JSON from aseprite
Sprite :: struct {
	debug_name: cstring,
	texture_name: string,
	frames: []Frame,
	current_frame: int,
	frame_time: f32,
	width: int,
	height: int,
	frame_width: int,
	frame_height: int,
	rect: rectangle2,
	resource: ^Resource,
}

sprite_as_render_group :: proc(sprite: ^Sprite, renderer: ^Renderer, position: rectangle2, z: f32) -> Render_Group {
	current_frame := sprite.frames[sprite.current_frame]
	render_group := texture_as_render_group(renderer, sprite.texture_name, sprite.debug_name, position, current_frame.rect, z)
	return render_group
}
