package main

import "core:os"
import "core:strconv"
import "core:strings"

Hex_Asset :: map[Hex_Coord]Cell

WALL_STR := [6]string{"NORTH_EAST", "EAST", "SOUTH_EAST", "SOUTH_WEST", "WEST", "NORTH_WEST"}

parse_hex_assets :: proc(filename: string, assets: ^map[string]Hex_Asset) {
	data, ok := os.read_entire_file(filename)
	if !ok {panic("failed to parse hex assets")}

	it := string(data)
	for section in strings.split_iterator(&it, "\n\n") {
		key: string
		asset := make(Hex_Asset)

		a := strings.trim_space(section)
		for curr in strings.split_iterator(&a, "\n") {
			line := strings.trim_space(curr)

			if len(line) < 2 {continue}
			if line[0] == '#' {
				key = line[1:]
				continue
			}
			if len(key) == 0 {break}

			p := strings.split(line, "::")
			defer delete(p)
			if len(p) != 2 {continue}

			c := strings.split(strings.trim_space(p[0]), ",")
			w := strings.split(strings.trim_space(p[1]), "|")
			defer delete(c)
			defer delete(w)
			if len(c) != 2 {continue}

			q, ok := strconv.parse_int(c[0])
			r, okay := strconv.parse_int(c[1])
			if !ok || !okay {continue}

			coord := Hex_Coord{i32(q), i32(r)}
			asset[coord] = Cell {
				walls = parse_walls(w),
			}
		}
		assets[key] = asset
	}
}

parse_walls :: proc(w: []string) -> Walls {
	walls := Walls{}

	for s in w {
		for i in 0 ..< 6 {
			if s == WALL_STR[i] {
				walls += {HEX_EXITS[i]}
			}
		}
	}
	return walls
}
