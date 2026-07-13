package main

import rl "vendor:raylib"

editor_run :: proc() {
	ghost := make(Maze)
	created := make(Maze)
	defer delete(ghost)
	defer delete(created)
	setup_editor(&ghost, &created)

	rl.InitWindow(WIDTH, HEIGHT, "labyrinth - editor")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		draw_ghost_maze(&ghost)
		draw_created_cells(&created)
		rl.EndDrawing()
	}
}

draw_ghost_maze :: proc(maze: ^Maze) {
	for p, cell in maze {
		draw_hex(p.q, p.r, cell.walls, rl.Color{40, 40, 40, 255})
	}
}

draw_created_cells :: proc(maze: ^Maze) {
	for p, cell in maze {
		draw_hex(p.q, p.r, cell.walls, rl.WHITE)
	}
}

setup_editor :: proc(maze: ^Maze, created: ^Maze) {
	start := Hex_Coord{0, 0}
	fill_hex_maze(LAYERS, maze, start)
	created[start] = Cell{ALL_WALLS}
}
