#!/usr/bin/env bash
set -eu

EXE=build/labyrinth

mkdir -p build

odin build src -out:$EXE -debug

./$EXE
