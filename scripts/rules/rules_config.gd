class_name RulesConfig
## Every name and number of the card game's rules, in one place. Nothing here changes during
## a run: a run copies NUMBERS into its own `dials`, so a test or a tuning pass can change one.

## The three symbols, in the order every tie between symbols is settled by.
const ROOTS: Array[String] = ["lamp", "heart", "mirror"]
## A Root card has a symbol and a side: paper is Jekyll's, ink is Hyde's.
const ROOT := {
	"lamp": {"label": "Lamp", "paper": "Composure", "ink": "Fog"},
	"heart": {"label": "Heart", "paper": "Kindness", "ink": "Appetite"},
	"mirror": {"label": "Mirror", "paper": "Scruple", "ink": "Pride"},
}

const FACTORS: Array[String] = ["cup", "eye", "lock", "pen", "cane"]
## A Common Factor has no side: it takes the name of the man at the table (paper: Jekyll,
## ink: Hyde). `unlock` is the dawn it joins the pool at, 0 for one that is there from the start.
const FACTOR := {
	"cup": {
		"label": "Cup", "paper": "Good Cheer", "ink": "Glee", "unlock": 0,
		"paper_text": "Adds 2 mult.", "ink_text": "Adds 25 chips.",
	},
	"eye": {
		"label": "Eye", "paper": "Curiosity", "ink": "Impulse", "unlock": 0,
		"paper_text": "Draws one more card after the hand refills.",
		"ink_text": "Draws one more card after the hand refills.",
	},
	"lock": {
		"label": "Lock", "paper": "Resolve", "ink": "Cunning", "unlock": 0,
		"paper_text": "The play adds no restraint.", "ink_text": "The play adds no Craving.",
	},
	"pen": {
		"label": "Pen", "paper": "Reason", "ink": "Alibi", "unlock": 1,
		"paper_text": "Adds 2 mult for each different Paper Root in the play.",
		"ink_text": "Adds 2 mult for each Ink Root in the largest matching set in the play.",
	},
	"cane": {
		"label": "Cane", "paper": "Vigour", "ink": "Restlessness", "unlock": 2,
		"paper_text": "Scores the play's best Root a second time and adds 2 mult.",
		"ink_text": "Scores the play's best Root a second time, adds 2 mult, and adds 1 more Craving to that Root.",
	},
}

## The hands of each stance. When a play fits several, the highest chips x mult counts.
const HANDS := {
	"jekyll": {
		"spark": {"name": "Spark", "chips": 15, "mult": 2, "row": "one"},
		"rumination": {"name": "Rumination", "chips": 25, "mult": 2, "row": "pair"},
		"goodwork": {"name": "Good Work", "chips": 30, "mult": 3, "row": "two"},
		"dogma": {"name": "Dogma", "chips": 40, "mult": 3, "row": "three"},
		"lucid": {"name": "Lucid Mind", "chips": 55, "mult": 5, "row": "all"},
		"sublimation": {"name": "Sublimation", "chips": 25, "mult": 2, "row": "sub"},
	},
	"hyde": {
		"stirring": {"name": "Stirring", "chips": 20, "mult": 3, "row": "one"},
		"fixation": {"name": "Fixation", "chips": 35, "mult": 5, "row": "pair"},
		"lapse": {"name": "Lapse", "chips": 25, "mult": 3, "row": "two"},
		"mania": {"name": "Mania", "chips": 60, "mult": 7, "row": "three"},
		"turmoil": {"name": "Turmoil", "chips": 40, "mult": 4, "row": "all"},
	},
}
## The patterns of active Roots, and the hand each stance makes of them.
const ROWS := [
	{"key": "one", "label": "One Root", "jekyll": "spark", "hyde": "stirring"},
	{"key": "pair", "label": "Two alike", "jekyll": "rumination", "hyde": "fixation"},
	{"key": "two", "label": "Two different", "jekyll": "goodwork", "hyde": "lapse"},
	{"key": "three", "label": "Three or more alike", "jekyll": "dogma", "hyde": "mania"},
	{"key": "all", "label": "All three symbols", "jekyll": "lucid", "hyde": "turmoil"},
	{"key": "sub", "label": "A Root and its ink twin", "jekyll": "sublimation", "hyde": ""},
]
const THOUGHT_NAME := "Passing Thought"

const INSTRUMENTS := {
	"spirit": {"name": "Spirit lamp", "text": "One more discard a round.", "price": 5, "whose": "lab"},
	"notebook": {"name": "Notebook", "text": "Shows the next three cards of the draw pile.", "price": 5, "whose": "lab"},
	"balance": {"name": "Balance", "text": "Restraint holds one more.", "price": 6, "whose": "lab"},
	"saucers": {"name": "Glass saucers", "text": "A Sublimation may turn two of his Roots.", "price": 7, "whose": "lab"},
	"hcane": {"name": "The Cane", "text": "His Mania gains 4 mult.", "price": 0, "whose": "his"},
	"cheque": {"name": "Cheque book", "text": "Each Stirring or better of his pays 1 sovereign.", "price": 0, "whose": "his"},
}
const LAB_INSTRUMENTS: Array[String] = ["spirit", "notebook", "balance", "saucers"]
const HIS_INSTRUMENTS: Array[String] = ["hcane", "cheque"]
const MAX_INSTRUMENTS := 3

## The starting deck, 12 cards, all on paper: 8 Paper Roots and 4 Common Factors.
const STARTING_DECK: Array[String] = [
	"lamp", "lamp", "lamp", "heart", "heart", "heart", "mirror", "mirror", "cup", "cup", "eye", "lock",
]
## The Ink Roots that join the first time Hyde has the table: 2 Fog, 1 Appetite, 1 Pride.
const FIRST_ARRIVAL: Array[String] = ["lamp", "lamp", "heart", "mirror"]

const CARD_PRICE := 3
const STRIKE_PAPER := 4
const STRIKE_INK := 8

## The five nights: two ordinary rounds, then a scene that bends one rule (`twist`).
## `brings` is the Ink Root two copies of which join at that night's dawn ("habit": his
## highest-Habit Root, "": none). `unlocks` is the Factor that joins the pool at that dawn.
const NIGHTS := [
	{
		"title": "Story of the Door", "targets": [1000, 1500, 2200], "twist": "", "brings": "heart", "unlocks": "pen",
		"twist_text": "None. Round 1 is played before the draught exists, and salt first works in the scene.",
	},
	{
		"title": "Search for Mr Hyde", "targets": [3000, 4200, 5500], "twist": "hunted", "brings": "mirror", "unlocks": "cane",
		"twist_text": "Hyde is hunted: the base mult of his hands is halved, rounded up.",
	},
	{
		"title": "The Carew Murder Case", "targets": [6500, 9000, 13000], "twist": "tight", "brings": "habit", "unlocks": "",
		"twist_text": "Restraint holds 2 fewer.",
	},
	{
		"title": "Incident at the Window", "targets": [14000, 19000, 26000], "twist": "window", "brings": "", "unlocks": "",
		"twist_text": "The scene begins as Hyde, whoever ended round 2. That shift is free and stains nothing.",
	},
	{
		"title": "The Last Night", "targets": [24000, 30000, 40000], "twist": "last", "brings": "", "unlocks": "",
		"twist_text": "No draught and no salt work in the scene.",
	},
]

## The numbers a run plays by. Rules.new_run copies them into `run.dials`, with any changes.
const NUMBERS := {
	# a round
	"plays": 4,
	"discards": 3,
	"hand_size": 8,
	"max_play": 5,
	# chips
	"root_chips": 15,
	"factor_chips": 10,
	"glee_chips": 25,
	"craving_chips": 10,  # a point of Craving, on every Ink Root of the symbol
	"habit_chips": 15,
	"temper_chips": 15,
	# mult
	"cheer_mult": 2,  # Good Cheer
	"pen_mult": 2,  # Reason: a different symbol. Alibi: a Root of the largest matching set
	"cane_mult": 2,  # Vigour and Restlessness
	"habit_mult": 1,  # a point of Habit, for every Ink Root of the symbol in the play
	"temper_mult": 2,  # a point of Temper, once for a symbol in the play
	"burst_mult": 2,  # a Sublimation's burst for a turned Root...
	"burst_craving_mult": 2,  # ...and for each point of Craving it carries
	"restraint_pay": 2,  # a point of stored restraint, on his first Stirring or better
	"hcane_mult": 4,  # The Cane, on a Mania
	# gauges and restraint
	"craving_cap": 3,  # Craving that rolls over into a Habit and a copy
	"restraint_limit": 5,
	"balance_bonus": 1,
	"tight_drop": 2,  # night 3's scene: the limit is this much lower
	"breakout_roots": 2,  # Ink Roots a breakout adds
	"alley_habit": 1,
	# salt and pay
	"salt_start": 3,
	"salt_price": 3,
	"salt_rise": 1,  # for every dose bought so far in the run
	"salt_from": 2,  # the round, counted from 0 across the run, when salt first works
	"alley_markup": 2,
	"round_pay": 3,
	"unused_play_pay": 1,
	# the reward after a round
	"reward_cards": 3,
	"reward_root_weight": 3,
	"reward_factor_weight": 2,
	# applied to the targets of nights 2 and later, for tuning
	"target_scale": 1,
}


## A run's numbers: NUMBERS with the given changes. An unknown key is an error.
static func dials(changes: Dictionary = {}) -> Dictionary:
	var d: Dictionary = NUMBERS.duplicate()
	for k: String in changes:
		assert(d.has(k), "unknown rules number: " + k)
		d[k] = changes[k]
	return d


## The score targets of a night's three rounds, for these numbers.
static func targets(dial_values: Dictionary, night: int) -> Array:
	var base: Array = NIGHTS[night].targets
	var scale: float = float(dial_values.target_scale)
	if night == 0 or scale == 1.0:
		return base
	var out: Array = []
	for t: int in base:
		out.append(maxi(50, int(floor(t * scale / 50.0 + 0.5)) * 50))
	return out
