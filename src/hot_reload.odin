package game

import rl "vendor:raylib"

@(export)
game_init_window :: proc() {
	rl.InitWindow(WIDTH, HEIGHT, "labyrinth")
	rl.SetTargetFPS(60)
	rl.SetExitKey(nil)
}

@(export)
game_update :: proc() {
	update()
}

@(export)
game_should_run :: proc() -> bool {
	return g.run && !rl.WindowShouldClose()
}

@(export)
game_shutdown :: proc() {
	delete(g.maze)
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)
}
