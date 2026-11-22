#!/bin/sh
# Render the game for a few frames and save a screenshot, under a time limit.
# Usage: tools/shot.sh /abs/out.png [res://scene.tscn] [game args...]
# With a scene, that screen is run instead of the main scene; the game args reach it either way.
# The screen must call Shot.run_if_requested(self) in _ready (scripts/shot.gd).
cd "$(dirname "$0")/.." || exit 1
out="${1:?output png path}"; shift
scene=""
case "${1:-}" in
	res://*) scene="$1"; shift ;;
esac
# A screen that never takes the shot would leave the game running: stop it after a minute.
exec perl -e 'alarm 60; exec @ARGV' "${GODOT:-godot}" --path . $scene -- --shot="$out" "$@"
