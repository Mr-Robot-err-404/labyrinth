package main

import "core:container/queue"
import "core:fmt"

Minatour :: struct {
	pos:   Hex_Coord,
	state: State,
}
State :: enum {
	exploring,
	loitering,
	resting,
}
Pathfind :: struct {
	path:  [dynamic]Hex_Coord,
	start: Maybe(Hex_Coord),
	end:   Maybe(Hex_Coord),
}

build_path :: proc(
	start, end: Hex_Coord,
	path: ^[dynamic]Hex_Coord,
	origin: map[Hex_Coord]Hex_Coord,
) {
	append_elem(path, end)
	curr := end
	for {
		prev, ok := origin[curr]
		if !ok {return}
		curr = prev
		append_elem(path, curr)
		if curr == start {return}
	}
}

bfs_search :: proc(a: Hex_Coord, b: Hex_Coord, maze: ^Maze, path: ^[dynamic]Hex_Coord) {
	visited := make(map[Hex_Coord]bool)
	origin := make(map[Hex_Coord]Hex_Coord)

	q: queue.Queue(Hex_Coord)
	queue.init(&q)
	queue.push_back(&q, a)

	for queue.len(q) > 0 {
		coord := queue.pop_front(&q)
		if coord == b {
			build_path(a, b, path, origin)
			return
		}
		visited[coord] = true
		cell := maze[coord]

		for i in 0 ..< len(HEX_EXITS) {
			wall := HEX_EXITS[i]
			dir := HEX_DIR[i]
			if wall in cell.walls {continue}

			neighbor := Hex_Coord{coord.q + dir.q, coord.r + dir.r}
			if _, ok := maze[neighbor]; !ok {continue}
			if _, seen := visited[neighbor]; seen {continue}

			queue.push_back(&q, neighbor)
			origin[neighbor] = coord
		}
	}
	fmt.println("not found :|")
}
