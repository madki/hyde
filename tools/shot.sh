#!/bin/sh
# Render the game for a few frames and save a screenshot. Usage: tools/shot.sh /abs/out.png [game args...]
# Needs a main scene that calls Shot.run_if_requested(self) in _ready (scripts/shot.gd).
cd "$(dirname "$0")/.." || exit 1
out="${1:?output png path}"; shift
exec "${GODOT:-godot}" --path . -- --shot="$out" "$@"
