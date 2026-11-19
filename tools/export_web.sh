#!/bin/sh
# Export the Web build to build/web/ (needs the Godot web export templates installed).
cd "$(dirname "$0")/.." || exit 1
mkdir -p build/web
GODOT_MCP_DISABLE_SERVER=1 exec "${GODOT:-godot}" --headless --path . --export-release "Web" build/web/index.html
