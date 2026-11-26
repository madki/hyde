class_name RulesConfig
## Every name of the card game's rules, and the numbers that belong to a card, a hand, a night
## or an instrument. Nothing here changes during a run. The numbers a tuning pass may want
## to change are in RulesDials.

## The rules' version, kept by hand: change it whenever a rule or a number changes.
const RULES_VERSION := "2026.11.26"

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
## A text here, or of an instrument or a night, may name a number of RulesDials in braces:
## show it through text(), which puts the run's number in.
const FACTOR := {
	"cup": {
		"label": "Cup", "paper": "Good Cheer", "ink": "Glee", "unlock": 0,
		"paper_text": "Adds {cheer_mult} mult.", "ink_text": "Adds {glee_chips} chips.",
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
		"paper_text": "Adds {pen_mult} mult for each different Paper Root in the play.",
		"ink_text": "Adds {pen_mult} mult for each Ink Root in the largest matching set in the play.",
	},
	"cane": {
		"label": "Cane", "paper": "Vigour", "ink": "Restlessness", "unlock": 2,
		"paper_text": "Scores the play's best Root a second time and adds {cane_mult} mult.",
		"ink_text": "Scores the play's best Root a second time, adds {cane_mult} mult, and adds 1 more Craving to that Root.",
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
	"balance": {"name": "Balance", "text": "Restraint holds {balance_bonus} more.", "price": 6, "whose": "lab"},
	"saucers": {"name": "Glass saucers", "text": "A Sublimation may turn two of his Roots.", "price": 7, "whose": "lab"},
	"hcane": {"name": "The Cane", "text": "His Mania gains {hcane_mult} mult.", "price": 0, "whose": "his"},
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
	var scale := dials.target_scale
	if night == 0 or scale == 1.0:
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
