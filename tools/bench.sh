#!/bin/sh
# Measure the rules' speed: plays whole runs headless with one fixed player and prints a hash
# of every state they pass through and the time a run takes, then the time of one reading of
# a play, one search for the best play and one copy of a run. The hash must be the same
# before and after a change that only makes the rules faster. Exits non-zero if a script
# error is printed or the run takes longer than the time limit.
# Usage: tools/bench.sh [runs=200] [calls=10000] [check]
#        (check also compares the quick functions with the full ones at every move)
#        BENCH_TIMEOUT=seconds tools/bench.sh   (time limit, 300 by default)
cd "$(dirname "$0")/.." || exit 1
godot="${GODOT:-godot}"
limit="${BENCH_TIMEOUT:-300}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# Runs Godot headless with the given arguments, writing its output to the log, and stops it
# if it takes longer than the time limit. Sets `code` to its exit code and `timed_out`.
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
}

# Bring the list of script classes up to date first, so a new class_name is known.
run_godot --import
if [ "$timed_out" = 1 ]; then
	cat "$log"
	echo "BENCH FAILED: the import did not finish in ${limit}s, stopped"
	exit 1
fi
if [ "$code" -ne 0 ]; then
	cat "$log"
	echo "BENCH FAILED: the import failed"
	exit 1
fi

run_godot -s res://tests/bench.gd -- "$@"
grep -E '^BENCH|SCRIPT ERROR|Parse Error|Compile Error|^ERROR' "$log" || cat "$log"

if [ "$timed_out" = 1 ]; then
	echo "BENCH FAILED: no result after ${limit}s, stopped"
	exit 1
fi
if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error' "$log"; then
	cat "$log"
	echo "BENCH FAILED: a script error was printed"
	exit 1
fi
if [ "$code" -ne 0 ] || ! grep -q '^BENCH DONE' "$log"; then
	echo "BENCH FAILED"
	exit 1
fi
