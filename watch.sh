#!/usr/bin/env bash
set -eu

EXE=build/labyrinth

mkdir -p build

kill_game() {
    pkill -f $EXE 2>/dev/null || true
}

build_and_run() {
    kill_game
    echo "Building..."
    if odin build src -out:$EXE -debug; then
        echo "Running..."
        ./$EXE &
    else
        echo "Build failed."
    fi
}

build_and_run

fswatch -o src/ | while read; do
    build_and_run
done
