package main

Set_Proc_Address_Type :: #type proc(p: rawptr, name: cstring)

Color_Format :: enum{RED, RGB, RGBA}

Setup_Renderer_Proc :: proc(renderer: ^Renderer, func_loader: Set_Proc_Address_Type)
Resize_Framebuffer_Proc :: proc(renderer: ^Renderer)
Render_Proc :: proc(renderer: ^Renderer)
Create_Texture_Proc :: proc(renderer: ^Renderer, shader_idx: int, contents: [^]byte, width: int, height: int, color_format: Color_Format) -> int

Renderer_VTable :: struct {
	impl_setup: Setup_Renderer_Proc,
	impl_resize_framebuffer: Resize_Framebuffer_Proc,
	impl_render: Render_Proc,
	impl_create_texture: Create_Texture_Proc,
}

OpenGL_Version :: struct {
	major: i32,
	minor: i32,
}

max_textures :: 16

Renderer :: struct {
	using renderer_vtable: Renderer_VTable,
	name: string,

	opengl_version: OpenGL_Version,
	framebuffer_dim: v2s,
	textures: [max_textures]OpenGL_Texture,
	num_textures: int,
}

push_texture :: proc(renderer: ^Renderer, texture: OpenGL_Texture) -> (texture_id: int) {
	assert(renderer.num_textures < len(renderer.textures))
	texture_id = renderer.num_textures
	renderer.textures[texture_id] = texture
	renderer.num_textures += 1
	return
}

activate_gl_4_1 :: proc(renderer: ^Renderer) {
	renderer.renderer_vtable = vtable_renderer_gl_4_1
	renderer.name = "OpenGL 4.1"
}
