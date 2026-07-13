package main

import rl "vendor:raylib"

editor_run :: proc() {
	rl.InitWindow(WIDTH, HEIGHT, "labyrinth - editor")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.EndDrawing()
	}
}
