class_name SimPersonas
## The numbers of each way of playing the card game, by name, for the player of
## sim/players/persona.gd: one policy, shaped by these numbers.

## More personas, by name, as a JSON Dictionary of name to changed numbers. The file may be
## absent. A name of NAMED is never looked up there.
const FOUND_PATH := "res://sim/personas_found.json"

## Every number of a persona, with the value it has when a persona does not change it.
const DEFAULTS := {
	# --- who has the table ---
	## Drinks of his own will once restraint is at least this (99: only when a breakout is
	## the other choice).
	"drink_at": 4,
	## Drinks as soon as the draught exists, whatever the restraint.
	"drink_asap": false,
	## Drinks rather than break out.
	"forced_drink": true,
	## Never drinks of his own will if Paper would lead Ink by less than this afterwards.
	"drink_min_cushion": 0,
	## Plays as Hyde before taking salt to come back (99: stays).
	"hyde_stay": 99,
	## As Hyde, takes salt when Paper leads by this or less and there is a Root to turn.
	"salt_cushion": 1,
	## Doses the plain return never spends.
	"salt_reserve": 0,
	## Is Jekyll for the scene Hyde is hunted in.
	"scene_aware": true,
	# --- what a play is worth, in shares of the round's target ---
	## For each Root a Sublimation turns, times how near the line is.
	"w_turn": 0.15,
	## For each point of Temper a Sublimation gains.
	"w_temper": 0.10,
	## Taken off a play of Jekyll's that fills the meter.
	"w_break": 0.6,
	## For each copy a play of Hyde's breeds.
	"w_habit": 0.12,
	## A play of Hyde's that breeds loses worth when Paper would lead by less than this.
	"min_cushion": 1,
	## A discard is made when the hand it is expected to give is worth this many times the
	## hand held.
	"discard_gain": 1.08,
	## The redraws tried for each discard.
	"samples": 5,
	# --- dawn and rewards ---
	## The laboratory's instruments to buy, dearest wish first.
	"inst_pref": ["balance", "saucers", "spirit", "notebook"],
	## His instruments to take in the alley, dearest wish first.
	"alley_inst": ["hcane", "cheque"],
	## What a card is worth as a reward or on the shelf. A reward is taken over 0.5, a card
	## bought over 0.7.
	"card_lamp": 1.0, "card_heart": 1.0, "card_mirror": 1.2,
	"card_cup": 0.6, "card_eye": 0.2, "card_lock": 0.8, "card_pen": 2.0, "card_cane": 1.6,
	## More for a Paper Root, times how near the line is.
	"paper_w": 0.6,
	## Doses to hold when leaving a place.
	"salt_target": 2,
	## Strikes his Roots while Paper leads by less than `strike_cushion`.
	"strike_ink": true,
	"strike_cushion": 3,
	## The Factors struck, one of each, when money is left over.
	"strike_kinds": [],
	# --- habits: one thing the policy does, taken away ---
	## Never plays a Sublimation.
	"no_turn": false,
	## Never discards while it has a play.
	"no_discard": false,
	## What it buys: "all" as the numbers above say, "salt" nothing but salt, "dearest" the
	## dearest thing it can pay for, whatever it is.
	"buys": "all",
}

## The numbers a persona changes, by its name.
const NAMED := {
	# Stays himself. Drinks only when a breakout is the other choice, and takes salt after
	# Hyde's one stored hand.
	"jekyll": {
		"drink_at": 99, "hyde_stay": 1, "salt_target": 3,
		"card_lock": 2.2, "card_pen": 2.0, "card_cane": 1.6, "inst_pref": ["balance", "saucers", "spirit"],
	},
	# Fills the meter, drinks for the stored hand, stays a few plays, comes back to turn what
	# he bred.
	"dance": {"drink_at": 4, "hyde_stay": 3, "salt_target": 3, "inst_pref": ["saucers", "balance", "spirit"]},
	# Back and forth as often as the salt allows.
	"pendulum": {"drink_at": 3, "hyde_stay": 2, "salt_target": 5, "inst_pref": ["saucers", "balance", "spirit"]},
	# A wide deck: takes every card, strikes nothing.
	"wide": {
		"drink_at": 4, "hyde_stay": 3, "salt_target": 3, "paper_w": 1.5, "strike_ink": false,
		"card_cup": 1.0, "card_eye": 0.8, "card_lock": 1.0, "inst_pref": ["saucers", "balance", "spirit"],
	},
	# A pruned deck: takes only the best Factors, strikes his Roots and the weak Factors.
	"thin": {
		"drink_at": 4, "hyde_stay": 3, "salt_target": 3, "paper_w": 0.0,
		"card_lamp": 0.0, "card_heart": 0.0, "card_mirror": 0.0, "card_cup": 0.0, "card_eye": 0.0, "card_lock": 0.6,
		"strike_cushion": 99, "strike_kinds": ["eye"], "inst_pref": ["saucers", "spirit", "balance"],
	},
	# On the edge: lives as Hyde, comes back only when the line is about to go.
	"edge": {
		"drink_at": 3, "hyde_stay": 99, "salt_cushion": 1, "salt_target": 2, "w_habit": 0.2, "min_cushion": 0,
		"inst_pref": ["saucers", "spirit", "balance"],
	},
	# Hyde as soon as the draught exists, and never back by choice. Cunning holds the line.
	"hyde": {
		"drink_asap": true, "hyde_stay": 99, "salt_cushion": -9, "salt_target": 0, "scene_aware": false,
		"w_habit": 0.2, "min_cushion": 1, "paper_w": 1.2, "inst_pref": ["spirit", "balance"],
	},
	# The players with one human habit each: `dance`, with one thing taken away.
	# Never drinks unless a breakout is the other choice, and never buys salt.
	"nodrink": {"based_on": "dance", "drink_at": 99, "salt_target": 0},
	# Never plays a Sublimation.
	"noturn": {"based_on": "dance", "no_turn": true},
	# Always the highest score: no weights.
	"bighand": {"based_on": "dance", "w_turn": 0.0, "w_temper": 0.0, "w_break": 0.0, "w_habit": 0.0, "min_cushion": -99},
	# Buys nothing but salt.
	"hoarder": {"based_on": "dance", "buys": "salt"},
	# Buys the dearest thing on the shelf, whatever it is.
	"spender": {"based_on": "dance", "buys": "dearest"},
	# Never discards.
	"nodiscard": {"based_on": "dance", "no_discard": true},
}


## The names of the personas of this file, in order.
static func names() -> Array:
	return NAMED.keys()


## Every number of the persona of this name: DEFAULTS for "", a persona of NAMED, or one of
## the file at `found_path`. {} when there is none of that name.
static func numbers(name: String, found_path: String = FOUND_PATH) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	if name == "":
		return out
	var changes: Dictionary = {}
	if NAMED.has(name):
		changes = NAMED[name]
	else:
		var found := read_found(found_path)
		if not found.get(name) is Dictionary:
			return {}
		changes = found[name]
		var wrong := faults(changes)
		if not wrong.is_empty():
			push_error("The persona %s of %s cannot be read: %s" % [name, found_path, "; ".join(wrong)])
			return {}
	var base := str(changes.get("based_on", ""))
	if base != "" and NAMED.has(base) and base != name:
		change(out, NAMED[base])
	change(out, changes)
	return out


## Puts changed numbers into a persona's numbers, each as the kind of value its default is
## (a list may be given as a text, "a+b"). Returns the keys that are no number of a persona.
static func change(into: Dictionary, changes: Dictionary) -> Array:
	var unknown: Array = []
	for key: Variant in changes:
		if key == "based_on":
			continue
		if not DEFAULTS.has(key):
			unknown.append(key)
			continue
		var v: Variant = changes[key]
		match typeof(DEFAULTS[key]):
			TYPE_INT: into[key] = int(v)
			TYPE_FLOAT: into[key] = float(v)
			TYPE_BOOL: into[key] = true if v is String and v == "true" else (false if v is String else bool(v))
			TYPE_STRING: into[key] = str(v)
			TYPE_ARRAY:
				if v is Array:
					into[key] = (v as Array).duplicate()
				else:
					into[key] = Array(str(v).split("+", false))
	return unknown


## What is wrong with a persona of a file, one line each: a number no persona has, a value
## that is not of its number's kind, a start that is no persona of NAMED. A file is checked,
## where a number given by hand is read as its kind: a file that is out of date must not
## play as if it were not.
static func faults(entry: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in entry:
		var v: Variant = entry[key]
		if key == "based_on":
			if not (v is String and NAMED.has(v)):
				out.append("based_on is no persona: %s" % str(v))
			continue
		if not DEFAULTS.has(key):
			out.append("no such number: %s" % str(key))
			continue
		var fits := false
		match typeof(DEFAULTS[key]):
			TYPE_INT: fits = v is int or (v is float and v == floor(v))
			TYPE_FLOAT: fits = v is int or v is float
			TYPE_BOOL: fits = v is bool
			TYPE_STRING: fits = v is String
			TYPE_ARRAY: fits = v is Array
		if not fits:
			out.append("%s is not of its kind: %s" % [key, str(v)])
	return out


## The personas of a JSON file, name to changed numbers. {} if the file is absent or is not
## a Dictionary.
static func read_found(path: String = FOUND_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		return data
	return {}
