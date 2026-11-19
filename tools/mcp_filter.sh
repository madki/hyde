#!/bin/sh
# Git filter that keeps the local-only Godot MCP plugin out of the committed project.godot.
#   clean  (on git add):      strips the plugin's entries, so they are never committed
#   smudge (on git checkout): puts them back, if the addon is installed
# Reads project.godot on stdin, writes it on stdout. Set up by tools/install_mcp.sh.
mode="${1:?clean or smudge}"
[ "$mode" = smudge ] && [ ! -f addons/godot_mcp/plugin.cfg ] && exec cat
MODE="$mode" exec perl -0777 -pe '
	my $cfg = q{"res://addons/godot_mcp/plugin.cfg"};
	# clean: the autoload, the plugin in the enabled list, the plugin settings section
	s/^MCPGameBridge=.*\n//mg;
	s/^\[godot_mcp\]\n(?:(?!\[).*\n?)*//mg;
	s/\Q$cfg\E,\s*//g; s/,\s*\Q$cfg\E//g; s/\Q$cfg\E//g;
	s/^enabled=PackedStringArray\(\)\n//mg;
	s/^\[[^\]\n]+\]\n\s*(?=^\[|\z)//mg; # sections left empty
	s/\s*\z/\n/;
	if ($ENV{MODE} eq "smudge") {
		my $bridge = qq{MCPGameBridge="res://addons/godot_mcp/game_bridge/mcp_game_bridge.gd"\n};
		s/^(\[autoload\]\n\n?)/$1$bridge/m or $_ .= "\n[autoload]\n\n$bridge";
		s/^(\[editor_plugins\]\n\n?enabled=PackedStringArray\()/$1$cfg, /m
			or $_ .= "\n[editor_plugins]\n\nenabled=PackedStringArray($cfg)\n";
		$_ .= qq{\n[godot_mcp]\n\nbind_mode=0\ncustom_bind_ip=""\nport_override_enabled=false\nport_override=6550\n};
	}
'
