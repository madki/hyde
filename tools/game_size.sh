#!/bin/sh
# Print how big the shipped (Web) game would be. Usage: tools/game_size.sh [--log]
#
# The game data is an estimate, added up without exporting: every committed file the Web
# preset would pack (export_presets.cfg leaves out studio/, tools/, docs/ and build/), at the
# size of its imported form in .godot/imported where it has one. The engine is the size of the
# files of the last real export in build/web (tools/export_web.sh), if there is one; that
# export's own total is printed too, with its date, to check the estimate against.
# `--log` also appends the figures to build/size.log (not committed), one line per commit.
# tools/install_hooks.sh makes git run this after every commit.
cd "$(dirname "$0")/.." || exit 1

size() { wc -c < "$1" 2>/dev/null | tr -d ' '; }
mb() { awk -v b="$1" 'BEGIN { printf "%.1f MB", b / 1048576 }'; }

# Folders the export preset leaves out, as a pattern: "build/*, tools/*" -> "^(build/|tools/)".
skip="$(sed -n 's/^exclude_filter="\(.*\)"$/\1/p' export_presets.cfg | head -1 \
	| sed 's/ //g; s/\*//g; s/,/|/g')"

data=0
for f in $(git ls-files | grep -Ev "^(${skip:-build/})" | grep -Ev '\.(import|uid|md|sh|cfg|mjs|json)$' \
		| grep -Ev '(^|/)(LICENSE|\.gitignore|\.gitattributes|\.gdignore)$'); do
	[ -f "$f" ] || continue
	if [ -f "$f.import" ]; then
		# What ships is the imported form (there can be more than one file of it).
		found=0
		for d in $(sed -n 's/^dest_files=\[\(.*\)\]$/\1/p' "$f.import" | tr -d '"' | tr ',' ' '); do
			p="${d#res://}"
			[ -f "$p" ] && { data=$((data + $(size "$p"))); found=1; }
		done
		[ "$found" = 1 ] || data=$((data + $(size "$f")))
	else
		data=$((data + $(size "$f")))
	fi
done

engine=0
export_total=0
export_note="no export in build/web yet, so the engine's size is not counted"
if [ -f build/web/index.wasm ]; then
	for f in build/web/*; do
		[ -f "$f" ] || continue
		export_total=$((export_total + $(size "$f")))
		case "$f" in *.pck) ;; *) engine=$((engine + $(size "$f"))) ;; esac
	done
	export_note="last real export: $(mb "$export_total") on $(date -r build/web/index.wasm +%Y-%m-%d)"
fi

total=$((data + engine))
echo "Shipped game (Web): about $(mb "$total") = $(mb "$data") game data (estimate) + $(mb "$engine") engine; $export_note"
if [ "$1" = "--log" ]; then
	echo "$(date +%Y-%m-%dT%H:%M) $(git rev-parse --short HEAD 2>/dev/null) total=$total data=$data engine=$engine last_export=$export_total" >> build/size.log
fi
