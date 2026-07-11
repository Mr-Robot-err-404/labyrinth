package main

import "core:dynlib"
import "core:fmt"
import "core:os"
import os2 "core:os/os2"
import "core:log"
import "core:mem"
import "core:time"

when ODIN_OS == .Darwin {
	DLL_EXT :: ".dylib"
} else {
	DLL_EXT :: ".so"
}

GAME_DLL_DIR  :: "build/hot_reload/"
GAME_DLL_PATH :: GAME_DLL_DIR + "game" + DLL_EXT

copy_dll :: proc(to: string) -> bool {
	err := os2.copy_file(to, GAME_DLL_PATH)
	if err != nil {
		fmt.printfln("Failed to copy %v to %v: %v", GAME_DLL_PATH, to, err)
		return false
	}
	return true
}

Game_API :: struct {
	lib:               dynlib.Library,
	init_window:       proc(),
	init:              proc(),
	update:            proc(),
	should_run:        proc() -> bool,
	shutdown:          proc(),
	shutdown_window:   proc(),
	memory:            proc() -> rawptr,
	memory_size:       proc() -> int,
	hot_reloaded:      proc(mem: rawptr),
	modification_time: time.Time,
	api_version:       int,
}

load_game_api :: proc(api_version: int) -> (api: Game_API, ok: bool) {
	mod_time, mod_err := os2.last_write_time_by_name(GAME_DLL_PATH)
	if mod_err != nil {
		fmt.printfln("Failed to get mod time of %v: %v", GAME_DLL_PATH, mod_err)
		return
	}

	dll_name := fmt.tprintf(GAME_DLL_DIR + "game_%v" + DLL_EXT, api_version)
	copy_dll(dll_name) or_return

	_, ok = dynlib.initialize_symbols(&api, dll_name, "game_", "lib")
	if !ok {
		fmt.printfln("Failed to load symbols: %v", dynlib.last_error())
	}

	api.api_version       = api_version
	api.modification_time = mod_time
	ok = true
	return
}

unload_game_api :: proc(api: ^Game_API) {
	if api.lib != nil {
		if !dynlib.unload_library(api.lib) {
			fmt.printfln("Failed to unload lib: %v", dynlib.last_error())
		}
	}
	os.remove(fmt.tprintf(GAME_DLL_DIR + "game_%v" + DLL_EXT, api.api_version))
}

main :: proc() {
	context.logger = log.create_console_logger()

	default_allocator := context.allocator
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking, default_allocator)
	context.allocator = mem.tracking_allocator(&tracking)

	version := 0
	api, ok := load_game_api(version)
	if !ok {
		fmt.println("Failed to load game")
		return
	}

	version += 1
	api.init_window()
	api.init()

	old_apis := make([dynamic]Game_API, default_allocator)

	for api.should_run() {
		api.update()

		dll_mod, dll_mod_err := os2.last_write_time_by_name(GAME_DLL_PATH)
		reload := dll_mod_err == nil && api.modification_time != dll_mod

		if reload {
			new_api, new_ok := load_game_api(version)
			if new_ok {
				// If Game_Memory size changed, do a full restart
				if api.memory_size() != new_api.memory_size() {
					api.shutdown()
					mem.tracking_allocator_clear(&tracking)
					for &old in old_apis { unload_game_api(&old) }
					clear(&old_apis)
					unload_game_api(&api)
					api = new_api
					api.init()
				} else {
					append(&old_apis, api)
					mem := api.memory()
					api = new_api
					api.hot_reloaded(mem)
				}
				version += 1
			}
		}
	}

	free_all(context.temp_allocator)
	api.shutdown()

	for _, v in tracking.allocation_map {
		log.errorf("Leaked %v bytes at %v", v.size, v.location)
	}

	for &old in old_apis { unload_game_api(&old) }
	delete(old_apis)
	api.shutdown_window()
	unload_game_api(&api)
	mem.tracking_allocator_destroy(&tracking)
}
