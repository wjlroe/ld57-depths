package main

import "core:log"
import "core:image/png"
import "core:os"

when false {

Game :: struct {
    running: bool,
    renderer: ^Renderer,
    resources: map[string]Resource,
    floor_tiles_sprite: Sprite,
    runner_sprite: Sprite,
}

render_game :: proc(game: ^Game) {
    z : f32 = -0.9
    {
        tile_size := game.floor_tiles_sprite.frame_dim.x * 2
        tile_pos : rectangle2 = rect_min_dim(v2{100.0, 100.0}, v2{f32(tile_size), f32(tile_size)})
        push_render_group(game.renderer, sprite_as_render_group(&game.floor_tiles_sprite, game.renderer, tile_pos, z, "floor_tiles_1"))
    }
    {
        tile_size := game.floor_tiles_sprite.frame_dim.x * 2
        tile_pos : rectangle2 = rect_min_dim(v2{400.0, 350.0}, v2{f32(tile_size), f32(tile_size)})
        push_render_group(game.renderer, sprite_as_render_group(&game.floor_tiles_sprite, game.renderer, tile_pos, z, "floor_tiles_2"))
    }
    z += 0.1
    {
        runner_size := game.runner_sprite.frame_dim.x * 2
        runner_pos : rectangle2 = rect_min_dim(v2{450.0, 500.0}, v2{f32(runner_size), f32(runner_size)})
        push_render_group(game.renderer, sprite_as_render_group(&game.runner_sprite, game.renderer, runner_pos, z, "runner_1"))
    }
    z += 0.1
    {
        runner_size := game.runner_sprite.frame_dim.x * 2
        runner_pos : rectangle2 = rect_min_dim(v2{750.0, 500.0}, v2{f32(runner_size), f32(runner_size)})
        push_render_group(game.renderer, sprite_as_render_group(&game.runner_sprite, game.renderer, runner_pos, z, "runner_2"))
    }
}

}
