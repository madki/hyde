#!/bin/sh
# Re-bake the street background textures into art/bg/ (desktop only, uses the Forward+ renderer).
# Usage: tools/bake_bg.sh [--variant=jekyll|hyde] [--passes=/abs/dir]   then run tools/check.sh
# Takes about ten seconds. The bake renders in a window, and macOS stops drawing windows while
# the display sleeps, so keep the display awake for the duration.
cd "$(dirname "$0")/.." || exit 1
if command -v caffeinate >/dev/null 2>&1; then caffeinate -u -d -t 60 & fi
GODOT_MCP_DISABLE_SERVER=1 exec "${GODOT:-godot}" --path . --rendering-method forward_plus res://studio/bake.tscn -- "$@"
