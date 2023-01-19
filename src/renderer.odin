package main

import "core:image"
import "core:image/png"
import "core:log"
import "core:os"

Set_Proc_Address_Type :: #type proc(p: rawptr, name: cstring)

Setup_Renderer_Proc :: proc(renderer: ^Renderer, func_loader: Set_Proc_Address_Type)
Resize_Framebuffer_Proc :: proc(renderer: ^Renderer)
Render_Proc :: proc(renderer: ^Renderer)
Create_Texture_Proc :: proc(renderer: ^Renderer, texture_name: string, image: ^image.Image, color_format: Color_Format)

Renderer_VTable :: struct {
	impl_setup: Setup_Renderer_Proc,
	impl_resize_framebuffer: Resize_Framebuffer_Proc,
	impl_render: Render_Proc,
	impl_create_texture: Create_Texture_Proc,
	impl_end_frame: Render_Proc,
}

Texture :: struct {
	name: string,
	id: int,
	resource: ^Resource,
	dim: v2s,
}

// TODO: how to store renderer-specific data?
Renderer :: struct {
	using renderer_vtable: Renderer_VTable,
	name: string,

	framebuffer_dim: v2s,
	viewport: rectangle2,
	ortho_projection: matrix[4,4]f32,
	render_groups: [dynamic]Render_Group,

	textures: map[string]Texture,
	next_texture_id: int,

	variant: union{^OpenGL_Renderer},
}

set_resource_as_texture :: proc(renderer: ^Renderer, name: string, resource: ^Resource) -> ^Texture {
	img, err := png.load_from_bytes(resource.data^)
	if err != nil {
		log.error(err)
		os.exit(1)
	}
	defer free(img)
	if !image.is_valid_image(img) {
		log.error("Not a valid image!")
		os.exit(1)
	}
	renderer.textures[name] = Texture {
		name = name,
		id = renderer.next_texture_id,
		resource = resource,
		dim = v2s{img.width, img.height},
	}
	renderer.next_texture_id += 1
	renderer->impl_create_texture(name, img, Color_Format.RGBA)
	return &renderer.textures[name]
}

push_render_group :: proc(renderer: ^Renderer, render_group: Render_Group) {
	append(&renderer.render_groups, render_group)
}

reset_ortho_projection :: proc(renderer: ^Renderer) {
	renderer.ortho_projection = ortho_matrix({0.0, f32(renderer.framebuffer_dim.y), -1.0}, {f32(renderer.framebuffer_dim.x), 0.0, 1.0})
}

renderer_end_frame :: proc(renderer: ^Renderer) {
	clear(&renderer.render_groups)
}
