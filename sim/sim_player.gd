class_name SimPlayer
extends RefCounted
## A player of whole runs of the card game, for the sims. One kind of player is one file of
## sim/players/, found by its file name: there is no table of them.
##
## A player must not cheat. It never reads the order of `run.draw`, never calls the run's
## generator, and never changes the run it is given except through Rules' moves in `between`.
## To look ahead it takes `run.copy()` and calls `SimMoves.hide(copy, rng)`.

const PLAYERS_DIR := "res://sim/players/"

## The player as it was named: "file", "file.variant" or "file.variant?key=value&key=value".
var name: String = ""
var variant: String = ""
var params: Dictionary = {}
## The player's own generator. `begin` seeds it, so one seed gives one run.
var rng := RandomNumberGenerator.new()


## The player of this name, set up, or null (with an error) if there is no such file.
static func make(spec: String) -> SimPlayer:
	var parts := parse(spec)
	var path: String = PLAYERS_DIR + str(parts.file) + ".gd"
	if not str(parts.file).is_valid_filename() or not ResourceLoader.exists(path):
		push_error("No such player: %s" % spec)
		return null
	var script: GDScript = ResourceLoader.load(path)
	if script == null or not script.can_instantiate():
		push_error("The player %s did not load" % spec)
		return null
	var made: Variant = script.new()
	if not made is SimPlayer:
		push_error("%s is not a SimPlayer" % path)
		return null
	var player: SimPlayer = made
	player.name = spec
	player.variant = parts.variant
	player.params = parts.params
	player.setup(parts.variant, parts.params)
	return player


## A player's name in its parts: {file, variant, params}. A value of `params` is read as JSON
## (8 is a number, true a truth) and is a text when it is not JSON.
static func parse(spec: String) -> Dictionary:
	var out := {"file": "", "variant": "", "params": {}}
	var q := spec.find("?")
	var head := spec if q < 0 else spec.substr(0, q)
	var dot := head.find(".")
	out.file = head if dot < 0 else head.substr(0, dot)
	out.variant = "" if dot < 0 else head.substr(dot + 1)
	if q >= 0:
		for pair in spec.substr(q + 1).split("&", false):
			var eq := pair.find("=")
			var key := pair if eq < 0 else pair.substr(0, eq)
			out.params[key] = true if eq < 0 else SimStore.read_value(pair.substr(eq + 1))
	return out


## Once, after the player is made.
@warning_ignore("unused_parameter")
func setup(variant_name: String, with_params: Dictionary) -> void:
	pass


## At the start of a run. Seeds the player's own generator.
@warning_ignore("unused_parameter")
func begin(run: RulesRun, run_seed: int) -> void:
	rng.seed = hash([run_seed, name])


## Before a search plays a copy on with this player: what it remembers of a run is of
## another copy, and is set to what this one shows.
@warning_ignore("unused_parameter")
func on_copy(copy: RulesRun) -> void:
	pass


## In phase "play": one move, {t: "play" | "discard" | "drink" | "salt" | "pass", ids: [...]}.
## It may add `options`: the moves it weighed, best first, each {t, ids, key, value} (`key`
## is the hand's key for a play).
@warning_ignore("unused_parameter")
func choose(run: RulesRun) -> Dictionary:
	return {"t": "pass", "ids": []}


## In phases "result", "lab" and "alley": makes that phase's moves itself and leaves it.
## Here: takes no reward, buys nothing, and goes on.
func between(run: RulesRun) -> void:
	SimMoves.leave(run)
