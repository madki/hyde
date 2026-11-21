#!/bin/sh
# Re-bake the figure layer: the two men and the flipbook of one turning into the other,
# art/bg/figures.png and art/bg/figures_depth.png (desktop only, uses the Forward+ renderer).
# Usage: tools/bake_figures.sh [--frames=/abs/dir] [--time=1.2]   then run tools/check.sh
# The first run also builds the figures' distance fields (about half a minute). The bake renders
# in a window, and macOS stops drawing windows while the display sleeps, so keep it awake.
cd "$(dirname "$0")/.." || exit 1
tools/need_figures.sh jekyll hyde || exit 1
if command -v caffeinate >/dev/null 2>&1; then caffeinate -u -d -t 180 & fi
GODOT_MCP_DISABLE_SERVER=1 exec "${GODOT:-godot}" --path . --rendering-method forward_plus res://studio/figure_bake.tscn -- "$@"
