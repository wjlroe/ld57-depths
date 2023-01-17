package main

import "core:image/png"

game_title :: "Base Code"

floor_tiles_image := #load("../assets/floor_tiles.png")

Resource :: struct {
    file_name: string,
    data: ^[]byte,
    length: int,
}

Game :: struct {
    running: bool,
    renderer: ^Renderer,
    resources: map[string]Resource,
    floor_tiles_sprite: Sprite,
}

init_game :: proc(game: ^Game, renderer: ^Renderer) {
    game.resources = make(map[string]Resource)
    {
        game.resources["floor_tiles.png"] = Resource {
            file_name = "floor_tiles.png",
            data = &floor_tiles_image,
            length = size_of(floor_tiles_image),
        }
    }
    game.running = true
    game.renderer = renderer
    game.floor_tiles_sprite = Sprite {
        debug_name = "floor_tile",
        texture_name = "floor_tiles.png",
        frames = []Frame{
            Frame{
               duration = 100.0,
               name = "frame",
               rect = rect_min_dim(v2{0, 0}, v2{64, 64}),
            },
        },
        frame_width = 64,
        frame_height = 64,
        width = 64,
        height = 64,
        rect = rect_min_dim(v2{0, 0}, v2{64, 64}),
        resource = &game.resources["floor_tiles.png"],
    }
    {
        set_resource_as_texture(renderer, "floor_tiles.png", &game.resources["floor_tiles.png"])
    }
}

render_game :: proc(game: ^Game) {
    {
        clear_window := clear_render_group(color_blue)
        push_render_group(game.renderer, clear_window)
    }
    tile_size := game.floor_tiles_sprite.frame_width * 2
    {
        tile_pos : rectangle2 = rect_min_dim(v2{100.0, 100.0}, v2{f32(tile_size), f32(tile_size)})
        z : f32 = 0.5
        push_render_group(game.renderer, sprite_as_render_group(&game.floor_tiles_sprite, game.renderer, tile_pos, z))
    }
}
