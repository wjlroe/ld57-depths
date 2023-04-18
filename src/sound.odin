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

init_sound_system :: proc(game: ^Game, sound_system: ^Sound_System) {
    result := miniaudio.engine_init(nil, &sound_system.engine)
    assert(result == miniaudio.result.SUCCESS)
    if result != miniaudio.result.SUCCESS {
        log.error("Failed to initialize miniaudio engine")
        os.exit(1)
    }

    miniaudio.sound_init_from_file(
    	&sound_system.engine,
    	"assets/olympus_em1_m3_125th.ogg",
    	0,
    	nil,
    	nil,
    	&sound_system.shutter,
    )

    sound_decoder := new(miniaudio.decoder)
    defer miniaudio.decoder_uninit(sound_decoder)
    {
        thunderstorm, ok := &game.resources["thunderstorm.ogg"]
        assert(ok, "Cannot find thunderstorm.ogg in game resources")
        result = miniaudio.decoder_init_memory(thunderstorm.data, len(thunderstorm.data), nil, sound_decoder)
        assert(result == miniaudio.result.SUCCESS)
        if result != miniaudio.result.SUCCESS {
            log.error("Failed to decode sound: thunderstorm.ogg: ", result)
            os.exit(1)
        }
        result = miniaudio.sound_init_from_data_source(
            &sound_system.engine,
            sound_decoder.pBackend,
            0,
            nil,
            &sound_system.thunderstorm,
        )
        assert(result == miniaudio.result.SUCCESS)
        if result != miniaudio.result.SUCCESS {
            log.error("Failed to initialize sound: thunderstorm.ogg")
            os.exit(1)
        }
    }

    // miniaudio.sound_init_from_file(
    //     &sound_system.engine,
    //     "assets/thunderstorm.ogg",
    //     0,
    //     nil,
    //     nil,
    //     &sound_system.thunderstorm,
    // )
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
    // TODO: uninit each sound?
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
