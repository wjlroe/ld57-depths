package main

import "core:log"
import "core:os"
import rl "vendor:raylib"

DEFAULT_WINDOW_WIDTH  :: 1280
DEFAULT_WINDOW_HEIGHT :: 800

main :: proc() {
	lowest_level := log.Level.Info
	when ODIN_DEBUG {
		lowest_level = log.Level.Debug
	}
	context.logger = log.create_console_logger(lowest = lowest_level)

    rl.InitWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT,  "Ludum Dare 55: Summoning")
    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    if !init_game() {
        os.exit(1)
    }

    log.infof("going to start the render loop")
    log.infof("DPI: {}", rl.GetWindowScaleDPI())
    log.infof("Screen: {}x{}", rl.GetScreenWidth(), rl.GetScreenHeight())
    log.infof("Render: {}x{}", rl.GetRenderWidth(), rl.GetRenderHeight())

    for !game_window.quit {
		if err := free_all(context.temp_allocator); err != .None {
			log.errorf("temp_allocator.free_all err == {}", err);
        }

        game_window.dt = rl.GetFrameTime()
        process_input()
        update_and_render()
    }

    rl.CloseWindow()
}
