package main

import "core:image/png"

game_title :: "Base Code"

floor_tiles_image := #load("../assets/floor_tiles.png")
runner_image := #load("../assets/runner.png")

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
    runner_sprite: Sprite,
}

init_game :: proc(game: ^Game, renderer: ^Renderer) {
    game.running = true
    game.renderer = renderer

    game.resources = map[string]Resource{
       "floor_tiles.png" =  Resource {
            file_name = "floor_tiles.png",
            data = &floor_tiles_image,
            length = size_of(floor_tiles_image),
        },
        "runner.png" = Resource {
            file_name = "runner.png",
            data = &runner_image,
            length = size_of(runner_image),
        },
    }

    floor_tiles_texture := set_resource_as_texture(renderer, "floor_tiles.png", &game.resources["floor_tiles.png"])
    runner_texture := set_resource_as_texture(renderer, "runner.png", &game.resources["runner.png"])

    game.floor_tiles_sprite = Sprite {
        debug_name = "floor_tile",
        texture_name = "floor_tiles.png",
        frames = []Frame{
            Frame{
               duration = 100.0,
               name = "frame",
               rect = rect_min_dim(v2s{0, 0}, v2s{64, 64}),
            },
        },
        frame_dim = v2s{64, 64},
        tex_dim = v2s{64, 64},
        resource = &game.resources["floor_tiles.png"],
    }

    game.runner_sprite = Sprite {
        debug_name = "runner",
        texture_name = "runner.png",
        tex_dim = runner_texture.dim,
        resource = &game.resources["runner.png"],
    }
    split_into_frames(&game.runner_sprite, 4, 4, 0.04)
}

render_game :: proc(game: ^Game) {
    {
        clear_window := clear_render_group(color_blue)
        push_render_group(game.renderer, clear_window)
    }
    z : f32 = 0.9
    {
        tile_size := game.floor_tiles_sprite.frame_dim.x * 2
        tile_pos : rectangle2 = rect_min_dim(v2{100.0, 100.0}, v2{f32(tile_size), f32(tile_size)})
        push_render_group(game.renderer, sprite_as_render_group(&game.floor_tiles_sprite, game.renderer, tile_pos, z))
    }
    z -= 0.1
    {
        runner_size := game.runner_sprite.frame_dim.x * 2
        runner_pos : rectangle2 = rect_min_dim(v2{450.0, 300.0}, v2{f32(runner_size), f32(runner_size)})
        push_render_group(game.renderer, sprite_as_render_group(&game.runner_sprite, game.renderer, runner_pos, z))
    }
}

update_game :: proc(game: ^Game, dt: f64) {
    update_sprite(&game.runner_sprite, dt)
}
