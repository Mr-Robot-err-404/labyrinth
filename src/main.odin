package main

import "core:fmt"
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

Direction :: enum u8 {
	NORTH_EAST,
	EAST,
	SOUTH_EAST,
	SOUTH_WEST,
	WEST,
	NORTH_WEST,
}
MOVE := [Direction]Hex_Coord {
	.NORTH_EAST = {1, -1},
	.EAST       = {1, 0},
	.SOUTH_EAST = {0, 1},
	.SOUTH_WEST = {-1, 1},
	.WEST       = {-1, 0},
	.NORTH_WEST = {0, -1},
}

Walls :: bit_set[Direction]
ALL_WALLS :: Walls{.NORTH_EAST, .EAST, .SOUTH_EAST, .SOUTH_WEST, .WEST, .NORTH_WEST}

DIR := [4]Coord{{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
EXITS := [4]u8{TOP_WALL, RIGHT_WALL, DOWN_WALL, LEFT_WALL}
START :: Coord{4, 12}

HEX_DIR := [6]Hex_Coord {
	MOVE[.NORTH_EAST],
	MOVE[.EAST],
	MOVE[.SOUTH_EAST],
	MOVE[.SOUTH_WEST],
	MOVE[.WEST],
	MOVE[.NORTH_WEST],
}
LAYERS :: 7

HEX_EXITS := [6]Direction{.NORTH_EAST, .EAST, .SOUTH_EAST, .SOUTH_WEST, .WEST, .NORTH_WEST}
RENDER_ORDER := [6]Direction{.EAST, .SOUTH_EAST, .SOUTH_WEST, .WEST, .NORTH_WEST, .NORTH_EAST}

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

EDITOR :: #config(EDITOR, false)

Game_Memory :: struct {
	run:      bool,
	maze:     Maze,
	assets:   map[string]Hex_Asset,
	occupied: map[Hex_Coord]string,
}
g: ^Game_Memory

main :: proc() {
	when EDITOR {
		editor_run()
	} else {
		game_init_window()
		game_init()
		for game_should_run() {
			game_update()
		}
		game_shutdown()
		game_shutdown_window()
	}
}

@(export)
game_init :: proc() {
	maze := make(Maze)
	assets := make(map[string]Hex_Asset)
	occupied := make(map[Hex_Coord]string)

	parse_hex_assets("src/assets/hex.txt", &assets)
	generate_hex_maze(LAYERS, &maze, &occupied, assets, {0, 0})

	for tag, asset in assets {
		log_asset(tag, asset)
	}
	g = new(Game_Memory)
	g.maze = maze
	g.assets = assets
	g.occupied = occupied
	g.run = true
	game_hot_reloaded(g)
}
update :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {g.run = false}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	draw_hex_maze(&g.maze, &g.occupied)
	draw_assets(&g.maze, &g.occupied)
	rl.EndDrawing()

	free_all(context.temp_allocator)
}

fill_hex_maze :: proc(layers: int, maze: ^Maze, start: Hex_Coord) {
	current := make(map[Hex_Coord]bool)
	next := make(map[Hex_Coord]bool)
	defer delete(current)
	defer delete(next)

	current[start] = true
	for c in 0 ..< layers {
		create_layer(maze, &current, &next)
		clear(&current)
		current, next = next, current
	}
}

place_hex_assets :: proc(
	maze: ^Maze,
	occupied: ^map[Hex_Coord]string,
	limit: ^map[Hex_Coord]int,
	assets: map[string]Hex_Asset,
	start_layer: i32,
	end_layer: i32,
) {
	for tag, ass in assets {
		candidates := make([dynamic]Hex_Coord, context.temp_allocator)
		defer delete(candidates)

		for coord in maze {
			region := cells_from_center(coord.q, coord.r)
			if region < start_layer || region >= end_layer {continue}
			if coord in occupied {continue}
			append(&candidates, coord)
		}
		if len(candidates) == 0 {continue}
		rand.shuffle(candidates[:])

		for i in 0 ..< len(candidates) {
			offset := candidates[i]

			if !is_space_available(ass, offset, maze, occupied) {
				fmt.println("space not available")
				continue
			}
			for pos, cell in ass {
				coord := asset_to_maze_coord(pos, offset)
				occupied[coord] = tag
				maze[coord] = cell
				limit[coord] = 0
			}
			break
		}
	}
}

is_space_available :: proc(
	asset: map[Hex_Coord]Cell,
	offset: Hex_Coord,
	maze: ^Maze,
	occupied: ^map[Hex_Coord]string,
) -> bool {
	for p in asset {
		coord := asset_to_maze_coord(p, offset)
		if coord not_in maze {return false}
		if coord in occupied {return false}
	}
	return true
}

asset_to_maze_coord :: proc(coord: Hex_Coord, offset: Hex_Coord) -> Hex_Coord {
	return Hex_Coord{coord.q + offset.q, coord.r + offset.r}
}

generate_hex_maze :: proc(
	layers: int,
	maze: ^Maze,
	occupied: ^map[Hex_Coord]string,
	assets: map[string]Hex_Asset,
	start: Hex_Coord,
) {
	limit := make(map[Hex_Coord]int)
	defer delete(limit)

	fill_hex_maze(layers, maze, start)
	for coord in maze {
		limit[coord] = 1
	}
	place_hex_assets(maze, occupied, &limit, assets, 0, LAYERS)
	walk(0, 0, maze, &limit, Direction.EAST)
}

walk :: proc(q, r: i32, maze: ^Maze, limit: ^map[Hex_Coord]int, entry: Direction) -> bool {
	coord := Hex_Coord{q, r}
	if coord not_in maze {return false}
	if n := limit[coord]; n <= 0 {return false}

	limit[coord] -= 1
	remove_wall(coord, maze, entry)

	indices := [6]int{0, 1, 2, 3, 4, 5}
	shuffle(&indices)

	for i in indices {
		dir := HEX_DIR[i]
		exit := HEX_EXITS[i]
		smash := walk(q + dir.q, r + dir.r, maze, limit, inverse_direction(exit))
		if !smash {continue}
		remove_wall(coord, maze, exit)
	}
	return true
}

cells_from_center :: proc(q, r: i32) -> i32 {
	// q + r + s = 0
	s := -q - r
	return max(math.abs(q), math.abs(r), math.abs(s))
}

remove_wall :: proc(coord: Hex_Coord, maze: ^Maze, wall: Direction) {
	cell, ok := maze[coord]
	if !ok {return}
	cell.walls -= {wall}
	maze[coord] = cell
}

create_layer :: proc(maze: ^Maze, current, next: ^map[Hex_Coord]bool) {
	for p in current {
		if _, visited := maze[p]; visited {continue}

		maze[p] = Cell {
			walls = Walls{.NORTH_EAST, .EAST, .SOUTH_EAST, .SOUTH_WEST, .WEST, .NORTH_WEST},
		}
		for dir in HEX_DIR {
			neighbor := Hex_Coord {
				q = p.q + dir.q,
				r = p.r + dir.r,
			}
			next[neighbor] = true
		}
	}
}

draw_assets :: proc(maze: ^Maze, occupied: ^map[Hex_Coord]string) {
	for p, tag in occupied {
		cell, ok := maze[p]
		if !ok {panic("asset cell not found in maze")}
		draw_hex(p.q, p.r, cell.walls, rl.BLUE)
	}
}

draw_hex_maze :: proc(maze: ^Maze, occupied: ^map[Hex_Coord]string) {
	for p, cell in maze {
		if p in occupied {continue}
		draw_hex(p.q, p.r, cell.walls, rl.WHITE)
	}
}

draw_hex :: proc(q, r: i32, walls: Walls, color: rl.Color) {
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
		rl.DrawLine(start.x, start.y, end.x, end.y, color)
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
