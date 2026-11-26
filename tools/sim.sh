#!/bin/sh
# Play a batch of headless runs of the card game with a scripted player, and keep them under
# sim_data/<rules version>/<batch>/ (manifest.json and runs.jsonl). Prints one line: wins,
# rounds cleared, seconds. A batch already on disk is not played again without `force`.
# Usage: tools/sim.sh player=greedy from=0 to=300 [name=batch] [give=a+b] [d.<dial>=<json>] [force]
#        SIM_JOBS=n tools/sim.sh ...      (processes; the cores less two by default)
#        SIM_TIMEOUT=seconds tools/sim.sh ...   (time limit of each step, 600 by default)
cd "$(dirname "$0")/.." || exit 1
godot="${GODOT:-godot}"
limit="${SIM_TIMEOUT:-600}"
tmp="$(mktemp -d)"
pids=""
trap 'for p in $pids; do kill -9 "$p" 2>/dev/null; done; rm -rf "$tmp"' EXIT
trap 'exit 1' INT TERM

# Waits for the processes in `pids`, and stops them if they take longer than the time limit.
# Sets `timed_out`, and `code` to 1 if any of them failed.
wait_all() {
	ticks=0
	timed_out=0
	code=0
	while :; do
		alive=0
		for p in $pids; do
			kill -0 "$p" 2>/dev/null && alive=1
		done
		[ "$alive" = 0 ] && break
		if [ "$ticks" -ge $((limit * 5)) ]; then
			for p in $pids; do kill -9 "$p" 2>/dev/null; done
			timed_out=1
			break
		fi
		sleep 0.2
		ticks=$((ticks + 1))
	done
	for p in $pids; do
		wait "$p" 2>/dev/null || code=1
	done
	pids=""
}

# Runs Godot headless with the given arguments, its output in the log, under the time limit.
run_godot() {
	GODOT_MCP_DISABLE_SERVER=1 "$godot" --headless --path . "$@" >"$tmp/log" 2>&1 &
	pids=$!
	wait_all
}

# Stops with the log if the step just run failed.
check() {
	if [ "$timed_out" = 1 ]; then
		cat "$tmp"/log*
		echo "SIM FAILED: $1 did not finish in ${limit}s, stopped"
		exit 1
	fi
	if [ "$code" -ne 0 ] || grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|SIM FAILED' "$tmp"/log*; then
		cat "$tmp"/log*
		echo "SIM FAILED: $1"
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

run_godot -s res://sim/run_sims.gd -- "$@" step=plan
check "the batch could not be planned"
if grep -q '^SIM HAVE' "$tmp/log"; then
	grep '^SIM ' "$tmp/log" | grep -v '^SIM HAVE'
	exit 0
fi
grep '^SIM STALE' "$tmp/log" || true
name="$(sed -n 's/^SIM NAME //p' "$tmp/log")"
seeds="$(sed -n 's/^SIM SEEDS //p' "$tmp/log")"
started="$(sed -n 's/^SIM START //p' "$tmp/log")"
from="${seeds% *}"
to="${seeds#* }"
if [ -z "$name" ] || [ -z "$seeds" ] || [ -z "$started" ]; then
	cat "$tmp/log"
	echo "SIM FAILED: the batch could not be planned"
	exit 1
fi

# One process for each share of the seeds.
cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
jobs="${SIM_JOBS:-$((cores - 2))}"
runs=$((to - from))
[ "$jobs" -gt "$runs" ] && jobs="$runs"
[ "$jobs" -lt 1 ] && jobs=1
rm -f "$tmp/log"
i=0
while [ "$i" -lt "$jobs" ]; do
	a=$((from + runs * i / jobs))
	b=$((from + runs * (i + 1) / jobs))
	GODOT_MCP_DISABLE_SERVER=1 "$godot" --headless --path . -s res://sim/run_sims.gd -- \
		"$@" "name=$name" "from=$a" "to=$b" step=play >"$tmp/log.$i" 2>&1 &
	pids="$pids $!"
	i=$((i + 1))
done
wait_all
check "the runs"
# A move the rules refused is an error of the player's: show it, and keep the batch.
grep -h '^ERROR' "$tmp"/log.* | sort | uniq -c | head -n 20
rm -f "$tmp"/log.*

commit="$(git rev-parse HEAD 2>/dev/null)"
dirty=0
[ -n "$(git status --porcelain 2>/dev/null)" ] && dirty=1
run_godot -s res://sim/run_sims.gd -- "$@" "name=$name" "from=$from" "to=$to" step=join \
	"commit=$commit" "dirty=$dirty" "started=$started"
check "the batch could not be joined"
grep '^SIM ' "$tmp/log"
