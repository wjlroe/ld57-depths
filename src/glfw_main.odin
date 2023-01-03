package main

import "core:log"
import "core:os"
import "core:runtime"
import glfw "vendor:glfw"

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

main :: proc() {
	context = setup_context()

	glfw.SetErrorCallback(glfw_error_callback)

	if (glfw.Init() == 0) {
		log.error("GLFW failed to init!")
		glfw.Terminate()
		os.exit(1)
	}
	defer glfw.Terminate()
}
