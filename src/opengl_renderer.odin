package main

import "core:fmt"
import gl "vendor:OpenGL"
import "core:log"
import "core:strings"

quad_vertex_shader_source := #load("shaders/quad_vert.glsl")
quad_fragment_shader_source := #load("shaders/quad_frag.glsl")
circle_fragment_shader_source := #load("shaders/circle_frag.glsl")

OpenGL_Texture :: struct {
	opengl_id: u32,
	shader_idx: int,
	dim: v2s,
}

OpenGL_Quad :: struct {
	vao: u32,
	vbo: u32,
	ebo: u32,
	num_elements: i32,
}

// TODO: turn locations into something generic, rather than
// adding a new field here for every location in every shader
OpenGL_Shader :: struct {
	program_id: u32,
	position_location: u32,
	texture_location: u32,
	ortho_location: u32,
	z_location: u32,
	pos_transform_location: u32,
	tex_transform_location: u32,
	color_location: u32,
	settings_location: u32,
}

init_attrib_location :: proc(program_id: u32, loc: ^u32, name: cstring) {
	attrib_loc := gl.GetAttribLocation(program_id, name)
	assert(attrib_loc >= 0, fmt.tprintf("couldn't find location for attrib named '%s'", name))
	loc^ = u32(attrib_loc)
}

init_uniform_location :: proc(program_id: u32, loc: ^u32, name: cstring) {
	uniform_loc := gl.GetUniformLocation(program_id, name)
	assert(uniform_loc >= 0, "uniform location is invalid")
	loc^ = u32(uniform_loc)
}

get_program_iv :: proc(program_id: u32, parameter: u32) -> int {
	value : i32
	gl.GetProgramiv(program_id, parameter, &value)
	return int(value)
}

program_attributes :: proc(program_id: u32) {
	count := get_program_iv(program_id, gl.ACTIVE_ATTRIBUTES)

	buf_size : i32 = 16
	name : [16]byte
	length : i32 // name length

	size : i32 // size of the variable
	type : u32 // type of the variable
	i : u32 = 0
	attr_names_msg := strings.builder_make()
	defer strings.builder_destroy(&attr_names_msg)
	strings.write_string(&attr_names_msg, "Attributes names: ")
	for i < u32(count) {
		gl.GetActiveAttrib(program_id, i, buf_size, &length, &size, &type, &name[0])
		strings.write_string(&attr_names_msg, string(name[0:length]))
		if i+1 < u32(count) {
			strings.write_string(&attr_names_msg, ", ")
		}
		i += 1
	}
	// log.info(strings.to_string(attr_names_msg))
	strings.builder_reset(&attr_names_msg)

	count = get_program_iv(program_id, gl.ACTIVE_UNIFORMS)

	i = 0
	strings.write_string(&attr_names_msg, "Uniform names: ")
	for i < u32(count) {
		gl.GetActiveUniform(program_id, i, buf_size, &length, &size, &type, &name[0])
		strings.write_string(&attr_names_msg, string(name[0:length]))
		if i+1 < u32(count) {
			strings.write_string(&attr_names_msg, ", ")
		}
		i += 1
	}
	// log.info(strings.to_string(attr_names_msg))
}

init_texture_locations :: proc(shader: ^OpenGL_Shader) {
	count := get_program_iv(shader.program_id, gl.ACTIVE_UNIFORMS)

	buf_size := 16
	name : [16]byte
	length : i32 // name length

	size : i32 // size of the variable
	type : u32 // type of the variable

	i := 0
	texture_i := 0
	for i < count {
		gl.GetActiveUniform(shader.program_id, u32(i), i32(buf_size), &length, &size, &type, &name[0])
		if type == gl.SAMPLER_2D {
			// FIXME: this should be a map really rather than hard-coding texture names here
			// sampler_name := strings.string_from_ptr(&name[0], int(length))
			// switch sampler_name {
			// 	case "fontTexture":
			// 		shader.font_texture_idx = texture_i
			// 	case "paletteTexture":
			// 		shader.palette_texture_idx = texture_i
			// }
			texture_i += 1
		}
		i += 1
	}
}

// TODO: use GL debugging functionality if available
// Available from OpenGL 4.3
gl_debug_message_callback :: proc "c" (source: u32, type: u32, id: u32, severity: u32, length: i32, message: cstring, userParam: rawptr) {
	context = setup_context()
	if source == gl.DEBUG_SOURCE_APPLICATION {
		return
	}
	error_msg := strings.builder_make()
	defer strings.builder_destroy(&error_msg)
	strings.write_string(&error_msg, "GL problem: ")
	switch type {
	case gl.DEBUG_TYPE_ERROR:
		strings.write_string(&error_msg, "ERROR: \n")
	case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		strings.write_string(&error_msg, "DEPRECATED: \n")
	case gl.DEBUG_TYPE_PORTABILITY:
		strings.write_string(&error_msg, "PORTABILITY: \n")
	case gl.DEBUG_TYPE_PERFORMANCE:
		strings.write_string(&error_msg, "PERFORMANCE: \n")
	case gl.DEBUG_TYPE_OTHER:
		strings.write_string(&error_msg, "OTHER: \n")
	}
	message_string := strings.clone_from_cstring(message)
	defer free(&message_string)
	strings.write_string(&error_msg, message_string)
	log.error(strings.to_string(error_msg))
}

check_shader_compilation :: proc(shader_name: string, shader_id: u32) {
	compile_status : i32
	gl.GetShaderiv(shader_id, gl.COMPILE_STATUS, &compile_status)
	gl_true : i32 = 1
	if compile_status != gl_true {
		info_len : i32
		max_len :: 1024
		info_log : [max_len]u8
		gl.GetShaderInfoLog(shader_id, max_len, &info_len, &info_log[0])
		compile_error := info_log[0:info_len]
		log.errorf("Error compiling %s:\n%s", shader_name, compile_error)
		assert(compile_status == gl_true)
	}
}

get_program_info :: proc(program_id: u32, object_param: u32) -> (ok: bool, error: string) {
	ok = true
	status := get_program_iv(program_id, object_param)
	gl_true := 1
	if status != gl_true {
		ok = false
		info_len : i32
		max_len :: 1024
		info_log : [max_len]u8
		gl.GetProgramInfoLog(program_id, max_len, &info_len, &info_log[0])
		link_error := info_log[0:info_len]
		error = string(link_error)
	}
	return
}

check_shader_linking :: proc(program_id: u32) {
	link_status, link_error := get_program_info(program_id, gl.LINK_STATUS)
	if !link_status {
		log.errorf("Error linking shader program:\n%s", link_error)
	}
	assert(link_status)
}

check_shader_program_valid :: proc(program_id: u32) {
	gl.ValidateProgram(program_id)
	valid_status, valid_error := get_program_info(program_id, gl.VALIDATE_STATUS)
	if !valid_status {
		log.errorf("Error validating shader program:\n%s", valid_error)
	}
	assert(valid_status)
}

compile_shaders_to_program :: proc(vertex_shader_source: ^cstring, fragment_shader_source: ^cstring) -> (program_id: u32) {
	program_id = gl.CreateProgram()

	vertex_shader_id := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader_id, 1, vertex_shader_source, nil)
	gl.CompileShader(vertex_shader_id)
	when ODIN_DEBUG {
		check_shader_compilation("vertex shader", vertex_shader_id)
	}

	fragment_shader_id := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader_id, 1, fragment_shader_source, nil)
	gl.CompileShader(fragment_shader_id)
	when ODIN_DEBUG {
		check_shader_compilation("fragment shader", fragment_shader_id)
	}

	gl.AttachShader(program_id, vertex_shader_id)
	gl.AttachShader(program_id, fragment_shader_id)
	gl.LinkProgram(program_id)

	gl.DeleteShader(vertex_shader_id)
	gl.DeleteShader(fragment_shader_id)

	return
}

gl_max_texture_size : i32

setup_renderer_gl_4_1 :: proc(renderer: ^Renderer, gl_loader: Set_Proc_Address_Type) {
	gl.GetIntegerv(gl.MAX_TEXTURE_SIZE, &gl_max_texture_size)

	renderer_info := gl.GetString(gl.RENDERER)
	version := gl.GetString(gl.VERSION)
	log.infof("Renderer info: {}\n", renderer_info)
	log.infof("OpenGL version supported: {}\n", version)
}

resize_framebuffer_gl_4_1 :: proc(renderer: ^Renderer) {

}

render_gl_4_1 :: proc(renderer: ^Renderer) {

}

create_texture_gl_4_1 :: proc(renderer: ^Renderer, shader_idx: int, contents: [^]byte, width: int, height: int, color_format: Color_Format) -> int {
	texture_id : u32
	gl.GenTextures(1, &texture_id)
	gl.BindTexture(gl.TEXTURE_2D, texture_id)

	gl_format : int
	switch color_format {
	case .RED:
		gl_format = gl.RED
	case .RGB:
		gl_format = gl.RGB
	case .RGBA:
		gl_format = gl.RGBA
	}

	gl.TexImage2D(gl.TEXTURE_2D, 0, i32(gl_format), i32(width), i32(height), 0, u32(gl_format), gl.UNSIGNED_BYTE, contents)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

	renderer_texture_id := push_texture(renderer, OpenGL_Texture{opengl_id = texture_id, shader_idx = shader_idx, dim = v2s{width, height}})
	return renderer_texture_id
}

@(private="package")
vtable_renderer_gl_4_1 :: Renderer_VTable {
	impl_setup = setup_renderer_gl_4_1,
	impl_resize_framebuffer = resize_framebuffer_gl_4_1,
	impl_render = render_gl_4_1,
	impl_create_texture = create_texture_gl_4_1,
}
