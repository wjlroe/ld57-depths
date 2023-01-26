package main

import "core:log"
import "core:os"
import miniaudio "vendor:miniaudio"

Sound_System :: struct {
    engine: miniaudio.engine,
    thunderstorm: miniaudio.sound,
}

sound_system : Sound_System

init_sound_system :: proc(sound_system: ^Sound_System) {
    result := miniaudio.engine_init(nil, &sound_system.engine)
    if result != miniaudio.result.SUCCESS {
        log.error("Failed to initialize miniaudio engine")
        os.exit(1)
    }

    miniaudio.sound_init_from_file(
        &sound_system.engine,
        "assets/thunderstorm.wav",
        0,
        nil,
        nil,
        &sound_system.thunderstorm,
    )
}

uninit_sound_system :: proc(sound_system: ^Sound_System) {
    miniaudio.engine_uninit(&sound_system.engine)
}
