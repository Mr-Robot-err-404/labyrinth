package main

import pq "core:container/priority_queue"
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
Node :: struct {
	pos:   Hex_Coord,
	score: i32,
	cost:  i32,
}
Pathfind :: struct {
	stack:   [dynamic]Hex_Coord,
	visited: map[Hex_Coord]bool,
	origin:  map[Hex_Coord]Hex_Coord,
	path:    [dynamic]Hex_Coord,
	target:  Hex_Coord,
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

step :: proc(pos: ^Hex_Coord, maze: ^Maze, p: ^Pathfind) {
	if len(p.stack) == 0 {return}
	pos^ = p.stack[len(p.stack) - 1]
	if pos^ == p.target {return}

	p.visited[pos^] = true
	cell := maze[pos^]

	best := Hex_Coord{}
	optimal := max(i32)

	for i in 0 ..< 6 {
		wall := HEX_EXITS[i]
		dir := HEX_DIR[i]
		if wall in cell.walls {continue}

		neighbor := Hex_Coord{pos.q + dir.q, pos.r + dir.r}
		if neighbor not_in maze {continue}
		if p.visited[neighbor] {continue}

		score := hex_distance(neighbor, p.target)
		if score < optimal {
			best = neighbor
			optimal = score
		}
	}
	if optimal < max(i32) {
		append(&p.stack, best)
		return
	}
	pop(&p.stack)
}

priority_search :: proc(a: Hex_Coord, b: Hex_Coord, maze: ^Maze, path: ^[dynamic]Hex_Coord) {
	visited := make(map[Hex_Coord]bool)
	origin := make(map[Hex_Coord]Hex_Coord)
	defer delete(origin)
	defer delete(visited)

	q: pq.Priority_Queue(Node)
	defer pq.destroy(&q)
	pq.init(&q, proc(a, b: Node) -> bool {return a.score < b.score}, pq.default_swap_proc(Node))
	pq.push(&q, Node{pos = a, score = hex_distance(a, b)})

	for pq.len(q) > 0 {
		node := pq.pop(&q)
		if node.pos == b {
			build_path(a, b, path, origin)
			return
		}
		visited[node.pos] = true
		cell := maze[node.pos]

		for i in 0 ..< len(HEX_EXITS) {
			wall := HEX_EXITS[i]
			dir := HEX_DIR[i]
			if wall in cell.walls {continue}

			neighbor := Hex_Coord{node.pos.q + dir.q, node.pos.r + dir.r}
			if _, ok := maze[neighbor]; !ok {continue}
			if _, seen := visited[neighbor]; seen {continue}

			pq.push(&q, Node{pos = neighbor, score = hex_distance(neighbor, b)})
			origin[neighbor] = node.pos
		}
	}
	fmt.println("not found :|")
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

is_deadend :: proc(pos: Hex_Coord, cell: Cell, visited: map[Hex_Coord]bool, maze: ^Maze) -> bool {
	for i in 0 ..< 6 {
		wall := HEX_EXITS[i]
		dir := HEX_DIR[i]
		if wall in cell.walls {continue}

		neighbor := Hex_Coord{pos.q + dir.q, pos.r + dir.r}
		if _, ok := maze[neighbor]; !ok {continue}
		if _, seen := visited[neighbor]; !seen {return false}
	}
	return true
}

backtrack :: proc(
	pos: ^Hex_Coord,
	next: Node,
	q: ^pq.Priority_Queue(Node),
	origin: map[Hex_Coord]Hex_Coord,
) -> bool {
	for i in 0 ..< 6 {
		dir := HEX_DIR[i]
		neighbor := Hex_Coord{pos.q + dir.q, pos.r + dir.r}
		if neighbor == next.pos {return false}
	}
	prev, okay := origin[pos^]
	if !okay {return false}
	pos^ = prev
	return true
}
