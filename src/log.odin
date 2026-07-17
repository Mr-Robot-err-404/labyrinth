package main

import "core:fmt"

log_asset :: proc(name: string, asset: Hex_Asset) {
	fmt.printfln("=== %s ===", name)
	for coord, cell in asset {
		fmt.printfln("  (%d,%d) :: %v", coord.q, coord.r, cell.walls)
	}
}
