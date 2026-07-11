package game

import rl "vendor:raylib"

MAZE_WIDTH: i32 : 20
MAZE_HEIGHT: i32 : 20
CELL_SIZE: f32 : 30
WIDTH :: 800
HEIGHT :: 800

TOP_WALL: u8 : 1 << 3
RIGHT_WALL: u8 : 1 << 2
DOWN_WALL: u8 : 1 << 1
LEFT_WALL: u8 : 1 << 0

Cell :: struct {
	walls: u8,
}

Game_Memory :: struct {
	run:  bool,
	maze: []Cell,
}

g: ^Game_Memory

@(export)
game_init :: proc() {
	g = new(Game_Memory)
	g.maze = make([]Cell, MAZE_WIDTH * MAZE_HEIGHT)
	g.run = true
	generate_maze(g.maze[:])
	game_hot_reloaded(g)
}
update :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {g.run = false}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	draw_maze(g.maze)
	rl.EndDrawing()

	free_all(context.temp_allocator)
}

generate_maze :: proc(maze: []Cell) {
	for i in 0 ..< len(maze) {
		maze[i] = Cell {
			walls = TOP_WALL | RIGHT_WALL | DOWN_WALL | LEFT_WALL,
		}
	}
}

draw_maze :: proc(maze: []Cell) {
	for y in 0 ..< MAZE_HEIGHT {
		for x in 0 ..< MAZE_WIDTH {
			cell := get_cell(x, y, maze)
			px := f32(x) * CELL_SIZE
			py := f32(y) * CELL_SIZE

			if is_wall(cell.walls, TOP_WALL) {render_wall(px, py, TOP_WALL)}
			if is_wall(cell.walls, RIGHT_WALL) {render_wall(px, py, RIGHT_WALL)}
			if is_wall(cell.walls, DOWN_WALL) {render_wall(px, py, DOWN_WALL)}
			if is_wall(cell.walls, LEFT_WALL) {render_wall(px, py, LEFT_WALL)}
		}
	}
}

render_wall :: proc(px, py: f32, w: u8) {
	ox, oy := centre()
	switch w {
	case TOP_WALL:
		rl.DrawLineV({px + ox, py + oy}, {px + CELL_SIZE + ox, py + oy}, rl.BLUE)
	case RIGHT_WALL:
		rl.DrawLineV(
			{px + CELL_SIZE + ox, py + oy},
			{px + CELL_SIZE + ox, py + CELL_SIZE + oy},
			rl.BLUE,
		)
	case DOWN_WALL:
		rl.DrawLineV(
			{px + ox, py + CELL_SIZE + oy},
			{px + CELL_SIZE + ox, py + CELL_SIZE + oy},
			rl.BLUE,
		)
	case LEFT_WALL:
		rl.DrawLineV({px + ox, py + oy}, {px + ox, py + CELL_SIZE + oy}, rl.BLUE)
	}
}

is_wall :: proc(walls: u8, side: u8) -> bool {
	return walls & side != 0
}

centre :: proc() -> (f32, f32) {
	total_w := f32(MAZE_WIDTH) * CELL_SIZE
	total_h := f32(MAZE_HEIGHT) * CELL_SIZE
	return (f32(WIDTH) - total_w) / 2, (f32(HEIGHT) - total_h) / 2
}

get_cell :: proc(x, y: i32, maze: []Cell) -> Cell {
	idx := (y * MAZE_WIDTH) + x
	return maze[idx]
}

set_cell :: proc(x, y: i32, walls: u8, maze: []Cell) {
	idx := (y * MAZE_WIDTH) + x
	maze[idx] = Cell {
		walls = walls,
	}
}
