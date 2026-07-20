package main

import "core:math"
import "core:os"
import "core:time"
import rl "vendor:raylib"

editor_run :: proc() {
	if len(os.args) < 2 {
		panic("usage: editor <tag>")
	}
	tag := os.args[1]
	ghost := make(Maze)
	asset := make(Maze)
	defer delete(ghost)
	defer delete(asset)
	setup_editor(&ghost, &asset)

	buf: Maybe(Hex_Coord)
	done := false

	rl.InitWindow(WIDTH, HEIGHT, "labyrinth - editor")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() && !done {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		switch {
		case rl.IsKeyPressed(.ENTER):
			save_hex_asset("src/assets/hex.txt", asset, tag)
			rl.ClearBackground(rl.BLACK)
			rl.DrawText("saved asset!", WIDTH / 2 - 30, HEIGHT / 2, 20, rl.GREEN)
			done = true

		case rl.IsMouseButtonPressed(.LEFT):
			buf = nil
			pos := rl.GetMousePosition()
			coord := pixel_to_hex(pos.x, pos.y)
			toggle_coord(coord, &asset)
		case rl.IsMouseButtonPressed(.RIGHT):
			pos := rl.GetMousePosition()
			coord := pixel_to_hex(pos.x, pos.y)
			passage(coord, &asset, &buf)
		case rl.IsKeyPressed(.COMMA):
			buf = nil
			clear(&asset)
			asset[Hex_Coord{0, 0}] = Cell{ALL_WALLS}
		}
	editor_draw_ghost_maze(&ghost)
	editor_draw_asset_cells(&asset, buf)
		rl.EndDrawing()
	}
	time.sleep(time.Second)
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
	if ok {
		delete_key(m, coord)
		return
	}
	walls := ALL_WALLS

	for i in 0 ..< len(HEX_DIR) {
		dir := HEX_DIR[i]
		exit := HEX_EXITS[i]
		neighbor := Hex_Coord{coord.q + dir.q, coord.r + dir.r}
		cell, ok := m[neighbor]
		if !ok {continue}
		if inverse_direction(exit) in cell.walls {continue}
		walls -= {exit}
	}
	m[coord] = Cell{walls}
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

editor_draw_ghost_maze :: proc(maze: ^Maze) {
	for p, cell in maze {
		editor_draw_hex(p.q, p.r, cell.walls, rl.Color{40, 40, 40, 255}, nil)
	}
}

editor_draw_asset_cells :: proc(maze: ^Maze, buf: Maybe(Hex_Coord)) {
	for p, cell in maze {
		if p == buf {
			editor_draw_hex(p.q, p.r, cell.walls, rl.BLUE, nil)
			continue
		}
		editor_draw_hex(p.q, p.r, cell.walls, rl.WHITE, nil)
	}
}

editor_draw_hex :: proc(q, r: i32, walls: Walls, color: rl.Color, fill: Maybe(rl.Color)) {
	x, y := i32(WIDTH / 2), i32(HEIGHT / 2)
	cx := HEX_SIZE * math.sqrt_f64(3) * (f64(q) + f64(r) / 2)
	cy := HEX_SIZE * 3 / 2 * f64(r)

	if f, ok := fill.?; ok {
		rl.DrawPoly(rl.Vector2{f32(cx) + f32(x), f32(cy) + f32(y)}, 6, f32(HEX_SIZE), -30, f)
	}

	points := [6]Coord_f64{}
	for i in 0 ..< 6 {
		px, py := hex_corner(cx, cy, i)
		points[i] = Coord_f64{px, py}
	}
	for i in 0 ..< 6 {
		if RENDER_ORDER[i] not_in walls {continue}
		j     := (i + 1) % 6
		start := Coord{i32(points[i].x) + x, i32(points[i].y) + y}
		end   := Coord{i32(points[j].x) + x, i32(points[j].y) + y}
		rl.DrawLine(start.x, start.y, end.x, end.y, color)
	}
}

setup_editor :: proc(maze: ^Maze, asset: ^Maze) {
	start := Hex_Coord{0, 0}
	fill_hex_maze(LAYERS, maze, start)
	asset[start] = Cell{ALL_WALLS}
}
