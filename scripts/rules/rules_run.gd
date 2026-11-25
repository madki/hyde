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

## The events of the move being made, in order (see Rules). Not saved: a move fills it and
## returns it.
var events: Array = []


## Where each card was last found in `cards`, by id. Not saved, and only a hint: card_of
## checks it, so `cards` may be changed freely.
var _card_at: Dictionary = {}

# The names of the variables that are saved, in order, and the same as a set.
static var _saved: PackedStringArray = []
static var _is_saved := {}


## A separate copy of the run.
func copy() -> RulesRun:
	return RulesRun.from_dict(to_dict())


## A separate copy of the run that costs little, for a search that makes many: the same
## run as copy gives, to play on from, without the road through plain data and back. The
## numbers it plays by (`dials`) are the run's own, not a copy: nothing in the rules changes
## them, and whoever changes them on the copy changes them on the run.
func copy_fast() -> RulesRun:
	var r := RulesRun.new()
	r.v = v
	r.dials = dials
	r.seed = seed
	r.seed0 = seed0
	r.uid = uid
	r.night = night
	r.round = round
	r.phase = phase
	r.stance = stance
	r.restraint = restraint
	r.stored = stored
	r.salt = salt
	r.doses_bought = doses_bought
	r.sov = sov
	r.hyde_arrived = hyde_arrived
	r.unlocked = unlocked.duplicate()
	r.instruments = instruments.duplicate()
	r.craving = craving.duplicate()
	r.habit = habit.duplicate()
	r.temper = temper.duplicate()
	var deck: Array = []
	for c: RulesCard in cards:
		var twin := RulesCard.new()
		twin.id = c.id
		twin.sym = c.sym
		twin.kind = c.kind
		twin.ink = c.ink
		deck.append(twin)
	r.cards = deck
	r._card_at = _card_at.duplicate()
	r.draw = draw.duplicate()
	r.hand = hand.duplicate()
	r.discard = discard.duplicate()
	r.score = score
	r.plays = plays
	r.discards = discards
	r.last = _twin(last)
	r.offer = _twin(offer)
	r.alley = _twin(alley)
	r.shop = _twin(shop)
	r.dawn = _twin(dawn)
	r.ending = ending
	r.ended_by = ended_by
	r.log = log.duplicate(true)
	r.history = history.duplicate(true)
	r.stats = stats.duplicate()
	return r


static func _twin(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


## The card with this id, or null if the deck has none.
func card_of(id: int) -> RulesCard:
	var at: int = _card_at.get(id, -1)
	if at >= 0 and at < cards.size():
		var held: RulesCard = cards[at]
		if held.id == id:
			return held
	for i in cards.size():
		var c: RulesCard = cards[i]
		if c.id == id:
			_card_at[id] = i
			return c
	return null


# Fills the names of the saved variables: every variable of the script but the ones that are
# rebuilt as the run is played.
func _name_saved() -> void:
	for p: Dictionary in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.name != "events" and p.name != "_card_at":
			_saved.append(p.name)
			_is_saved[p.name] = true


## The run as plain data: numbers, strings, Arrays and Dictionaries only.
func to_dict() -> Dictionary:
	if _saved.is_empty():
		_name_saved()
	var out := {}
	for name: String in _saved:
		var value: Variant = get(name)
		if name == "dials":
			value = dials.to_dict()
		elif name == "cards":
			value = cards.map(func(c: RulesCard) -> Dictionary: return c.to_dict())
		elif value is Array or value is Dictionary:
			value = value.duplicate(true)
		out[name] = value
	return out


## Whether this is the data of a run that can be played on: the right version, a deck of
## known cards with ids of their own, piles that hold cards of the deck once at most, the
## gauges, a night, round, phase and stance that exist, and what the phase needs. Whole
## numbers must already be ints.
static func is_run_data(data: Variant) -> bool:
	if not data is Dictionary or data.get("v") != 1 or not data.get("dials") is Dictionary:
		return false
	# Numbers.
	for k: String in ["seed", "seed0"]:
		if not data.get(k, 0) is int:
			return false
	for k: String in ["uid", "night", "round", "restraint", "stored", "salt", "doses_bought", "sov", "score", "plays", "discards"]:
		var n: Variant = data.get(k, 0)
		if not n is int or n < 0:
			return false
	if data.get("night", 0) >= RulesConfig.NIGHTS.size() or data.get("round", 0) > 2:
		return false
	if not data.get("hyde_arrived", false) is bool:
		return false
	if not data.get("stance", "jekyll") in ["jekyll", "hyde"]:
		return false
	# Lists and records.
	for k: String in ["cards", "draw", "hand", "discard", "instruments"]:
		if not data.get(k) is Array:
			return false
	for k: String in ["log", "history"]:
		if not data.get(k, []) is Array:
			return false
	for k: String in ["unlocked", "stats"]:
		if not data.get(k, {}) is Dictionary:
			return false
	for k: String in ["last", "alley", "shop", "dawn"]:
		if data.get(k) != null and not data[k] is Dictionary:
			return false
	for key: Variant in data.instruments:
		if not RulesConfig.INSTRUMENTS.has(key):
			return false
	for k: String in ["craving", "habit", "temper"]:
		var gauge: Variant = data.get(k)
		if not gauge is Dictionary:
			return false
		for sym in RulesConfig.ROOTS:
			if not gauge.get(sym) is int or gauge[sym] < 0:
				return false
	# The deck and the piles.
	var ids := {}
	for c: Variant in data.cards:
		if not c is Dictionary or not c.get("id") is int or ids.has(c.id) or c.id > data.get("uid", 0):
			return false
		ids[c.id] = true
		if c.get("t") == "factor":
			if not RulesConfig.FACTOR.has(c.get("kind")):
				return false
		elif c.get("t") != "root" or not RulesConfig.ROOT.has(c.get("sym")) or not c.get("ink") is bool:
			return false
	var piled := {}
	for pile: String in ["draw", "hand", "discard"]:
		for id: Variant in data[pile]:
			if not id is int or not ids.has(id) or piled.has(id):
				return false
			piled[id] = true
	# What the phase needs.
	var offer: Variant = data.get("offer")
	if offer != null:
		if not offer is Array:
			return false
		for key: Variant in offer:
			if not RulesConfig.ROOT.has(key) and not RulesConfig.FACTOR.has(key):
				return false
	match data.get("phase", "play"):
		"play":
			return piled.size() == ids.size()
		"result":
			return data.get("last") is Dictionary
		"end":
			return data.get("last") is Dictionary and data.get("ending") is String
		"lab":
			var shop: Variant = data.get("shop")
			return shop is Dictionary and _is_shelf(shop.get("cards")) and _is_shelf(shop.get("instruments"))
		"alley":
			var alley: Variant = data.get("alley")
			return alley is Dictionary and alley.get("options") is Array and alley.get("bought") is int
	return false


static func _is_shelf(shelf: Variant) -> bool:
	if not shelf is Array:
		return false
	for o: Variant in shelf:
		if not o is Dictionary or not o.get("key") is String or not o.get("price") is int or not o.get("sold") is bool:
			return false
	return true


## A run from to_dict's data, which must pass is_run_data. Anything the data lacks keeps
## its starting value, and anything it holds that a run does not have is left out.
static func from_dict(data: Dictionary) -> RulesRun:
	var run := RulesRun.new()
	if _saved.is_empty():
		run._name_saved()
	for k: Variant in data:
		if not _is_saved.has(k):
			continue
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
			"stats", "unlocked":
				run.set(k, run.get(k).merged(value, true))
			_:
				run.set(k, value.duplicate(true) if value is Array or value is Dictionary else value)
	return run
