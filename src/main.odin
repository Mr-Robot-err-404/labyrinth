package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

MAZE_WIDTH: i32 : 20
MAZE_HEIGHT: i32 : 20
CELL_SIZE: f32 : 30
HEX_SIZE: f64 : 30
WIDTH: i32 : 800
HEIGHT: i32 : 800

TOP_WALL: u8 : 1 << 3
RIGHT_WALL: u8 : 1 << 2
DOWN_WALL: u8 : 1 << 1
LEFT_WALL: u8 : 1 << 0

DIR := [4]Coord{{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
EXITS := [4]u8{TOP_WALL, RIGHT_WALL, DOWN_WALL, LEFT_WALL}
START :: Coord{4, 12}

HEX_DIR := [6]Hex_Coord{{1, -1}, {1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {0, -1}}
LAYERS :: 7

Direction :: enum u8 {
	NORTH_EAST,
	EAST,
	SOUTH_EAST,
	SOUTH_WEST,
	WEST,
	NORTH_WEST,
}
Walls :: bit_set[Direction]

HEX_EXITS := [6]Direction{.NORTH_EAST, .EAST, .SOUTH_EAST, .SOUTH_WEST, .WEST, .NORTH_WEST}
RENDER_ORDER := [6]Direction{.SOUTH_EAST, .SOUTH_WEST, .WEST, .NORTH_WEST, .NORTH_EAST, .EAST}

Cell :: struct {
	walls: Walls,
}
Maze :: map[Hex_Coord]Cell

Coord :: struct {
	x, y: i32,
}
Hex_Coord :: struct {
	q, r: i32,
}
Coord_f64 :: struct {
	x, y: f64,
}

Game_Memory :: struct {
	run:  bool,
	maze: Maze,
}
g: ^Game_Memory

@(export)
game_init :: proc() {
	g = new(Game_Memory)
	g.maze = make(Maze)
	g.run = true
	generate_hex_maze(LAYERS, &g.maze, {0, 0})
	game_hot_reloaded(g)
}
update :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {g.run = false}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	draw_hex_maze(g.maze)
	rl.EndDrawing()

	free_all(context.temp_allocator)
}

generate_hex_maze :: proc(layers: int, maze: ^Maze, start: Hex_Coord) {
	visited := make(map[Hex_Coord]bool)
	seen := make(map[Hex_Coord]bool)
	current := make(map[Hex_Coord]bool)
	next := make(map[Hex_Coord]bool)
	defer delete(current)
	defer delete(next)
	defer delete(visited)
	defer delete(seen)

	current[start] = true
	for c in 0 ..< layers {
		create_layer(maze, &current, &next, &visited)
		clear(&current)
		current, next = next, current
	}
	walk(0, 0, maze, &seen, Direction.EAST)
}

walk :: proc(q, r: i32, maze: ^Maze, visited: ^map[Hex_Coord]bool, entry: Direction) -> bool {
	coord := Hex_Coord{q, r}
	if coord not_in maze {return false}

	if visited[coord] {return false}
	visited[coord] = true
	remove_wall(coord, maze, entry)

	indices := [6]int{0, 1, 2, 3, 4, 5}
	shuffle(&indices)

	for i in indices {
		dir := HEX_DIR[i]
		exit := HEX_EXITS[i]
		smash := walk(q + dir.q, r + dir.r, maze, visited, inverse_direction(exit))
		if !smash {continue}
		remove_wall(coord, maze, exit)
	}
	return true
}

remove_wall :: proc(coord: Hex_Coord, maze: ^Maze, wall: Direction) {
	cell, ok := maze[coord]
	if !ok {return}
	cell.walls -= {wall}
	maze[coord] = cell
}

create_layer :: proc(maze: ^Maze, current, next, visited: ^map[Hex_Coord]bool) {
	for p in current {
		maze[p] = Cell {
			walls = Walls{.NORTH_EAST, .EAST, .SOUTH_EAST, .SOUTH_WEST, .WEST, .NORTH_WEST},
		}
		visited[p] = true

		for dir in HEX_DIR {
			neighbor := Hex_Coord {
				q = p.q + dir.q,
				r = p.r + dir.r,
			}
			if ok := visited[neighbor]; ok {continue}
			next[neighbor] = true
		}
	}
}

draw_hex_maze :: proc(maze: Maze) {
	for p, cell in maze {
		draw_hex(p.q, p.r, cell.walls)
	}
}

draw_hex :: proc(q, r: i32, walls: Walls) {
	x, y := i32(WIDTH / 2), i32(HEIGHT / 2)
	cx := HEX_SIZE * math.sqrt_f64(3) * (f64(q) + f64(r) / 2)
	cy := HEX_SIZE * 3 / 2 * f64(r)

	points := [6]Coord_f64{}

	for i in 0 ..< 6 {
		px, py := hex_corner(cx, cy, i)
		points[i] = Coord_f64{px, py}
	}
	for i in 0 ..< 6 {
		if RENDER_ORDER[i] not_in walls {continue}
		j := (i + 1) % 6
		start := Coord{i32(points[i].x) + x, i32(points[i].y) + y}
		end := Coord{i32(points[j].x) + x, i32(points[j].y) + y}
		rl.DrawLine(start.x, start.y, end.x, end.y, rl.WHITE)
	}
}

hex_corner :: proc(cx, cy: f64, i: int) -> (f64, f64) {
	deg: f64 = 60 * f64(i) - 30
	theta := math.PI / 180 * deg
	return cx + HEX_SIZE * math.cos_f64(theta), cy + HEX_SIZE * math.sin_f64(theta)
}


shuffle :: proc(arr: ^[6]int) {
	for i := len(arr) - 1; i > 0; i -= 1 {
		j := rand.int_max(i + 1)
		arr[i], arr[j] = arr[j], arr[i]
	}
}
inverse_direction :: proc(wall: Direction) -> Direction {
	switch wall {
	case .NORTH_EAST:
		return .SOUTH_WEST
	case .EAST:
		return .WEST
	case .SOUTH_EAST:
		return .NORTH_WEST
	case .SOUTH_WEST:
		return .NORTH_EAST
	case .WEST:
		return .EAST
	case .NORTH_WEST:
		return .SOUTH_EAST
	}
	return Direction.EAST
}

out_of_bounds_hex :: proc(coord: Hex_Coord, maze: ^Maze) -> bool {
	return coord not_in maze
}

maze_idx :: proc(x, y: i32) -> i32 {
	return (y * MAZE_WIDTH) + x
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
