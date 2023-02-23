package main

import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import glfw "vendor:glfw"
import miniaudio "vendor:miniaudio"

setup_context :: proc() -> runtime.Context {
	c := runtime.default_context()
	lowest_level := log.Level.Info
	when ODIN_DEBUG {
		lowest_level = log.Level.Debug
	}
	c.logger = log.create_console_logger(lowest = lowest_level)
	return c
}

glfw_error_callback :: proc "c" (error_code: i32, error_description: cstring) {
	context = setup_context()
	log.errorf("error (code: %d): %s", error_code, error_description)
}

window_size_callback :: proc "c" (handle: glfw.WindowHandle, width: i32, height: i32) {
}

framebuffer_size_callback :: proc "c" (handle: glfw.WindowHandle, width: i32, height: i32) {
}

window_content_scale_callback :: proc "c" (window_handle: glfw.WindowHandle, xscale, yscale: f32) {
}

window_pos_callback :: proc "c" (handle: glfw.WindowHandle, x, y: i32) {
}

window_key_callback :: proc "c" (handle: glfw.WindowHandle, key, scancode, action, mods: i32) {
}

window_char_callback :: proc "c" (handle: glfw.WindowHandle, codepoint: rune) {
	context = setup_context()

	if codepoint == 't' {
		if game.thunder_playing {
			pause_sound(&sound_system, .Thunderstorm)
			game.thunder_playing = false
		} else {
			play_sound(&sound_system, .Thunderstorm, true)
			game.thunder_playing = true
		}
	}
}

cursor_position_callback :: proc "c" (window_handle: glfw.WindowHandle, xpos, ypos: f64) {
}

mouse_button_callback :: proc "c" (window_handle: glfw.WindowHandle, button, action, mods: i32) {
	context = setup_context()

	if action == glfw.PRESS && mods == 0 {
		if button == glfw.MOUSE_BUTTON_LEFT {
			play_sound(&sound_system, .Shutter, false)
		} else if button == glfw.MOUSE_BUTTON_RIGHT {
			play_sound(&sound_system, .Shutter_GX9, false)
		}
	}
}

mouse_scroll_callback :: proc "c" (window_handle: glfw.WindowHandle, xoffset, yoffset: f64) {
}

// FIXME: this is specific to OpenGL
create_window :: proc(window: ^Window) -> (ok: bool) {
	opengl_renderer := window.renderer.variant.(^OpenGL_Renderer)
	glfw.WindowHint(glfw.SAMPLES, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, i32(opengl_renderer.opengl_version.major))
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, i32(opengl_renderer.opengl_version.minor))
	// FIXME: is forward_compat obsolete?
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.SCALE_TO_MONITOR, 1)
	glfw.WindowHint(glfw.RESIZABLE, 0)
	window.glfw_window_handle = glfw.CreateWindow(
		1280,
		800,
		game_title,
		nil,
		nil,
	)
	if (window.glfw_window_handle != nil) {
		ok = true
	}
	return
}

// FIXME: this is specific to OpenGL
create_window_with_opengl_version :: proc() -> (window: Window, ok: bool) {
	window.renderer.variant = new(OpenGL_Renderer)
	opengl_renderer := window.renderer.variant.(^OpenGL_Renderer)
	versions := []OpenGL_Version{{4,5},{4,1}}

	for version in versions {
		opengl_renderer.opengl_version = version
		ok = create_window(&window)
		if (ok) {
			break
		}
	}

	return
}

game : Game

main :: proc() {
	context = setup_context()

	init_debug_system(true)
	defer uninit_debug_system()

	glfw.SetErrorCallback(glfw_error_callback)

	if (glfw.Init() == 0) {
		log.error("GLFW failed to init!")
		glfw.Terminate()
		os.exit(1)
	}
	defer glfw.Terminate()

	glfw_major, glfw_minor, glfw_rev : i32 = glfw.GetVersion()
	log.infof("GLFW version: %d.%d.%d", glfw_major, glfw_minor, glfw_rev)

	window, window_created := create_window_with_opengl_version()
	if (!window_created) {
		log.error("Creating a window failed!")
		os.exit(1)
	}
	defer glfw.DestroyWindow(window.glfw_window_handle)
	window.keep_open = true

	{
		xscale, yscale := glfw.GetWindowContentScale(window.glfw_window_handle)
		window.content_scale = v2{xscale, yscale}
	}

	// Setup glfw callbacks (input, etc.)
	glfw.SetWindowSizeCallback(window.glfw_window_handle, window_size_callback)
	glfw.SetFramebufferSizeCallback(window.glfw_window_handle, framebuffer_size_callback)
	glfw.SetWindowContentScaleCallback(window.glfw_window_handle, window_content_scale_callback)
	glfw.SetWindowPosCallback(window.glfw_window_handle, window_pos_callback)
	glfw.SetKeyCallback(window.glfw_window_handle, window_key_callback)
	glfw.SetCharCallback(window.glfw_window_handle, window_char_callback)
	glfw.SetCursorPosCallback(window.glfw_window_handle, cursor_position_callback)
	glfw.SetMouseButtonCallback(window.glfw_window_handle, mouse_button_callback)
	glfw.SetScrollCallback(window.glfw_window_handle, mouse_scroll_callback)

	glfw.MakeContextCurrent(window.glfw_window_handle)

	{
		width, height := glfw.GetWindowSize(window.glfw_window_handle)
		window.window_dim = v2s{int(width), int(height)}
	}

	{
		width, height := glfw.GetFramebufferSize(window.glfw_window_handle)
		window.renderer.framebuffer_dim = v2s{int(width), int(height)}
		window.framebuffer_dim = v2s{int(width), int(height)}
	}

	// We only have one GL renderer, which assumes 4.1 for most stuff
	activate_gl_4_1(&window.renderer)
	window.renderer->impl_setup(glfw.gl_set_proc_address)

	init_game(&game, &window.renderer)
	defer uninit_game(&game)

	init_sound_system(&game, &sound_system)
	defer uninit_sound_system(&sound_system)

	glfw.SwapInterval(1)

	previous_frame_time := glfw.GetTime()

	for (window.keep_open) {
		if err := mem.free_all(context.temp_allocator); err != .None {
			log.errorf("temp_allocator.free_all err == {}", err);
        }
		frame_time := glfw.GetTime()
		dt := frame_time - previous_frame_time
		previous_frame_time = frame_time

		update_game(&game, dt)
		render_game(&game)
		window.renderer->impl_render()
		glfw.SwapBuffers(window.glfw_window_handle)
		glfw.PollEvents()
		window.renderer->impl_end_frame()

		if (cast(bool)glfw.WindowShouldClose(window.glfw_window_handle)) {
			window.keep_open = false
		}
	}

	log.info("Done")
}
