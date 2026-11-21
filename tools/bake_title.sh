#!/bin/sh
# Re-bake the title screen's pictures into art/bg/: the two streets with the shadow of the man
# who stands in them (title_jekyll_a.png, _b.png, title_hyde_a.png, _b.png), then the men
# themselves (title_figures.png, title_figures_depth.png). Where they stand: studio/title_street.gd.
# Desktop only, uses the Forward+ renderer.
# Usage: tools/bake_title.sh [--passes=/abs/dir] [--frames=/abs/dir]   then run tools/check.sh
# The bake renders in a window, and macOS stops drawing windows while the display sleeps, so
# keep it awake for the duration.
cd "$(dirname "$0")/.." || exit 1
tools/need_figures.sh jekyll jekyll_title hyde || exit 1
if command -v caffeinate >/dev/null 2>&1; then caffeinate -u -d -t 90 & fi
GODOT="${GODOT:-godot}"
GODOT_MCP_DISABLE_SERVER=1 "$GODOT" --path . --rendering-method forward_plus res://studio/bake.tscn -- --variant=title_jekyll "$@" || exit 1
GODOT_MCP_DISABLE_SERVER=1 "$GODOT" --path . --rendering-method forward_plus res://studio/bake.tscn -- --variant=title_hyde "$@" || exit 1
GODOT_MCP_DISABLE_SERVER=1 exec "$GODOT" --path . --rendering-method forward_plus res://studio/title_figure_bake.tscn -- "$@"
