package main

import glfw "vendor:glfw"

Window :: struct {
	glfw_window_handle: glfw.WindowHandle,
	renderer: Renderer,
	window_dim: v2s,
	framebuffer_dim: v2s,
	content_scale: v2,
	keep_open: bool,
}
