class_name RulesDials
## The numbers a run plays by. The values here are the game's own. A run holds its own copy,
## so a test or a tuning pass can change one (Rules.new_run, RulesDials.make).

# A round.
var plays: int = 4
var discards: int = 3
var hand_size: int = 8
var max_play: int = 5
## The most cards one discard takes.
var max_discard: int = 5

# Chips.
var root_chips: int = 15
var factor_chips: int = 10
var glee_chips: int = 25
## A point of Craving, on every Ink Root of the symbol.
var craving_chips: int = 10
var habit_chips: int = 15
var temper_chips: int = 15

# Mult.
## Temperance (the Chalice).
var cheer_mult: int = 2
## Balance: a different symbol. Obsession: a Root of the largest matching set.
var pen_mult: int = 2
## Resolve and Surrender.
var cane_mult: int = 2
## A point of Habit, for every Ink Root of the symbol in the play.
var habit_mult: int = 1
## A point of Temper, once for a symbol in the play.
var temper_mult: int = 3
## The burst of Tame the Other for a turned Root, and for each point of Craving it carries.
var burst_mult: int = 2
var burst_craving_mult: int = 2
## A point of stored restraint, on his first hand from Indulge Vice up.
var restraint_pay: int = 2
## The Cane, on Spread Ruin.
var hcane_mult: int = 4

# Gauges and restraint.
## Craving that rolls over into a Habit and a copy.
var craving_cap: int = 3
var restraint_limit: int = 5
var balance_bonus: int = 1
## Night 3's scene: the limit is this much lower.
var tight_drop: int = 2
## Ink Roots a breakout adds.
var breakout_roots: int = 2
var alley_habit: int = 1

# Salt and pay.
var salt_start: int = 3
var salt_price: int = 3
## The rise in price for every dose bought so far in the run.
var salt_rise: int = 1
## The round, counted from 0 across the run, when salt first works.
var salt_from: int = 0
## The round, counted from 0 across the run, when the draught first exists.
var draught_from: int = 0
var alley_markup: int = 2
var round_pay: int = 3
var unused_play_pay: int = 1

# The reward after a round.
var reward_cards: int = 3
var reward_root_weight: int = 3
var reward_factor_weight: int = 2

## Applied to the targets of nights 2 and later, for tuning.
var target_scale: float = 1.0
## Applied to the targets of night 1.
var first_night_scale: float = 1.5


# The names of the numbers, in order, and the game's own values by name: found once.
static var _names: PackedStringArray = []
static var _known := {}

# Numbers that must be at least 1 for a round to be playable. The others must be 0 or more.
const _AT_LEAST_ONE: Array[String] = ["plays", "hand_size", "max_play", "max_discard", "craving_cap", "restraint_limit"]


## The game's numbers with the given changes. A change that cannot be used (see problems)
## is reported as an error and left out, so the game's own value stands.
static func make(changes: Dictionary = {}) -> RulesDials:
	var d := RulesDials.new()
	var wrong := problems(changes)
	for k: Variant in changes:
		if wrong.has(k):
			push_error(wrong[k])
		else:
			d.set(k, changes[k])
	return d


## What is wrong with these changes, as a message for each name that cannot be used: an
## unknown name, a value that is not a number, a fraction for a whole number, a negative
## value, or one too small to play with.
static func problems(changes: Dictionary) -> Dictionary:
	if _known.is_empty():
		_known = RulesDials.new().to_dict()
	var known := _known
	var out := {}
	for k: Variant in changes:
		var value: Variant = changes[k]
		if not k is String or not known.has(k):
			out[k] = "Unknown rules number: %s" % k
		elif not (value is int or value is float) or is_nan(value) or is_inf(value) or (known[k] is int and value != floor(value)):
			out[k] = "The rules number %s cannot be %s" % [k, value]
		elif value < (1 if _AT_LEAST_ONE.has(k) else 0) or ((k == "target_scale" or k == "first_night_scale") and value <= 0):
			out[k] = "The rules number %s is too small: %s" % [k, value]
	return out


## Every number by name.
func to_dict() -> Dictionary:
	if _names.is_empty():
		for p: Dictionary in get_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_names.append(p.name)
	var out := {}
	for name: String in _names:
		out[name] = get(name)
	return out
