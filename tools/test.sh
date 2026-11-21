#!/bin/sh
# Run the headless tests: every test_* method of every tests/test_*.gd. Exits non-zero if a
# check fails, a script error is printed, or the run takes longer than the time limit.
# Usage: tools/test.sh [text]   (only tests whose "file:method" name holds the text)
#        TEST_TIMEOUT=seconds tools/test.sh   (time limit, 120 by default)
cd "$(dirname "$0")/.." || exit 1
godot="${GODOT:-godot}"
limit="${TEST_TIMEOUT:-120}"
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
	echo "TESTS FAILED: the import did not finish in ${limit}s, stopped"
	exit 1
fi
if [ "$code" -ne 0 ]; then
	cat "$log"
	echo "TESTS FAILED: the import failed"
	exit 1
fi

run_godot -s res://tests/run_tests.gd -- "$@"
cat "$log"

if [ "$timed_out" = 1 ]; then
	echo "TESTS FAILED: no result after ${limit}s, stopped"
	exit 1
fi
if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error' "$log"; then
	echo "TESTS FAILED: a script error was printed"
	exit 1
fi
if [ "$code" -ne 0 ] || ! grep -q '^TESTS PASSED' "$log"; then
	echo "TESTS FAILED"
	exit 1
fi
