#!/usr/bin/env bash
set -eu

EXE=build/labyrinth_editor

mkdir -p build

odin build src -out:$EXE -debug -define:EDITOR=true

./$EXE
