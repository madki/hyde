#!/bin/sh
# Search the numbers of a persona for a way of playing that clears more rounds than a named
# one (sim/tune.gd). Every candidate is played with tools/sim.sh and kept as a batch under
# sim_data/, so a search run again, or run for more rounds, plays only what is new. The
# persona found is written to sim/personas_found.json as `found-<start>` and shown beside
# its start on seeds the search did not play.
# Usage: tools/sim_tune.sh start=dance [rounds=8] [tries=6] [seeds=150] [from=1000]
#                          [show=0-300] [seed=1] [z=2] [z2=1]
#        TUNE_TIMEOUT=seconds tools/sim_tune.sh ...   (time limit of each step, 300 by default)
#        SIM_JOBS and SIM_TIMEOUT are tools/sim.sh's.
cd "$(dirname "$0")/.." || exit 1
godot="${GODOT:-godot}"
limit="${TUNE_TIMEOUT:-300}"
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
		echo "TUNE FAILED: $1 did not finish in ${limit}s, stopped"
		exit 1
	fi
	if [ "$code" -ne 0 ] || grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|TUNE FAILED' "$log"; then
		cat "$log"
		grep -q 'TUNE FAILED' "$log" || echo "TUNE FAILED: $1"
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

played=0
steps=0
while :; do
	run_godot -s res://sim/tune.gd -- "$@"
	check "the search"
	if ! grep -q '^TUNE PLAY' "$log"; then
		# The search is over: its rounds, and the persona found.
		sed -e '/^Godot Engine v/d' -e '/^$/d' "$log"
		echo "TUNE played $played batches"
		exit 0
	fi
	grep '^TUNE AT' "$log"
	# A search that asks for the same batches for ever has gone wrong.
	steps=$((steps + 1))
	if [ "$steps" -gt 2000 ]; then
		echo "TUNE FAILED: the search does not end"
		exit 1
	fi
	plays="$(grep '^TUNE PLAY' "$log")"
	while IFS="|" read -r _ name a b player force; do
		set_name=""
		[ -n "$name" ] && set_name="name=$name"
		# shellcheck disable=SC2086
		out="$(tools/sim.sh "player=$player" "from=$a" "to=$b" $set_name $force)" || {
			echo "$out"
			echo "TUNE FAILED: the batch of $player was not played"
			exit 1
		}
		played=$((played + 1))
	done <<EOF
$plays
EOF
done
