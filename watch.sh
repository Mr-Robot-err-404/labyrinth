#!/usr/bin/env bash
set -eu

EXE=build/labyrinth
DLL_DIR=build/hot_reload
ROOT=$(odin root)

mkdir -p $DLL_DIR

build_dll() {
    echo "Building game.dylib..."
    odin build src \
        -extra-linker-flags:"-Wl,-rpath,${ROOT}/vendor/raylib/macos" \
        -define:RAYLIB_SHARED=true \
        -build-mode:dll \
        -out:$DLL_DIR/game_tmp.dylib \
        -debug && mv $DLL_DIR/game_tmp.dylib $DLL_DIR/game.dylib && echo "Done."
}

build_exe() {
    echo "Building runner..."
    odin build src/main_hot_reload -out:$EXE -debug && echo "Done."
}

build_dll
build_exe

echo "Running..."
./$EXE &

fswatch -o src/ | while read; do
    build_dll
done
