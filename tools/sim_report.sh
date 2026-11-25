#!/bin/sh
# Read batches of sim runs back from sim_data/ and print what happened in them: wins and
# endings, each round (who reaches it, who dies there and how, plays used, the stance), the
# hands played by night, the instruments held, the rounds that are lulls and the swings.
# Usage: tools/sim_report.sh [batch ...]       (every batch of the rules' version of now when
#                                               none is named; a batch is a name or a folder)
#        tools/sim_report.sh --compare a b     (two batches side by side, differences marked)
#        tools/sim_report.sh --csv ...         (also write the tables as files beside the batch)
#        REPORT_TIMEOUT=seconds tools/sim_report.sh ...   (time limit of each step, 300 by default)
cd "$(dirname "$0")/.." || exit 1
godot="${GODOT:-godot}"
limit="${REPORT_TIMEOUT:-300}"
log="$(mktemp)"
pid=""
trap '[ -n "$pid" ] && kill -9 "$pid" 2>/dev/null; rm -f "$log"' EXIT
trap 'exit 1' INT TERM

# Runs Godot headless with the given arguments, its output in the log, and stops it if it
# takes longer than the time limit. Sets `code` to its exit code and `timed_out`.
run_godot() {
	GODOT_MCP_DISABLE_SERVER=1 "$godot" --headless --path . "$@" >"$log" 2>&1 &
	pid=$!
	ticks=0
	timed_out=0
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$ticks" -ge $((limit * 5)) ]; then
			kill -9 "$pid" 2>/dev/null
			timed_out=1
			break
		fi
		sleep 0.2
		ticks=$((ticks + 1))
	done
	wait "$pid" 2>/dev/null
	code=$?
	pid=""
}

# Stops with the log if the step just run failed.
check() {
	if [ "$timed_out" = 1 ]; then
		cat "$log"
		echo "REPORT FAILED: $1 did not finish in ${limit}s, stopped"
		exit 1
	fi
	if [ "$code" -ne 0 ] || grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|REPORT FAILED' "$log"; then
		cat "$log"
		grep -q 'REPORT FAILED' "$log" || echo "REPORT FAILED: $1"
		exit 1
	fi
}

# Bring the list of script classes up to date when a script is newer than it.
classes=".godot/global_script_class_cache.cfg"
if [ ! -f "$classes" ] || [ -n "$(find sim scripts -name '*.gd' -newer "$classes" 2>/dev/null | head -n 1)" ]; then
	run_godot --import
	check "the import"
	[ -f "$classes" ] && touch "$classes"
fi

run_godot -s res://sim/sim_report.gd -- "$@"
check "the report"
# The report, without the engine's own first lines.
sed -e '/^Godot Engine v/d' -e '1{/^$/d;}' "$log" | sed -e '1{/^$/d;}'
