package main

import "core:log"
import "core:os"
import miniaudio "vendor:miniaudio"

Sound_System :: struct {
    engine: miniaudio.engine,
    thunderstorm: miniaudio.sound,
    shutter: miniaudio.sound,
    shutter_gx9: miniaudio.sound,
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
        "assets/thunderstorm.ogg",
        0,
        nil,
        nil,
        &sound_system.thunderstorm,
    )
    miniaudio.sound_init_from_file(
    	&sound_system.engine,
    	"assets/olympus_em1_m3_125th.ogg",
    	0,
    	nil,
    	nil,
    	&sound_system.shutter,
    )
    miniaudio.sound_init_from_file(
    	&sound_system.engine,
    	"assets/lumix_gx9_125th.ogg",
    	0,
    	nil,
    	nil,
    	&sound_system.shutter_gx9,
    )
}

uninit_sound_system :: proc(sound_system: ^Sound_System) {
    miniaudio.engine_uninit(&sound_system.engine)
}

Which_Sound :: enum {
	Thunderstorm,
	Shutter,
	Shutter_GX9,
}

play_sound :: proc(sound_system: ^Sound_System, which_sound: Which_Sound, loop: bool) {
	sound : ^miniaudio.sound
	level : f32 = 1.0
	switch which_sound {
		case .Thunderstorm: sound = &sound_system.thunderstorm
		case .Shutter: sound = &sound_system.shutter
		case .Shutter_GX9:
			sound = &sound_system.shutter_gx9
			level = 0.1
	}
    miniaudio.sound_set_volume(sound, level)
    miniaudio.sound_set_looping(sound, b32(loop))
    miniaudio.sound_start(sound)
}

pause_sound :: proc(sound_system: ^Sound_System, which_sound: Which_Sound) {
	sound : ^miniaudio.sound
	switch which_sound {
		case .Thunderstorm: sound = &sound_system.thunderstorm
		case .Shutter: sound = &sound_system.shutter
		case .Shutter_GX9: sound = &sound_system.shutter_gx9
	}
	miniaudio.sound_stop(sound)
}
