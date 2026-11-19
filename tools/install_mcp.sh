#!/bin/sh
# Set up the Godot MCP server and editor plugin locally (optional, for AI-assisted development
# with Claude Code). Everything it creates is ignored by git:
#   addons/godot_mcp/            the editor plugin
#   .mcp.json                    the MCP server definition
#   .claude/settings.local.json  approves the server and its tools
# It also sets up a git filter so the plugin's entries in project.godot stay out of commits.
# Needs node (npx). Close the Godot editor first. Run again after changing VERSION to update.
VERSION=4.3.0
PACKAGE="@satelliteoflove/godot-mcp@$VERSION"
cd "$(dirname "$0")/.." || exit 1

if [ "$1" != "--no-download" ]; then
	npx -y "$PACKAGE" --install-addon . || exit 1
fi

mkdir -p .claude
PACKAGE="$PACKAGE" node -e '
	const fs = require("fs");
	const read = (p) => fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf8")) : {};
	const write = (p, v) => fs.writeFileSync(p, JSON.stringify(v, null, 2) + "\n");
	const add = (list, item) => list.includes(item) ? list : [...list, item];

	const mcp = read(".mcp.json");
	mcp.mcpServers = { ...mcp.mcpServers, godot: { command: "npx", args: ["-y", process.env.PACKAGE] } };
	write(".mcp.json", mcp);

	const local = read(".claude/settings.local.json");
	local.enabledMcpjsonServers = add(local.enabledMcpjsonServers || [], "godot");
	local.permissions = local.permissions || {};
	local.permissions.allow = add(local.permissions.allow || [], "mcp__godot");
	write(".claude/settings.local.json", local);
' || exit 1

git config filter.godot-mcp.clean "tools/mcp_filter.sh clean"
git config filter.godot-mcp.smudge "tools/mcp_filter.sh smudge"
tmp="$(mktemp)" && tools/mcp_filter.sh smudge < project.godot > "$tmp" && cat "$tmp" > project.godot
rm -f "$tmp"
git update-index -q --refresh
echo "Godot MCP $VERSION set up. Open the Godot editor, then restart Claude Code."
