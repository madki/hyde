class_name RulesConfig
## Every name of the card game's rules, and the numbers that belong to a card, a hand, a night
## or an instrument. Nothing here changes during a run. The numbers a tuning pass may want
## to change are in RulesDials.

## The rules' version, kept by hand: change it whenever a rule or a number changes.
const RULES_VERSION := "2026.11.26.2"

## The three symbols, in the order every tie between symbols is settled by.
const ROOTS: Array[String] = ["lamp", "heart", "mirror"]
## A Root card has a symbol and a side: paper is Jekyll's, ink is Hyde's. `label` is the
## symbol; `domain` is the part of the man it stands for (shown nowhere yet).
const ROOT := {
	"lamp": {"label": "Cloak", "domain": "Soul", "paper": "Piety", "ink": "Corruption"},
	"heart": {"label": "Quill", "domain": "Mind", "paper": "Reason", "ink": "Madness"},
	"mirror": {"label": "Cane", "domain": "Body", "paper": "Composure", "ink": "Brutality"},
}

const FACTORS: Array[String] = ["cup", "eye", "lock", "pen", "cane"]
## A Common Factor has no side: it takes the name of the man at the table (paper: Jekyll,
## ink: Hyde). `unlock` is the dawn it joins the pool at, 0 for one that is there from the start.
## A text here, or of an instrument or a night, may name a number of RulesDials in braces:
## show it through text(), which puts the run's number in.
const FACTOR := {
	"cup": {
		"label": "Chalice", "paper": "Temperance", "ink": "Indulgence", "unlock": 0,
		"paper_text": "Adds {cheer_mult} mult.", "ink_text": "Adds {glee_chips} chips.",
	},
	"eye": {
		"label": "Hourglass", "paper": "Patience", "ink": "Impulse", "unlock": 0,
		"paper_text": "Draws one more card after the hand refills.",
		"ink_text": "Draws one more card after the hand refills.",
	},
	"lock": {
		"label": "Mask", "paper": "Truth", "ink": "Deceit", "unlock": 0,
		"paper_text": "The play adds no restraint.", "ink_text": "The play adds no Craving.",
	},
	"pen": {
		"label": "Scale", "paper": "Balance", "ink": "Obsession", "unlock": 1,
		"paper_text": "Adds {pen_mult} mult for each different Paper Root in the play.",
		"ink_text": "Adds {pen_mult} mult for each Ink Root in the largest matching set in the play.",
	},
	"cane": {
		"label": "Key", "paper": "Resolve", "ink": "Surrender", "unlock": 2,
		"paper_text": "Scores the play's best Root a second time and adds {cane_mult} mult.",
		"ink_text": "Scores the play's best Root a second time, adds {cane_mult} mult, and adds 1 more Craving to that Root.",
	},
}

## The hands of each stance. When a play fits several, the highest chips x mult counts.
const HANDS := {
	"jekyll": {
		"spark": {"name": "Kindle Virtue", "chips": 15, "mult": 2, "row": "one"},
		"rumination": {"name": "Strengthen Conviction", "chips": 25, "mult": 2, "row": "pair"},
		"goodwork": {"name": "Weave Harmony", "chips": 30, "mult": 3, "row": "two"},
		"dogma": {"name": "Impose Order", "chips": 40, "mult": 3, "row": "three"},
		"lucid": {"name": "Master the Self", "chips": 55, "mult": 5, "row": "all"},
		"sublimation": {"name": "Tame the Other", "chips": 25, "mult": 2, "row": "sub"},
	},
	"hyde": {
		"stirring": {"name": "Indulge Vice", "chips": 20, "mult": 3, "row": "one"},
		"fixation": {"name": "Stoke Compulsion", "chips": 35, "mult": 5, "row": "pair"},
		"lapse": {"name": "Sow Discord", "chips": 25, "mult": 3, "row": "two"},
		"mania": {"name": "Spread Ruin", "chips": 60, "mult": 7, "row": "three"},
		"turmoil": {"name": "Unchain the Beast", "chips": 40, "mult": 4, "row": "all"},
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
const THOUGHT_NAME := "Guard the Veil"

const INSTRUMENTS := {
	"spirit": {"name": "Spirit lamp", "text": "One more discard a round.", "price": 5, "whose": "lab"},
	"notebook": {"name": "Notebook", "text": "Shows the next three cards of the draw pile.", "price": 5, "whose": "lab"},
	"balance": {"name": "Balance", "text": "Restraint holds {balance_bonus} more.", "price": 6, "whose": "lab"},
	"saucers": {"name": "Glass saucers", "text": "Tame the Other may turn two of his Roots.", "price": 7, "whose": "lab"},
	"hcane": {"name": "The Cane", "text": "His Spread Ruin gains {hcane_mult} mult.", "price": 0, "whose": "his"},
	"cheque": {"name": "Cheque book", "text": "Each Indulge Vice or better of his pays 1 sovereign.", "price": 0, "whose": "his"},
}
const LAB_INSTRUMENTS: Array[String] = ["spirit", "notebook", "balance", "saucers"]
const HIS_INSTRUMENTS: Array[String] = ["hcane", "cheque"]
const MAX_INSTRUMENTS := 3

## The starting deck, 12 cards, all on paper: 8 Paper Roots and 4 Common Factors.
const STARTING_DECK: Array[String] = [
	"lamp", "lamp", "lamp", "heart", "heart", "heart", "mirror", "mirror", "cup", "cup", "eye", "lock",
]
## The Ink Roots that join the first time Hyde has the table: 2 Corruption, 1 Madness, 1 Brutality.
const FIRST_ARRIVAL: Array[String] = ["lamp", "lamp", "heart", "mirror"]

const CARD_PRICE := 3
const STRIKE_PAPER := 4
const STRIKE_INK := 8

## The five nights: two ordinary rounds, then a scene that bends one rule (`twist`).
## `targets` are a night's plain targets: what a round asks is these by the numbers' scale
## (see `targets()`), the first night by `first_night_scale`.
## `brings` is the Ink Root two copies of which join at that night's dawn ("habit": his
## highest-Habit Root, "": none). `unlocks` is the Factor that joins the pool at that dawn.
const NIGHTS := [
	{
		"title": "Story of the Door", "targets": [1000, 1500, 2200], "twist": "", "brings": "heart", "unlocks": "pen",
		"twist_text": "None.",
	},
	{
		"title": "Search for Mr Hyde", "targets": [3000, 4200, 5500], "twist": "hunted", "brings": "mirror", "unlocks": "cane",
		"twist_text": "Hyde is hunted: the base mult of his hands is halved, rounded up.",
	},
	{
		"title": "The Carew Murder Case", "targets": [6500, 9000, 13000], "twist": "tight", "brings": "habit", "unlocks": "",
		"twist_text": "Restraint holds {tight_drop} fewer.",
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

## The score targets of a night's three rounds, for these numbers.
static func targets(dials: RulesDials, night: int) -> Array:
	var base: Array = NIGHTS[night].targets
	var scale := dials.first_night_scale if night == 0 else dials.target_scale
	if scale == 1.0:
		return base.duplicate()
	var out: Array = []
	for t: int in base:
		out.append(maxi(50, int(floor(t * scale / 50.0 + 0.5)) * 50))
	return out


## A text of this config with a run's numbers put in place of the names in braces.
static func text(template: String, dials: RulesDials) -> String:
	return template.format(dials.to_dict())


## What a Factor does, in the words of the man at the table.
static func factor_text(kind: String, stance: String, dials: RulesDials) -> String:
	return text(FACTOR[kind].ink_text if stance == "hyde" else FACTOR[kind].paper_text, dials)


## What an instrument does.
static func instrument_text(key: String, dials: RulesDials) -> String:
	return text(INSTRUMENTS[key].text, dials)


## What a night's scene bends.
static func twist_text(night: int, dials: RulesDials) -> String:
	return text(NIGHTS[night].twist_text, dials)
