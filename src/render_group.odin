package main

import "core:fmt"

Quad :: struct {
	position: rectangle2,
	z: f32,
	texture: rectangle2,
	debug_info: string,
}

Render_Settings :: enum {
	QuadShader,
	DepthTesting,
	AlphaBlending,
	FaceCulling,
	ClearColor,
	ClearDepth,
	Viewport,
}
Render_Settings_Set :: bit_set[Render_Settings]

Uniform_Type :: enum {
	Texture,
	Z,
	Texture_Transform,
}

Uniform_Data :: struct {
	setting: Uniform_Type,
	data: union {
		int, // e.g. texture ID
		u32,
		i32,
		f32,
		v4,
		matrix[4,4]f32,
	},
}

max_uniform_data :: 16

Render_Group :: struct {
	debug_name: cstring,
	settings: Render_Settings_Set,
	uniforms: [max_uniform_data]Uniform_Data,
	num_uniforms: int,
	data: union {
		[dynamic]Quad,
		rectangle2,
		rectangle2s,
		v4, // ClearColor color
	},
	num_elements: int, // FIXME: is this too-implementation specific?
}

push_uniform_data :: proc(render_group: ^Render_Group, uniform_data: Uniform_Data) {
	assert(render_group.num_uniforms < max_uniform_data)
	render_group.uniforms[render_group.num_uniforms] = uniform_data
	render_group.num_uniforms += 1
}

texture_as_render_group :: proc(renderer: ^Renderer, texture_name: string, debug_name: cstring, position: rectangle2, tex_transform: matrix[4,4]f32, z: f32) -> Render_Group {
	assert(rect_width(position) > 0.0)
	assert(rect_height(position) > 0.0)
	render_group := Render_Group {
		debug_name = debug_name,
		settings = {.QuadShader},
	}
	render_group.data = make([dynamic]Quad)
	append(&render_group.data.([dynamic]Quad), Quad{position = position})
	texture_id := renderer.textures[texture_name].id
	push_uniform_data(&render_group, Uniform_Data{
		setting = .Texture,
		data = texture_id,
	})
	push_uniform_data(&render_group, Uniform_Data{
		setting = .Z,
		data = z,
	})
	push_uniform_data(&render_group, Uniform_Data{
		setting = .Texture_Transform,
		data = tex_transform,
	})
	return render_group
}

clear_render_group :: proc(color: v4) -> Render_Group {
	render_group := Render_Group {
		debug_name = "clear_color_depth",
		settings = {.ClearColor, .ClearDepth},
		data = color,
	}
	return render_group
}
