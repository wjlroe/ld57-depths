package main

setup_renderer_gl_4_1 :: proc(renderer: ^Renderer, gl_loader: Set_Proc_Address_Type) {

}

resize_framebuffer_gl_4_1 :: proc(renderer: ^Renderer) {

}

render_gl_4_1 :: proc(renderer: ^Renderer) {

}

create_texture_gl_4_1 :: proc(renderer: ^Renderer, shader_idx: int, content: [^]byte, width: int, height: int, color_format: Color_Format) -> int {
	return 0
}

@(private="package")
vtable_renderer_gl_4_1 :: Renderer_VTable {
	impl_setup = setup_renderer_gl_4_1,
	impl_resize_framebuffer = resize_framebuffer_gl_4_1,
	impl_render = render_gl_4_1,
	impl_create_texture = create_texture_gl_4_1,
}
