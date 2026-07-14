package main

import "core:math"
import rl "vendor:raylib"

editor_run :: proc() {
	ghost := make(Maze)
	created := make(Maze)
	defer delete(ghost)
	defer delete(created)
	setup_editor(&ghost, &created)

	buf: Maybe(Hex_Coord)

	rl.InitWindow(WIDTH, HEIGHT, "labyrinth - editor")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		switch {
		case rl.IsMouseButtonPressed(.LEFT):
			buf = nil
			pos := rl.GetMousePosition()
			coord := pixel_to_hex(pos.x, pos.y)
			toggle_coord(coord, &created)
		case rl.IsMouseButtonPressed(.RIGHT):
			pos := rl.GetMousePosition()
			coord := pixel_to_hex(pos.x, pos.y)
			passage(coord, &created, &buf)
		case rl.IsKeyPressed(.COMMA):
			buf = nil
			clear(&created)
			created[Hex_Coord{0, 0}] = Cell{ALL_WALLS}
		}
		draw_ghost_maze(&ghost)
		draw_created_cells(&created, buf)
		rl.EndDrawing()
	}
}

passage :: proc(b: Hex_Coord, m: ^Maze, buf: ^Maybe(Hex_Coord)) {
	a, okay := buf^.?

	if !okay {
		buf^ = b
		return
	}
	buf^ = nil

	dir, found := is_neighbor(a, b)
	if !found {return}
	toggle_wall(a, m, dir)
	toggle_wall(b, m, inverse_direction(dir))
}

is_neighbor :: proc(a, b: Hex_Coord) -> (Direction, bool) {
	v := hex_vector(a, b)
	for mv, dir in MOVE {
		if mv == v {return dir, true}
	}
	return .EAST, false
}

hex_vector :: proc(a, b: Hex_Coord) -> Hex_Coord {
	return Hex_Coord{b.q - a.q, b.r - a.r}
}
toggle_wall :: proc(coord: Hex_Coord, m: ^Maze, wall: Direction) {
	cell, ok := m[coord]
	if !ok {return}

	if wall in cell.walls {
		cell.walls -= {wall}
	} else {
		cell.walls += {wall}
	}
	m[coord] = cell
}

toggle_coord :: proc(coord: Hex_Coord, m: ^Maze) {
	_, ok := m[coord]
	if !ok {
		m[coord] = Cell{ALL_WALLS}
		return
	}
	delete_key(m, coord)
}

pixel_to_hex :: proc(px, py: f32) -> Hex_Coord {
	x := f64(px) - (f64(WIDTH) / 2)
	y := f64(py) - (f64(HEIGHT) / 2)
	q := (x * math.sqrt_f64(3) / 3 - y / 3) / HEX_SIZE
	r := (y * 2 / 3) / HEX_SIZE
	return hex_round(q, r)
}
hex_round :: proc(q, r: f64) -> Hex_Coord {
	s := -q - r
	rq, rr, rs := math.round_f64(q), math.round_f64(r), math.round_f64(s)
	dq := math.abs(rq - q)
	dr := math.abs(rr - r)
	ds := math.abs(rs - s)
	if dq > dr && dq > ds {
		rq = -rr - rs
	} else if dr > ds {
		rr = -rq - rs
	}
	return Hex_Coord{i32(rq), i32(rr)}
}

draw_ghost_maze :: proc(maze: ^Maze) {
	for p, cell in maze {
		draw_hex(p.q, p.r, cell.walls, rl.Color{40, 40, 40, 255})
	}
}

draw_created_cells :: proc(maze: ^Maze, buf: Maybe(Hex_Coord)) {
	for p, cell in maze {
		if p == buf {
			draw_hex(p.q, p.r, cell.walls, rl.BLUE)
			continue
		}
		draw_hex(p.q, p.r, cell.walls, rl.WHITE)
	}
}

setup_editor :: proc(maze: ^Maze, created: ^Maze) {
	start := Hex_Coord{0, 0}
	fill_hex_maze(LAYERS, maze, start)
	created[start] = Cell{ALL_WALLS}
}
