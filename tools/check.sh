#!/bin/sh
# Re-import assets and report script/scene errors, then exit. Safe to run while the editor is open.
cd "$(dirname "$0")/.." || exit 1
GODOT_MCP_DISABLE_SERVER=1 exec "${GODOT:-godot}" --headless --path . --import
