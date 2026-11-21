#!/bin/sh
# Re-bake the street background textures into art/bg/ (desktop only, uses the Forward+ renderer).
# Usage: tools/bake_bg.sh [--variant=jekyll|hyde] [--passes=/abs/dir]   then run tools/check.sh
# The figures are a separate layer: tools/bake_figures.sh.
# Takes about ten seconds. The bake renders in a window, and macOS stops drawing windows while
# the display sleeps, so keep the display awake for the duration.
cd "$(dirname "$0")/.." || exit 1
# Each street has its man's mesh in it; the other pictures have scripts of their own.
case " $* " in
	*" --variant=jekyll "*) tools/need_figures.sh jekyll || exit 1 ;;
	*" --variant=hyde "*) tools/need_figures.sh hyde || exit 1 ;;
	*" --variant="*) ;;
	*) tools/need_figures.sh jekyll hyde || exit 1 ;;
esac
if command -v caffeinate >/dev/null 2>&1; then caffeinate -u -d -t 60 & fi
GODOT_MCP_DISABLE_SERVER=1 exec "${GODOT:-godot}" --path . --rendering-method forward_plus res://studio/bake.tscn -- "$@"
