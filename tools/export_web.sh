#!/bin/sh
# Export the Web build to build/web/ (needs the Godot web export templates installed).
# Close the Godot editor first: project.godot is swapped for a copy without the local-only
# MCP plugin while the export runs, so the plugin never ships in the build.
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/web
backup="$(mktemp)" || exit 1
cp project.godot "$backup"
restore() { cat "$backup" > project.godot; rm -f "$backup"; }
trap restore EXIT
trap 'exit 1' INT TERM
tools/mcp_filter.sh clean < "$backup" > project.godot
GODOT_MCP_DISABLE_SERVER=1 "${GODOT:-godot}" --headless --path . --export-release "Web" build/web/index.html
