package main

import "core:fmt"
import miniaudio "vendor:miniaudio"

Sound_Id :: enum {
    Thunderstorm,
    Shutter,
    Shutter_GX9,
}

Sound :: struct {
    id: Sound_Id,
    resource_name: string,
    data: []u8,
    sound: ^miniaudio.sound,
    decoder: ^miniaudio.decoder,
}

Sound_System :: struct {
    engine: miniaudio.engine,
    sounds: [len(Sound_Id)]Sound,
}

sound_system : Sound_System

init_sound_from_resources :: proc(sound: ^Sound) -> (ok: bool) {
    result : miniaudio.result
    // decoder_config : miniaudio.decoder_config
    // decoder_config.encodingFormat = cast(miniaudio.encoding_format)4
    sound.sound = new(miniaudio.sound)
    sound.decoder = new(miniaudio.decoder)
    resource, res_ok := &game.resources[sound.resource_name]
    if !res_ok {
        fail(fmt.tprintf("Cannot find %s in game resources", sound.resource_name))
        return
    }
    sound.data = make([]u8, len(resource.data))
    copy(sound.data, resource.data^)
    // result = miniaudio.decoder_init_memory(&sound.data[0], len(sound.data), &decoder_config, sound.decoder)
    result = miniaudio.decoder_init_memory(&sound.data[0], len(sound.data), nil, sound.decoder)
    if result != miniaudio.result.SUCCESS {
        fail(fmt.tprintf("Failed to decode sound: {}: {}", sound.resource_name, result))
        return
    }
    result = miniaudio.sound_init_from_data_source(
        &sound_system.engine,
        sound.decoder.pBackend,
        0,
        nil,
        sound.sound,
    )
    if result != miniaudio.result.SUCCESS {
        fail(fmt.tprintf("Failed to initialize sound: {}", sound.resource_name))
        return
    }
    ok = true
    return
}

uninit_sound :: proc(sound: ^Sound) {
    miniaudio.decoder_uninit(sound.decoder)
}

init_sound_system :: proc(game: ^Game, sound_system: ^Sound_System) -> (ok: bool) {
    result := miniaudio.engine_init(nil, &sound_system.engine)
    if result != miniaudio.result.SUCCESS {
        fail("Failed to initialize miniaudio engine")
        return
    }

    sound_system.sounds = [?]Sound{
        {
            id = .Thunderstorm,
            resource_name = "thunderstorm.ogg",
        },
        {
            id = .Shutter,
            resource_name = "olympus_em1_m3_125th.ogg",
        },
        {
            id = .Shutter_GX9,
            resource_name = "lumix_gx9_125th.ogg",
        },
    }

    for sound_id in Sound_Id {
        sound := &sound_system.sounds[sound_id]
        ok = init_sound_from_resources(sound)
        if !ok {
            fail(fmt.tprintf("Failed to init sound: {}", sound.resource_name))
            return
        }
    }

    ok = true
    return
}

uninit_sound_system :: proc(sound_system: ^Sound_System) {
    for sound_id in Sound_Id {
        sound := &sound_system.sounds[sound_id]
        uninit_sound(sound)
    }
    miniaudio.engine_uninit(&sound_system.engine)
}

play_sound :: proc(sound_system: ^Sound_System, which_sound: Sound_Id, loop: bool) {
	sound := sound_system.sounds[which_sound].sound
	level : f32 = 1.0
    miniaudio.sound_set_volume(sound, level)
    miniaudio.sound_set_looping(sound, b32(loop))
    miniaudio.sound_start(sound)
}

pause_sound :: proc(sound_system: ^Sound_System, which_sound: Sound_Id) {
	sound := sound_system.sounds[which_sound].sound
	miniaudio.sound_stop(sound)
}
