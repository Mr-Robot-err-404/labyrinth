package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

HEX_SIZE: f64 : 30
WIDTH: i32 : 1920
HEIGHT: i32 : 1080

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

HEX_DIR := [6]Hex_Coord {
	MOVE[.NORTH_EAST],
	MOVE[.EAST],
	MOVE[.SOUTH_EAST],
	MOVE[.SOUTH_WEST],
	MOVE[.WEST],
	MOVE[.NORTH_WEST],
}
LAYERS :: 10
DENSITY_STEP: f32 : 0.02
DECAY_STEP: f32 : 0.02

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
	run:         bool,
	maze:        Maze,
	assets:      map[string]Hex_Asset,
	occupied:    map[Hex_Coord]string,
	max_density: f32,
	decay:       f32,
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
	g = new(Game_Memory)
	g.max_density = 0.5
	g.decay = 0.7
	g.run = true

	assets := make(map[string]Hex_Asset)
	parse_hex_assets("src/assets/hex.txt", &assets)
	g.assets = assets

	regen(g)
	game_hot_reloaded(g)
}

regen :: proc(g: ^Game_Memory) {
	delete(g.maze)
	delete(g.occupied)
	g.maze = make(Maze)
	g.occupied = make(map[Hex_Coord]string)
	generate_hex_maze(LAYERS, &g.maze, &g.occupied, g.assets, {0, 0}, g.max_density, g.decay)
}

update :: proc() {
	if rl.IsKeyPressed(.ESCAPE) {g.run = false}

	dirty := false
	if rl.IsKeyPressed(.UP) {g.max_density = min(g.max_density + DENSITY_STEP, 1.0); dirty = true}
	if rl.IsKeyPressed(
		.DOWN,
	) {g.max_density = max(g.max_density - DENSITY_STEP, 0.0); dirty = true}
	if rl.IsKeyPressed(.RIGHT) {g.decay = min(g.decay + DECAY_STEP, 1.0); dirty = true}
	if rl.IsKeyPressed(.LEFT) {g.decay = max(g.decay - DECAY_STEP, 0.0); dirty = true}
	if dirty {regen(g)}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	draw_hex_maze(&g.maze, &g.occupied)
	draw_assets(&g.maze, &g.occupied)
	draw_debug_overlay()
	rl.EndDrawing()

	free_all(context.temp_allocator)
}

draw_debug_overlay :: proc() {
	pad :: i32(12)
	line :: i32(20)
	y := pad

	rl.DrawText(
		fmt.ctprintf("max_density: %.2f  [UP/DOWN]", g.max_density),
		pad,
		y,
		18,
		rl.YELLOW,
	); y += line
	rl.DrawText(
		fmt.ctprintf("decay:       %.2f  [LEFT/RIGHT]", g.decay),
		pad,
		y,
		18,
		rl.YELLOW,
	); y += line
	y += 6
	for i in 0 ..< LAYERS {
		d := layer_density(i32(i), g.max_density, g.decay)
		rl.DrawText(fmt.ctprintf("  layer %d: %.3f", i, d), pad, y, 16, rl.GRAY)
		y += line
	}
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

break_walls :: proc(maze: ^Maze, occupied: ^map[Hex_Coord]string, max_density: f32, decay: f32) {
	visited := make(map[Hex_Coord]bool)
	defer delete(visited)

	for coord, cell in maze {
		if coord in occupied {continue}
		visited[coord] = true

		layer := cells_from_center(coord.q, coord.r)
		for i in 0 ..< 6 {
			wall := HEX_EXITS[i]
			dir := HEX_DIR[i]
			if wall not_in cell.walls {continue}

			neighbor := Hex_Coord{coord.q + dir.q, coord.r + dir.r}
			if neighbor in occupied {continue}
			if neighbor not_in maze {continue}
			if visited[neighbor] {continue}
			if rand.float32() >= layer_density(layer, max_density, decay) {continue}

			remove_wall(coord, maze, wall)
			remove_wall(neighbor, maze, inverse_direction(wall))
		}
	}
}

layer_density :: proc(layer: i32, max_density: f32, decay: f32) -> f32 {
	return max_density * math.pow_f32(decay, f32(layer))
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

			if !is_space_available(ass, offset, maze, occupied) {continue}
			for pos, cell in ass {
				coord := asset_to_maze_coord(pos, offset)
				occupied[coord] = tag
				maze[coord] = cell
				limit[coord] = 0

				for i in 0 ..< len(HEX_DIR) {
					dir := HEX_DIR[i]
					wall := HEX_EXITS[i]
					if wall in cell.walls {continue}
					neighbor := Hex_Coord{coord.q + dir.q, coord.r + dir.r}

					if hex, ok := maze[neighbor]; ok && inverse_direction(wall) in hex.walls {
						hex.walls -= {inverse_direction(wall)}
						maze[neighbor] = hex
					}
				}
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
	max_density: f32,
	decay: f32,
) {
	limit := make(map[Hex_Coord]int)
	defer delete(limit)

	fill_hex_maze(layers, maze, start)
	for coord in maze {
		limit[coord] = 1
	}
	place_hex_assets(maze, occupied, &limit, assets, 0, LAYERS)
	start := starting_point(maze, occupied)
	walk(start.q, start.r, maze, &limit, Direction.EAST)
	break_walls(maze, occupied, max_density, decay)
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

starting_point :: proc(maze: ^Maze, occupied: ^map[Hex_Coord]string) -> Hex_Coord {
	for coord in maze {
		if coord in occupied {continue}
		return coord
	}
	panic("nope")
}

cells_from_center :: proc(q, r: i32) -> i32 {
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
			walls = ALL_WALLS,
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
	for p in occupied {
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
	return .EAST
}
