#!/bin/sh
# Re-bake the back-alley picture into art/bg/: alley_a.png and alley_b.png (the alley's light
# passes), then alley_figure.png and alley_figure_depth.png (the man at the door).
# Desktop only, uses the Forward+ renderer.
# Usage: tools/bake_alley.sh [--passes=/abs/dir] [--rebuild]   then run tools/check.sh
# `--rebuild` OVERWRITES studio/alley.tscn with a fresh one from studio/alley_builder.gd.
# The bake renders in a window, and macOS stops drawing windows while the display sleeps, so
# keep it awake for the duration.
cd "$(dirname "$0")/.." || exit 1
tools/need_figures.sh hyde || exit 1
if command -v caffeinate >/dev/null 2>&1; then caffeinate -u -d -t 60 & fi
GODOT="${GODOT:-godot}"
GODOT_MCP_DISABLE_SERVER=1 "$GODOT" --path . --rendering-method forward_plus res://studio/bake.tscn -- --variant=alley "$@" || exit 1
GODOT_MCP_DISABLE_SERVER=1 exec "$GODOT" --path . --rendering-method forward_plus res://studio/alley_figure_bake.tscn -- "$@"
