package main

import "base:runtime"
import "core:path/filepath"
import "core:log"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

game_title :: "Base Code"
DEFAULT_WINDOW_WIDTH  :: 1280
DEFAULT_WINDOW_HEIGHT :: 800

floor_tiles_image := #load("../assets/floor_tiles.png")
runner_image := #load("../assets/runner.png")
thunderstorm_sound := #load("../assets/thunderstorm.ogg")
oly_shutter_sound := #load("../assets/olympus_em1_m3_125th.ogg")
lumix_shutter_sound := #load("../assets/lumix_gx9_125th.ogg")

Resource_Type :: enum {
    RESOURCE_NONE,
    RESOURCE_SOUND,
    RESOURCE_IMAGE,
}

Resource :: struct {
    type: Resource_Type,
    filename: string,
    data: ^[]byte,
    rl_data: union { rl.Texture2D, rl.Sound },
}

load_image_resource :: proc(resource: ^Resource) -> (ok: bool) {
    extension := strings.clone_to_cstring(filepath.ext(resource.filename), context.temp_allocator)
    image := rl.LoadImageFromMemory(extension, &resource.data[0], i32(len(resource.data)))
    if !rl.IsImageReady(image) {
        log.errorf("Image is not ready: {}", resource.filename)
        assert(false)
        return
    }
    resource.rl_data = rl.LoadTextureFromImage(image)
    ok = true
    return
}

load_sound_resource :: proc(resource: ^Resource) -> (ok: bool) {
    extension := strings.clone_to_cstring(filepath.ext(resource.filename), context.temp_allocator)
    wave := rl.LoadWaveFromMemory(extension, &resource.data[0], i32(len(resource.data)))
    if !rl.IsWaveReady(wave) {
        log.errorf("Wave is not ready: {}", resource.filename)
        assert(false)
        return
    }
    sound := rl.LoadSoundFromWave(wave)
    // TODO: rl.UnloadWave(wave)?
    if !rl.IsSoundReady(sound) {
        log.errorf("Sound is not ready: {}", resource.filename)
        assert(false)
        return
    }
    resource.rl_data = sound
    ok = true
    return
}

load_resource :: proc(resource: ^Resource) -> bool {
    #partial switch resource.type {
        case .RESOURCE_IMAGE: return load_image_resource(resource)
        case .RESOURCE_SOUND: return load_sound_resource(resource)
    }
    log.errorf("Unknown resource type")
    return false
}

dim_from_texture :: proc(texture: rl.Texture2D) -> rl.Vector2 {
    return rl.Vector2{f32(texture.width), f32(texture.height)}
}

setup_context :: proc() -> runtime.Context {
    c := runtime.default_context()
    lowest_level := log.Level.Info
    when ODIN_DEBUG {
        lowest_level = log.Level.Debug
    }
    c.logger = log.create_console_logger(lowest = lowest_level)
    return c
}

Font :: struct {
    font: rl.Font,
    size: f32,
}

Game_State :: enum {
    STATE_TITLE,
}

Game_Window :: struct {
    game_state: Game_State,
    resources: map[string]Resource,

    title_font: Font,
    menu_font: Font,

    floor_tiles_sprite: Sprite,
    runner_sprite: Sprite,
    thunder_playing: bool,

    debug_font: Font,

    dim: rl.Vector2,

    quit: bool,
}

@(require)
game_window := Game_Window{}

update_window_dim :: proc() {
    // We use screen functions here because GetRenderWidth is broken on macos (deliberately!)
    game_window.dim.x = f32(rl.GetScreenWidth())
    game_window.dim.y = f32(rl.GetScreenHeight())
}

init_game :: proc() -> bool {
    update_window_dim()

    game_window.resources = map[string]Resource{
       "floor_tiles.png" =  Resource {
            type = .RESOURCE_IMAGE,
            filename = "floor_tiles.png",
            data = &floor_tiles_image,
        },
        "runner.png" = Resource {
            type = .RESOURCE_IMAGE,
            filename = "runner.png",
            data = &runner_image,
        },
        "thunderstorm.ogg" = Resource {
            type = .RESOURCE_SOUND,
            filename = "thunderstorm.ogg",
            data = &thunderstorm_sound,
        },
        "olympus_em1_m3_125th.ogg" = Resource {
            type = .RESOURCE_SOUND,
            filename = "olympus_em1_m3_125th.ogg",
            data = &oly_shutter_sound,
        },
        "lumix_gx9_125th.ogg" = Resource {
            type = .RESOURCE_SOUND,
            filename = "lumix_gx9_125th.ogg",
            data = &lumix_shutter_sound,
        },
    }

    for resource_key in game_window.resources {
        if !load_resource(&game_window.resources[resource_key]) {
            log.errorf("Error loading resource with key: {}", resource_key)
            assert(false)
        }
    }

    floor_texture_dim := dim_from_texture(game_window.resources["floor_tiles.png"].rl_data.(rl.Texture2D))
    game_window.floor_tiles_sprite = Sprite {
        debug_name = "floor_tile",
        texture_name = "floor_tiles.png",
        frames = []Frame{
            Frame{
               duration = 100.0,
               name = "frame",
               rect = rl.Rectangle{0, 0, 64, 64},
            },
        },
        frame_dim = floor_texture_dim,
        resource = &game_window.resources["floor_tiles.png"],
    }

    runner_texture_dim := dim_from_texture(game_window.resources["runner.png"].rl_data.(rl.Texture2D))
    game_window.runner_sprite = Sprite {
        debug_name = "runner",
        texture_name = "runner.png",
        resource = &game_window.resources["runner.png"],
    }
    split_into_frames(&game_window.runner_sprite, 4, 4, 0.04)

    return true
}

update_and_render :: proc(dt: f32) {
    update_sprite(&game_window.runner_sprite, dt)

    rl.BeginDrawing()
    rl.ClearBackground(color_blue)
    {
        tile_size := f32(game_window.floor_tiles_sprite.frame_dim.x * 2)
        dest := rl.Rectangle{100.0, 100.0, tile_size, tile_size}
        draw_sprite(&game_window.floor_tiles_sprite, dest, rl.WHITE)
    }
    rl.EndDrawing()
}

process_input :: proc() {
    // TODO: press 't' to play/pause the thunder sound file
    // TODO: mouse click left (without modifiers) -> play shutter sound
    // TODO: mouse click right (without modifiers) -> play GX9 shutter sound

    if rl.WindowShouldClose() {
        game_window.quit = true
    }
}

main :: proc() {
	context = setup_context()

    init_debug_system(true)
    defer uninit_debug_system()

    rl.InitAudioDevice()
    rl.InitWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT,  game_title)
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

        dt := rl.GetFrameTime()
        process_input()
        update_and_render(dt)
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}
