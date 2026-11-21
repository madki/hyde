class_name RulesRun
## A run of the card game: everything that has to be kept to go on playing, and nothing
## else. Rules changes it, RulesView reads it. It saves as plain data (to_dict, from_dict).

var v: int = 1
var dials: RulesDials = RulesDials.new()
## The generator's state, a signed 32-bit number, and the seed the run began with.
@warning_ignore("shadowed_global_identifier")
var seed: int
var seed0: int
## The id of the newest card.
var uid: int

## 0 to 4.
var night: int
## 0 to 2. The scene is 2.
@warning_ignore("shadowed_global_identifier")
var round: int
## "play", "result", "lab", "alley" or "end".
var phase: String = "play"
## "jekyll" or "hyde".
var stance: String = "jekyll"

var restraint: int
var stored: int
var salt: int
var doses_bought: int
var sov: int
var hyde_arrived: bool
## Which of the Pen and the Cane have unlocked.
var unlocked: Dictionary = {"pen": false, "cane": false}
## Keys of the instruments held.
var instruments: Array = []

# The three gauges, a number for each symbol.
var craving: Dictionary[String, int] = {"lamp": 0, "heart": 0, "mirror": 0}
var habit: Dictionary[String, int] = {"lamp": 0, "heart": 0, "mirror": 0}
var temper: Dictionary[String, int] = {"lamp": 0, "heart": 0, "mirror": 0}

## The whole deck, as RulesCard.
var cards: Array = []
# The piles, as card ids. The top of the draw pile is its end.
var draw: Array = []
var hand: Array = []
var discard: Array = []

# The round.
var score: int
var plays: int
var discards: int

# Between rounds. Each is null when there is none.
## How the last round ended: {how: "won" | "rescued" | "lost", ...}.
var last: Variant = null
## The reward on offer: keys of three cards.
var offer: Variant = null
## The back alley's offers: {habit, inst, options, bought}.
var alley: Variant = null
## The laboratory's shelf: {cards, instruments}, each [{key, price, sold}].
var shop: Variant = null
## What this dawn brought: {no, brings, unlocks, last, as_hyde}.
var dawn: Variant = null
## "hyde", "double" or "myself", and what ended the run.
var ending: Variant = null
var ended_by: Variant = null

## What happened this round, and how each round so far ended.
@warning_ignore("shadowed_global_identifier")
var log: Array = []
var history: Array = []
var stats: Dictionary = {
	"rescues": 0, "converted": 0, "breakouts": 0, "turns": 0, "temper": 0,
	"hyde_hands": 0, "jekyll_hands": 0, "best": 0, "best_name": "",
	"drinks": 0, "stains": 0, "salts": 0, "bred": 0, "struck": 0, "passes": 0,
}


## A separate copy of the run.
func copy() -> RulesRun:
	return RulesRun.from_dict(to_dict())


## The run as plain data: numbers, strings, Arrays and Dictionaries only.
func to_dict() -> Dictionary:
	var out := {}
	for p: Dictionary in get_property_list():
		if not p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var value: Variant = get(p.name)
		if p.name == "dials":
			value = dials.to_dict()
		elif p.name == "cards":
			value = cards.map(func(c: RulesCard) -> Dictionary: return c.to_dict())
		elif value is Array or value is Dictionary:
			value = value.duplicate(true)
		out[p.name] = value
	return out


## Whether this is the data of a run, as far as its shape goes: the right version, a deck of
## cards, the piles, the gauges and the numbers. Whole numbers must already be ints.
static func is_run_data(data: Variant) -> bool:
	if not data is Dictionary or data.get("v") != 1 or not data.get("dials") is Dictionary:
		return false
	for k: String in ["cards", "draw", "hand", "discard", "instruments"]:
		if not data.get(k) is Array:
			return false
	for k: String in ["craving", "habit", "temper"]:
		var gauge: Variant = data.get(k)
		if not gauge is Dictionary:
			return false
		for sym in RulesConfig.ROOTS:
			if not gauge.get(sym) is int:
				return false
	for c: Variant in data.cards:
		if not c is Dictionary or not c.get("id") is int:
			return false
		if c.get("t") == "factor":
			if not RulesConfig.FACTOR.has(c.get("kind")):
				return false
		elif c.get("t") != "root" or not RulesConfig.ROOT.has(c.get("sym")) or not c.get("ink") is bool:
			return false
	for pile: String in ["draw", "hand", "discard"]:
		for id: Variant in data[pile]:
			if not id is int:
				return false
	return true


## A run from to_dict's data, which must pass is_run_data. A number the data lacks keeps the
## game's own value.
static func from_dict(data: Dictionary) -> RulesRun:
	var run := RulesRun.new()
	for k: String in data:
		var value: Variant = data[k]
		match k:
			"dials":
				run.dials = RulesDials.make(value)
			"cards":
				run.cards = value.map(func(d: Dictionary) -> RulesCard: return RulesCard.from_dict(d))
			"craving", "habit", "temper":
				var gauge: Dictionary[String, int] = {}
				for sym: String in value:
					gauge[sym] = value[sym]
				run.set(k, gauge)
			_:
				run.set(k, value.duplicate(true) if value is Array or value is Dictionary else value)
	return run
