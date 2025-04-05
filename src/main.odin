package main

import "base:runtime"
import "core:path/filepath"
import "core:log"
import "core:os"
import "core:slice"
import "core:container/small_array"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

game_title :: "Depths"
DEFAULT_WINDOW_WIDTH  :: 1280
DEFAULT_WINDOW_HEIGHT :: 800

liberation_serif_regular := #load("../assets/fonts/liberation_serif/LiberationSerif-Regular.ttf")

neo_zero_buildings_02 := #load("../assets/neo_zero/neo_zero_buildings_02.png")
neo_zero_props_02_free := #load("../assets/neo_zero/neo_zero_props_02_free.png")
neo_zero_tileset_02 := #load("../assets/neo_zero/neo_zero_tileset_02.png")
neo_zero_buildings__lights_off_02 := #load("../assets/neo_zero/neo_zero_buildings__lights_off_02.png")
neo_zero_dungeon_02 := #load("../assets/neo_zero/neo_zero_dungeon_02.png")
neo_zero_props_02 := #load("../assets/neo_zero/neo_zero_props_02.png")
neo_zero_char_01 := #load("../assets/neo_zero/neo_zero_char_01.png")
neo_zero_props_and_items_01 := #load("../assets/neo_zero/neo_zero_props_and_items_01.png")
neo_zero_tiles_and_buildings_01 := #load("../assets/neo_zero/neo_zero_tiles_and_buildings_01.png")

rect_min_dim :: proc(min, dim: rl.Vector2) -> rl.Rectangle {
    return rl.Rectangle{
        min.x,
        min.y,
        dim.x,
        dim.y,
    }
}

hex_to_int :: proc(hex: string) -> (n: u8, ok: bool) {
    number : u64
    number, ok = strconv.parse_u64_of_base(hex, 16)
    if number < 256 {
        n = u8(number)
        ok = true
        return
    }
    return
}

color_from_hex :: proc(hex: string) -> rl.Color {
    r, g, b : u8
    ok : bool
    r, ok = hex_to_int(hex[1:3])
    assert(ok)
    g, ok = hex_to_int(hex[3:5])
    assert(ok)
    b, ok = hex_to_int(hex[5:7])
    assert(ok)
    return {r, g, b, 255}
}

color_red := color_from_hex("#ff0000")
color_green := color_from_hex("#00ff00")
color_blue := color_from_hex("#0000ff")
color_black := color_from_hex("#000000")
color_grey := color_from_hex("#ededed")
color_pink := color_from_hex("#ec39c6")
color_navy := color_from_hex("#3636cc")
color_gold := color_from_hex("#ffd700")
color_yellow := color_from_hex("#ffff00")
color_original := color_from_hex("#ffffff")

Resource_Type :: enum {
    RESOURCE_NONE,
    RESOURCE_SOUND,
    RESOURCE_IMAGE,
    RESOURCE_FONT,
}

Resource :: struct {
    type: Resource_Type,
    filename: string,
    data: ^[]byte,
    rl_data: union { rl.Texture2D, rl.Sound, Font },
    size: rl.Rectangle, // for textures/images
    tileset: bool,
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
    resource.size = {0, 0, f32(image.width), f32(image.height)}
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
    if !rl.IsSoundReady(sound) {
        log.errorf("Sound is not ready: {}", resource.filename)
        assert(false)
        return
    }
    rl.UnloadWave(wave)
    resource.rl_data = sound
    ok = true
    return
}

load_font_resource :: proc(resource: ^Resource) -> (ok: bool) {
    font := &resource.rl_data.(Font)
    extension := strings.clone_to_cstring(filepath.ext(resource.filename), context.temp_allocator)
    font.font = rl.LoadFontFromMemory(extension, &resource.data[0], i32(len(resource.data)), i32(font.size), nil, -1)
    assert(rl.IsFontReady(font.font))
    ok = true
    return
}

load_resource :: proc(resource: ^Resource) -> bool {
    #partial switch resource.type {
        case .RESOURCE_IMAGE: return load_image_resource(resource)
        case .RESOURCE_SOUND: return load_sound_resource(resource)
        case .RESOURCE_FONT:  return load_font_resource(resource)
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

Frame :: struct {
    duration: f32,
    name: string,
    rect: rl.Rectangle,
    coords: rl.Vector2,
}

// TODO: parse sprite JSON from aseprite
Sprite :: struct {
    debug_name: cstring,
    texture_name: string,
    frames: []Frame,
    num_frames: int,
    current_frame: int,
    frame_time: f32,
    frame_dim: rl.Vector2,
    resource: ^Resource,
}

draw_sprite :: proc(sprite: ^Sprite, destination: rl.Rectangle, tint: rl.Color) {
    current_frame := sprite.frames[sprite.current_frame]
    origin := rl.Vector2{}
    rotation : f32 = 0.0
    rl.DrawTexturePro(sprite.resource.rl_data.(rl.Texture2D), current_frame.rect, destination, origin, rotation, tint)
}

split_into_frames :: proc(sprite: ^Sprite, num_x: int, num_y: int, duration: f32) {
    texture := sprite.resource.rl_data.(rl.Texture2D)
    sprite.frame_dim.x = f32(texture.width) / f32(num_x)
    sprite.frame_dim.y = f32(texture.height) / f32(num_y)
    sprite.num_frames = num_x * num_y
    sprite.frames = make([]Frame, sprite.num_frames)
    for y in 0..<num_y {
        for x in 0..<num_x {
            idx := num_y * y + x
            sprite.frames[idx].duration = duration
            sprite.frames[idx].rect = rect_min_dim(rl.Vector2{f32(x) * sprite.frame_dim.x, f32(y) * sprite.frame_dim.y}, sprite.frame_dim)
            sprite.frames[idx].coords = rl.Vector2{f32(x), f32(y)}
        }
    }
}

update_sprite :: proc(sprite: ^Sprite, dt: f32) {
    current_frame := sprite.frames[sprite.current_frame]
    new_time := sprite.frame_time + dt
    if new_time > current_frame.duration {
        overflow := new_time - current_frame.duration
        sprite.current_frame = (sprite.current_frame + 1) % sprite.num_frames
        sprite.frame_time = overflow
    } else {
        sprite.frame_time = new_time
    }
}

Game_State :: enum {
    STATE_TITLE,
    STATE_MENU,
    STATE_LEVEL,
}

Game_Window :: struct {
    game_state: Game_State,
    resources: map[string]Resource,

    title_font: Font,
    menu_font: Font,

    title_resource: cstring,

    floor_tiles_sprite: Sprite,
    runner_sprite: Sprite,
    thunder_playing: bool,

    menu: Menu,

    debug_font: Font,

    rect: rl.Rectangle,

    quit: bool,
}

@(require)
game_window := Game_Window{}

update_window_dim :: proc() {
    // We use screen functions here because GetRenderWidth is broken on macos (deliberately!)
    game_window.rect.width = f32(rl.GetScreenWidth())
    game_window.rect.height = f32(rl.GetScreenHeight())
}

init_game :: proc() -> bool {
    update_window_dim()
    setup_main_menu()

    game_window.resources["neo_zero_buildings_02.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_buildings_02.png",
        data = &neo_zero_buildings_02,
        tileset = true,
    }
    game_window.resources["neo_zero_props_02_free.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_props_02_free.png",
        data = &neo_zero_props_02_free,
        tileset = true,
    }
    game_window.resources["neo_zero_tileset_02.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_tileset_02.png",
        data = &neo_zero_tileset_02,
        tileset = true,
    }
    game_window.resources["neo_zero_buildings__lights_off_02.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_buildings__lights_off_02.png",
        data = &neo_zero_buildings__lights_off_02,
        tileset = true,
    }
    game_window.resources["neo_zero_dungeon_02.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_dungeon_02.png",
        data = &neo_zero_dungeon_02,
        tileset = true,
    }
    game_window.resources["neo_zero_props_02.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_props_02.png",
        data = &neo_zero_props_02,
        tileset = true,
    }
    game_window.resources["neo_zero_char_01.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_char_01.png",
        data = &neo_zero_char_01,
        tileset = true,
    }
    game_window.resources["neo_zero_props_and_items_01.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_props_and_items_01.png",
        data = &neo_zero_props_and_items_01,
        tileset = true,
    }
    game_window.resources["neo_zero_tiles_and_buildings_01.png"] = Resource {
        type = .RESOURCE_IMAGE,
        filename = "neo_zero_tiles_and_buildings_01.png",
        data = &neo_zero_tiles_and_buildings_01,
        tileset = true,
    }
    game_window.resources["title_font"] = Resource {
        type = .RESOURCE_FONT,
        filename = "LiberationSerif-Regular.ttf",
        data = &liberation_serif_regular,
        rl_data = Font { size = 220.0 },
    }
    game_window.resources["menu_font"] = Resource {
        type = .RESOURCE_FONT,
        filename = "LiberationSerif-Regular.ttf",
        data = &liberation_serif_regular,
        rl_data = Font { size = 80.0 },
    }
    game_window.resources["info_font"] = Resource {
        type = .RESOURCE_FONT,
        filename = "LiberationSerif-Regular.ttf",
        data = &liberation_serif_regular,
        rl_data = Font { size = 48.0 },
    }
    game_window.title_resource = strings.clone_to_cstring("neo_zero_buildings_02.png")

    for resource_key in game_window.resources {
        if !load_resource(&game_window.resources[resource_key]) {
            log.errorf("Error loading resource with key: {}", resource_key)
            assert(false)
        }
    }
    // {
    //     // Play+pause thunderstorm so that it can be resumed and paused later
    //     thunderstorm := game_window.resources["thunderstorm.ogg"].rl_data.(rl.Sound)
    //     rl.PlaySound(thunderstorm)
    //     rl.PauseSound(thunderstorm)
    // }

    // floor_texture_dim := dim_from_texture(game_window.resources["floor_tiles.png"].rl_data.(rl.Texture2D))
    // game_window.floor_tiles_sprite = Sprite {
    //     debug_name = "floor_tile",
    //     texture_name = "floor_tiles.png",
    //     frames = []Frame{
    //         Frame{
    //            duration = 100.0,
    //            name = "frame",
    //            rect = rl.Rectangle{0, 0, 64, 64},
    //         },
    //     },
    //     frame_dim = floor_texture_dim,
    //     resource = &game_window.resources["floor_tiles.png"],
    // }
    // split_into_frames(&game_window.floor_tiles_sprite, 1, 1, 0.0)

    // runner_texture_dim := dim_from_texture(game_window.resources["runner.png"].rl_data.(rl.Texture2D))
    // game_window.runner_sprite = Sprite {
    //     debug_name = "runner",
    //     texture_name = "runner.png",
    //     resource = &game_window.resources["runner.png"],
    // }
    // split_into_frames(&game_window.runner_sprite, 4, 4, 0.04)

    return true
}

title_screen :: proc(dt: f32) {
    if rl.IsKeyPressed(.ENTER) {
        goto_main_menu()
    } else if rl.IsKeyPressed(.DOWN) {
        all_keys : [dynamic]string
        for key in game_window.resources {
            if game_window.resources[key].type == .RESOURCE_IMAGE && game_window.resources[key].tileset {
                append(&all_keys, key)
            }
        }
        idx, found := slice.linear_search(all_keys[:], string(game_window.title_resource))
        assert(found)
        next_idx := (idx + 1) % len(all_keys)
        delete(game_window.title_resource)
        game_window.title_resource = strings.clone_to_cstring(all_keys[next_idx])
    }

    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(color_navy)

    window_rect := game_window.rect
    {
        font := game_window.resources["info_font"].rl_data.(Font)
        text_size := rl.MeasureTextEx(font.font, game_window.title_resource, font.size, 0.0)
        rl.DrawTextEx(font.font, game_window.title_resource, rl.Vector2{}, font.size, 0.0, color_black)
        window_rect.y += text_size.y
        window_rect.height -= text_size.y
    }
    {
        resource := game_window.resources[string(game_window.title_resource)]
        source := resource.size
        origin := rl.Vector2{}
        rotation := f32(0)
        aspect := source.width / source.height
        dest := rl.Rectangle{}
        percentage := f32(0.98)
        // try % of window height
        dest.height = percentage * window_rect.height
        dest.width = aspect * dest.height
        dest.x = (window_rect.width - dest.width) / 2.0
        dest.y = (window_rect.height - dest.height) / 2.0 + window_rect.y
        if dest.x < 0 || dest.y < 0 {
            // try % of window width
            dest.width = percentage * window_rect.width
            dest.height = dest.width / aspect
            dest.x = (window_rect.width - dest.width) / 2.0
            dest.y = (window_rect.height - dest.height) / 2.0 + window_rect.y
        }
        rl.DrawTexturePro(resource.rl_data.(rl.Texture2D), source, dest, origin, rotation, color_original)
        magnification := dest.width / source.width
        cell := dest
        cell.width = f32(16) * magnification
        cell.height = f32(16) * magnification
        bottom := dest.y + dest.height - 1
        right := dest.x + dest.width - 1
        for cell.y < bottom {
            for cell.x < right {
                rl.DrawRectangleLinesEx(cell, 1.0, color_red)
                cell.x += f32(16) * magnification
            }
            cell.x = dest.x
            cell.y += f32(16) * magnification
        }
    }

    // title_font := game_window.resources["title_font"].rl_data.(Font)
    // text_size := rl.MeasureTextEx(title_font.font, game_title, title_font.size, 0.0)
    // pos := rl.Vector2{
    //     game_window.dim.x / 2.0 - text_size.x / 2.0,
    //     game_window.dim.y / 2.0 - text_size.y / 2.0,
    // }
    // rl.DrawTextEx(title_font.font, game_title, pos, title_font.size, 0.0, color_gold)
}

MAX_MENU_ITEMS :: 16

Action :: enum {
    NONE,
    NEW_GAME,
    QUIT,
}

Menu_Item :: struct {
    label: cstring,
    action: Action,
}

Menu :: struct {
    items: small_array.Small_Array(MAX_MENU_ITEMS, Menu_Item),
    focussed_index: int,
}

global_main_menu := Menu{}

setup_main_menu :: proc() {
    using global_main_menu
    small_array.push_back(&items, Menu_Item{"New Game", .NEW_GAME})
    small_array.push_back(&items, Menu_Item{"Quit", .QUIT})
}

goto_main_menu :: proc() {
    game_window.menu = global_main_menu
    game_window.game_state = .STATE_MENU
}

goto_new_game :: proc() {
    game_window.game_state = .STATE_LEVEL
}

menu_screen :: proc(dt: f32) {
    if rl.IsKeyPressed(.ENTER) {
        item := small_array.get_ptr(&game_window.menu.items, game_window.menu.focussed_index)
        #partial switch item.action {
            case .QUIT: game_window.quit = true
            case .NEW_GAME: goto_new_game()
        }
    } else if rl.IsKeyPressed(.DOWN) {
        game_window.menu.focussed_index = (game_window.menu.focussed_index + 1) % small_array.len(game_window.menu.items)
    } else if rl.IsKeyPressed(.UP) {
        if game_window.menu.focussed_index == 0 {
            game_window.menu.focussed_index = small_array.len(game_window.menu.items) - 1
        } else {
            game_window.menu.focussed_index = (game_window.menu.focussed_index - 1) % small_array.len(game_window.menu.items)
        }
    }

    rl.BeginDrawing()
    defer rl.EndDrawing()

    rl.ClearBackground(color_navy)
    menu_font := game_window.resources["menu_font"].rl_data.(Font)
    total_size : rl.Vector2
    for item in small_array.slice(&game_window.menu.items) {
        item_size := rl.MeasureTextEx(menu_font.font, item.label, menu_font.size, 0.0)
        total_size.x = max(total_size.x, item_size.x)
        total_size.y += item_size.y
    }
    pos := rl.Vector2{
        game_window.rect.width / 2.0 - total_size.x / 2.0,
        game_window.rect.height / 2.0 - total_size.y / 2.0,
    }
    for item, idx in small_array.slice(&game_window.menu.items) {
        rl.DrawTextEx(menu_font.font, item.label, pos, menu_font.size, 0.0, color_gold)
        item_size := rl.MeasureTextEx(menu_font.font, item.label, menu_font.size, 0.0)
        if idx == game_window.menu.focussed_index {
            circle_pos := pos
            circle_pos.y += item_size.y / 2.0
            circle_pos.x -= 20.0
            rl.DrawCircleV(circle_pos, 10.0, color_gold)
        }
        pos.y += item_size.y
    }
}

level_screen :: proc(dt: f32) {
    if rl.GetCharPressed() == 't' {
        thunderstorm := game_window.resources["thunderstorm.ogg"].rl_data.(rl.Sound)
        if game_window.thunder_playing {
            // pause
            rl.PauseSound(thunderstorm)
            game_window.thunder_playing = false
        } else {
            // play
            rl.ResumeSound(thunderstorm)
            game_window.thunder_playing = true
        }
    }
    if rl.IsMouseButtonPressed(.LEFT) {
        rl.PlaySound(game_window.resources["olympus_em1_m3_125th.ogg"].rl_data.(rl.Sound))
    }
    if rl.IsMouseButtonPressed(.RIGHT) {
        rl.PlaySound(game_window.resources["lumix_gx9_125th.ogg"].rl_data.(rl.Sound))
    }

    update_sprite(&game_window.runner_sprite, dt)

    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(color_blue)
    {
        tile_size := f32(game_window.floor_tiles_sprite.frame_dim.x * 2)
        dest := rl.Rectangle{100.0, 100.0, tile_size, tile_size}
        draw_sprite(&game_window.floor_tiles_sprite, dest, rl.WHITE)
    }
    {
        tile_size := f32(game_window.floor_tiles_sprite.frame_dim.x * 2)
        dest := rl.Rectangle{400.0, 350.0, tile_size, tile_size}
        draw_sprite(&game_window.floor_tiles_sprite, dest, rl.WHITE)
    }
    {
        runner_size := f32(game_window.runner_sprite.frame_dim.x * 2)
        dest := rl.Rectangle{450.0, 500.0, runner_size, runner_size}
        draw_sprite(&game_window.runner_sprite, dest, rl.WHITE)
    }
    {
        runner_size := f32(game_window.runner_sprite.frame_dim.x * 2)
        dest := rl.Rectangle{750.0, 500.0, runner_size, runner_size}
        draw_sprite(&game_window.runner_sprite, dest, rl.WHITE)
    }
}

update_and_render :: proc(dt: f32) {
    if rl.WindowShouldClose() {
        game_window.quit = true
    }

    #partial switch game_window.game_state {
        case .STATE_TITLE: title_screen(dt)
        case .STATE_LEVEL: level_screen(dt)
        case .STATE_MENU:  menu_screen(dt)
    }
}

main :: proc() {
	context = setup_context()

    init_debug_system(true)
    defer uninit_debug_system()

    rl.InitAudioDevice()
    rl.InitWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT,  game_title)
    when !ODIN_DEBUG {
        rl.SetExitKey(rl.KeyboardKey.KEY_NULL) // disable exit with escape in release mode
    }

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
        update_and_render(dt)
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}
