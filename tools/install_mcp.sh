#!/bin/sh
# Install the Godot MCP editor plugin locally (optional, for AI-assisted development).
# The plugin lives in addons/godot_mcp/, which is ignored by git. This script also sets up
# a git filter so the plugin's entries in project.godot stay out of commits.
# Needs node (npx). Close the Godot editor first. Safe to run again to update the plugin.
cd "$(dirname "$0")/.." || exit 1
if [ "$1" != "--no-download" ]; then
	npx -y @satelliteoflove/godot-mcp --install-addon . || exit 1
fi
git config filter.godot-mcp.clean "tools/mcp_filter.sh clean"
git config filter.godot-mcp.smudge "tools/mcp_filter.sh smudge"
tmp="$(mktemp)" && tools/mcp_filter.sh smudge < project.godot > "$tmp" && cat "$tmp" > project.godot
rm -f "$tmp"
git update-index -q --refresh
echo "Godot MCP plugin installed and enabled. Open the Godot editor, then restart Claude Code."
