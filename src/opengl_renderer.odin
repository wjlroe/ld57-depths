package main

import "core:fmt"
import gl "vendor:OpenGL"
import "core:image"
import "core:log"
import "core:strings"

quad_vertex_shader_source := string(#load("shaders/quad_vert.glsl"))
quad_fragment_shader_source := string(#load("shaders/quad_frag.glsl"))
circle_fragment_shader_source := #load("shaders/circle_frag.glsl")

zero : uintptr = 0
zero_ptr := cast(rawptr)zero

frame_num := 0

OpenGL_Version :: struct {
	major: int,
	minor: int,
}

OpenGL_Uniform :: union {
	u32,
	i32,
	f32,
	v4,
	matrix[4,4]f32,
}

OpenGL_Texture :: struct {
	name: string,
	opengl_id: u32,
	dim: v2s,
}

OpenGL_Sampler :: struct {
	shader_idx: int,
	shader_location: u32,
}

OpenGL_Shader :: struct {
	name: string,
	program_id: u32,
	vao: u32,
	vbo: u32,
	ebo: u32,
	uniforms: map[string]u32,
	samplers: map[string]OpenGL_Sampler,
}

max_gl_shaders :: 16

OpenGL_Renderer :: struct {
	using renderer: Renderer,

	opengl_version: OpenGL_Version,
	gl_textures: map[int]OpenGL_Texture,
	shaders: [max_gl_shaders]OpenGL_Shader,
	num_shaders: int,
	quad_shader_id: int,
}

push_gl_shader :: proc(renderer: ^OpenGL_Renderer, shader: OpenGL_Shader) -> (shader_id: int) {
	assert(renderer.num_shaders < max_gl_shaders)
	shader_id = renderer.num_shaders
	renderer.shaders[shader_id] = shader
	renderer.num_shaders += 1
	return
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

program_attributes :: proc(shader: ^OpenGL_Shader) {
	program_id := shader.program_id
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

init_uniform_locations :: proc(shader: ^OpenGL_Shader) {
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
			sampler_name := strings.string_from_ptr(&name[0], int(length))
			sampler := OpenGL_Sampler {
				shader_idx = texture_i,
			}
			init_uniform_location(shader.program_id, &sampler.shader_location, cstring(&name[0]))
			shader.samplers[strings.clone(sampler_name)] = sampler
			// switch sampler_name {
			// 	case "fontTexture":
			// 		shader.font_texture_idx = texture_i
			// 	case "paletteTexture":
			// 		shader.palette_texture_idx = texture_i
			// }
			texture_i += 1
		} else {
			uniform_name := strings.string_from_ptr(&name[0], int(length))
			location : u32
			init_uniform_location(shader.program_id, &location, cstring(&name[0]))
			shader.uniforms[strings.clone(uniform_name)] = location
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
	defer delete(message_string)
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
		link_error := string(info_log[0:info_len])
		error = strings.clone(link_error)
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

compile_shaders_to_program :: proc(shader: ^OpenGL_Shader, vertex_shader_source: string, fragment_shader_source: string) {
	shader.program_id = gl.CreateProgram()

	vertex_shader_id := gl.CreateShader(gl.VERTEX_SHADER)
	vertex_shader_source_cstr := strings.clone_to_cstring(vertex_shader_source)
	defer delete(vertex_shader_source_cstr)
	gl.ShaderSource(vertex_shader_id, 1, &vertex_shader_source_cstr, nil)
	gl.CompileShader(vertex_shader_id)
	when ODIN_DEBUG {
		check_shader_compilation("vertex shader", vertex_shader_id)
	}

	fragment_shader_id := gl.CreateShader(gl.FRAGMENT_SHADER)
	fragment_shader_source_cstr := strings.clone_to_cstring(fragment_shader_source)
	defer delete(fragment_shader_source_cstr)
	gl.ShaderSource(fragment_shader_id, 1, &fragment_shader_source_cstr, nil)
	gl.CompileShader(fragment_shader_id)
	when ODIN_DEBUG {
		check_shader_compilation("fragment shader", fragment_shader_id)
	}

	gl.AttachShader(shader.program_id, vertex_shader_id)
	gl.AttachShader(shader.program_id, fragment_shader_id)
	gl.LinkProgram(shader.program_id)

	gl.DeleteShader(vertex_shader_id)
	gl.DeleteShader(fragment_shader_id)
}

gl_max_texture_size : i32

setup_renderer_gl_4_1 :: proc(renderer: ^Renderer, gl_loader: Set_Proc_Address_Type) {
	opengl_renderer := renderer.variant.(^OpenGL_Renderer)
	gl.load_up_to(opengl_renderer.opengl_version.major, opengl_renderer.opengl_version.minor, gl_loader)

	quad_shader := OpenGL_Shader {
		name = "quad_shader",
	}
	compile_shaders_to_program(&quad_shader, quad_vertex_shader_source, quad_fragment_shader_source)
	program_attributes(&quad_shader)
	init_uniform_locations(&quad_shader)
	{
		quad_vertices := [?]f32{
			-1.0, 1.0, 0.0, 0.0, // 0: top-left
			-1.0, -1.0, 0.0, 1.0, // 1: bottom-left
			1.0, -1.0, 1.0, 1.0, // 2: bottom-right
			1.0, 1.0, 1.0, 0.0, // 3: top-right
		}

		quad_indices := [?]u32{
			0, 1, 2, 2, 3, 0,
		}

		quad_pos_len := 2
		quad_tex_len := 2
		quad_stride := quad_pos_len + quad_tex_len

		pos_loc := 0
		tex_loc := 1
		gl.GenVertexArrays(1, &quad_shader.vao)
		gl.GenBuffers(1, &quad_shader.vbo)
		gl.BindVertexArray(quad_shader.vao)
		gl.BindBuffer(gl.ARRAY_BUFFER, quad_shader.vbo)
		gl.BufferData(gl.ARRAY_BUFFER, quad_stride * len(quad_vertices) * size_of(type_of(quad_vertices[0])), &quad_vertices, gl.STATIC_DRAW)
		gl.GenBuffers(1, &quad_shader.ebo)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, quad_shader.ebo)
		gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(quad_indices) * size_of(type_of(quad_indices[0])), &quad_indices, gl.STATIC_DRAW)

		gl.VertexAttribPointer(u32(pos_loc), i32(quad_pos_len), gl.FLOAT, gl.FALSE, i32(quad_stride * size_of(type_of(quad_vertices[0]))), zero)
		gl.EnableVertexAttribArray(u32(pos_loc))

		gl.VertexAttribPointer(u32(tex_loc), i32(quad_tex_len), gl.FLOAT, gl.FALSE, i32(quad_stride * size_of(type_of(quad_vertices[0]))), uintptr(quad_pos_len * size_of(type_of(quad_vertices[0]))))
		gl.EnableVertexAttribArray(u32(tex_loc))

		when ODIN_DEBUG {
			// NOTE: macOS needs the VAO to be bound before validating the shader
			check_shader_linking(quad_shader.program_id)
			check_shader_program_valid(quad_shader.program_id)
		}

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
		gl.BindVertexArray(0)
	}
	opengl_renderer.quad_shader_id = push_gl_shader(opengl_renderer, quad_shader)

	gl.GetIntegerv(gl.MAX_TEXTURE_SIZE, &gl_max_texture_size)

	renderer_info := gl.GetString(gl.RENDERER)
	version := gl.GetString(gl.VERSION)
	log.infof("Renderer info: {}\n", renderer_info)
	log.infof("OpenGL version supported: {}\n", version)

	viewport : [4]i32
	gl.GetIntegerv(gl.VIEWPORT, &viewport[0])
	log.infof("Viewport: {}, framebuffer_dim: {}\n", viewport, renderer.framebuffer_dim)

	// FIXME: we shouldn't be ignoring that viewport we read above, we should be saving it here?
	renderer.viewport = rectangle2{{0, 0}, {f32(renderer.framebuffer_dim.x), f32(renderer.framebuffer_dim.y)}}
	gl.Viewport(0, 0, i32(renderer.framebuffer_dim.x), i32(renderer.framebuffer_dim.y))

	reset_ortho_projection(renderer)
}

resize_framebuffer_gl_4_1 :: proc(renderer: ^Renderer) {
	// FIXME: we shouldn't be ignoring that viewport we read above, we should be saving it here?
	renderer.viewport = rectangle2{{0, 0}, {f32(renderer.framebuffer_dim.x), f32(renderer.framebuffer_dim.y)}}
	gl.Viewport(0, 0, i32(renderer.framebuffer_dim.x), i32(renderer.framebuffer_dim.y))
	reset_ortho_projection(renderer)
}

bind_gl_uniform :: proc(location: u32, uniform: OpenGL_Uniform) {
	switch data in uniform {
		case u32:
		gl.Uniform1ui(i32(location), u32(data))
		case i32:
		gl.Uniform1i(i32(location), data)
		case f32:
		gl.Uniform1f(i32(location), data)
		case v4:
		my_data := data
		gl.Uniform4fv(i32(location), 1, &my_data[0])
		case matrix[4,4]f32:
		my_data := data
		gl.UniformMatrix4fv(i32(location), 1, gl.FALSE, &my_data[0][0])
	}
}

gl_version_available :: proc(renderer: ^OpenGL_Renderer, version: OpenGL_Version) -> bool {
	if renderer.opengl_version.major > version.major {
		return true
	}
	if renderer.opengl_version.major < version.major {
		return false
	}
	return renderer.opengl_version.minor >= version.minor
}

gl_push_debug :: proc(renderer: ^OpenGL_Renderer, text: cstring) {
	if gl_version_available(renderer, OpenGL_Version{4, 5}) {
		gl.PushDebugGroup(gl.DEBUG_SOURCE_APPLICATION, 1, -1, text)
	}
}

gl_pop_debug :: proc(renderer: ^OpenGL_Renderer) {
	if gl_version_available(renderer, OpenGL_Version{4, 5}) {
		gl.PopDebugGroup()
	}
}

render_gl_4_1 :: proc(renderer: ^Renderer) {
	frame_num += 1
	opengl_renderer := renderer.variant.(^OpenGL_Renderer)
	for _, i in renderer.render_groups {
		group := &renderer.render_groups[i]

		when ODIN_DEBUG {
			if len(group.debug_name) > 0 {
				gl_push_debug(opengl_renderer, group.debug_name)
			}
		}

		if .ClearColor in group.settings {
			clear_bits : u32 = gl.COLOR_BUFFER_BIT
			if .ClearDepth in group.settings {
				clear_bits |= gl.DEPTH_BUFFER_BIT
			}
			color := group.data.(v4)
			gl.ClearColor(color.r, color.g, color.b, color.a)
			gl.Clear(clear_bits)
		}

		if .Viewport in group.settings {
			viewport := group.data.(rectangle2s)
			viewport_width := rect_width(viewport)
			viewport_height := rect_height(viewport)
			gl.Viewport(i32(viewport.min.x), i32(viewport.min.y), i32(viewport_width), i32(viewport_height))
		}

		if .QuadShader in group.settings {
			shader_id := opengl_renderer.quad_shader_id
			assert(shader_id < len(opengl_renderer.shaders))
			shader := &opengl_renderer.shaders[shader_id]

			gl.UseProgram(u32(shader.program_id))

			if .DepthTesting in group.settings {
				gl.Enable(gl.DEPTH_TEST)
				gl.DepthFunc(gl.LESS)
			} else {
				gl.Disable(gl.DEPTH_TEST)
			}
			if .AlphaBlending in group.settings {
				gl.Enable(gl.BLEND)
				gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
			} else {
				gl.Disable(gl.BLEND)
			}
			if .FaceCulling in group.settings {
				gl.Enable(gl.CULL_FACE)
			} else {
				gl.Disable(gl.CULL_FACE)
			}

			gl.BindVertexArray(shader.vao)

			for uniform_data in group.uniforms[:group.num_uniforms] {
				switch uniform_data.setting {
					case .Texture:
						texture_id := uniform_data.data.(int)
						gl_texture := opengl_renderer.gl_textures[texture_id]
						gl.BindTexture(gl.TEXTURE_2D, gl_texture.opengl_id)
					case .Z:
						loc, ok := shader.uniforms["u_Z"]
						if !ok {
							log.error("no u_Z uniform location!")
						}
						bind_gl_uniform(loc, uniform_data.data.(f32))
					case .Texture_Transform:
						loc, ok := shader.uniforms["tex_transform"]
						if !ok {
							log.error("no tex_transform uniform location!")
						}
						transform := uniform_data.data.(matrix[4,4]f32)
						bind_gl_uniform(loc, transform)
				}
			}

			{
				loc, ok := shader.uniforms["ortho_transform"]
				if !ok {
					log.error("no ortho_transform uniform location!")
				}
				bind_gl_uniform(loc, renderer.ortho_projection)
			}

			{
				loc, ok := shader.uniforms["color"]
				if !ok {
					log.error("no color uniform location!")
				}
				bind_gl_uniform(loc, color_red)
			}

			{
				loc, ok := shader.uniforms["sample_texture"]
				if !ok {
					log.error("no sample_texture location!")
				}
				bind_gl_uniform(loc, i32(2))
			}

			{
				sampler, ok := shader.samplers["texture1"]
				if !ok {
					log.error("no texture1! sampler!")
				}
				bind_gl_uniform(sampler.shader_location, i32(sampler.shader_idx))
				gl.ActiveTexture(u32(gl.TEXTURE0 + sampler.shader_idx))
			}

			for quad in group.data.([]Quad) {
				assert(rect_width(quad.position) > 0.0)
				assert(rect_height(quad.position) > 0.0)
				pos_transform := screen_transform_for_position(quad.position, renderer.viewport)
				debug_only_once(fmt.tprintf("{}.quad.position", group.debug_name), fmt.tprintf("{}", quad.position), fmt.tprintf("Frame: {}", frame_num))
				debug_only_once(fmt.tprintf("{}.pos_transform", group.debug_name), fmt.tprintf("{}", pos_transform), fmt.tprintf("Frame: {}", frame_num))
				// debug_only_once(fmt.tprintf("{}.pos_transform(2)", group.debug_name), fmt.tprintf("{}", pos_transform), fmt.tprintf("Frame: {}", frame_num))
				// if pos_transform[0][0] == 0.0 {
				// 	log.error("zero matrix!")
				// }
				{
					pos_uniform, ok := shader.uniforms["pos_transform"]
					if !ok {
						log.error("no pos_transform uniform location!")
					}
					bind_gl_uniform(pos_uniform, pos_transform)
				}

				gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
			}
		} else {
			// log.debug("not a quad?")
		}

		when ODIN_DEBUG {
			if len(group.debug_name) > 0 {
				gl_pop_debug(opengl_renderer)
			}
		}
	}

	gl.Flush()
}

// FIXME: work from the Texture inside Renderer, rather than unpacking it into arguments here
create_texture_gl_4_1 :: proc(renderer: ^Renderer, texture_name: string, image: ^image.Image, color_format: Color_Format) {
	opengl_renderer := renderer.variant.(^OpenGL_Renderer)
	texture := &renderer.textures[texture_name]
	opengl_texture := OpenGL_Texture{
		dim = v2s{image.width, image.height},
	}
	gl.GenTextures(1, &opengl_texture.opengl_id)
	gl.BindTexture(gl.TEXTURE_2D, opengl_texture.opengl_id)

	gl_format : int
	switch color_format {
	case .RED:
		gl_format = gl.RED
	case .RGB:
		gl_format = gl.RGB
	case .RGBA:
		gl_format = gl.RGBA
	}

	gl.TexImage2D(gl.TEXTURE_2D, 0, i32(gl_format), i32(image.width), i32(image.height), 0, u32(gl_format), gl.UNSIGNED_BYTE, &image.pixels.buf[0])
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	opengl_renderer.gl_textures[texture.id] = opengl_texture
}

activate_gl_4_1 :: proc(renderer: ^Renderer) {
	renderer.renderer_vtable = vtable_renderer_gl_4_1
	renderer.name = "OpenGL"
	// renderer.variant = new(OpenGL_Renderer)
}

@(private="package")
vtable_renderer_gl_4_1 :: Renderer_VTable {
	impl_setup = setup_renderer_gl_4_1,
	impl_resize_framebuffer = resize_framebuffer_gl_4_1,
	impl_render = render_gl_4_1,
	impl_create_texture = create_texture_gl_4_1,
	impl_end_frame = renderer_end_frame,
}
