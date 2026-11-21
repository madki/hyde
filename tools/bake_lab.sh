#!/bin/sh
# Re-bake the laboratory picture into art/bg/: lab_a.png and lab_b.png (its light passes) and
# lab_c.png (Jekyll's own colours).
# Jekyll in his chair is part of the picture, so there is no figure layer to bake.
# Desktop only, uses the Forward+ renderer.
# Usage: tools/bake_lab.sh [--passes=/abs/dir] [--rebuild]   then run tools/check.sh
# `--rebuild` OVERWRITES studio/lab.tscn with a fresh one from studio/lab_builder.gd.
# The bake renders in a window, and macOS stops drawing windows while the display sleeps, so
# keep it awake for the duration.
cd "$(dirname "$0")/.." || exit 1
if command -v caffeinate >/dev/null 2>&1; then caffeinate -u -d -t 60 & fi
GODOT="${GODOT:-godot}"
GODOT_MCP_DISABLE_SERVER=1 exec "$GODOT" --path . --rendering-method forward_plus res://studio/bake.tscn -- --variant=lab "$@"
