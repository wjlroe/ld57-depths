package main

Game :: struct {
    running: bool,
    renderer: ^Renderer,
}

init_game :: proc(game: ^Game, renderer: ^Renderer) {
    game.running = true
    game.renderer = renderer
}
