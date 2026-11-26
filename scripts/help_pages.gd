class_name HelpPages
## The help book's pages, as data: what HelpBook shows. Each page is
##
## - `title`: its heading.
## - `words`: its paragraphs, MOST_WORDS words at most in all. A name in braces is filled in
##   from the rules (see `values`), so no name of a card or a hand and no number of the rules
##   is written here.
## - `picture`: which picture HelpBook lays beside the words, made from the table's own parts.
##
## Pages are counted from 1, as the book shows them.

## The most words a page may hold.
const MOST_WORDS := 60
## The space that keeps a number on one line with what it counts. It parts two words as any
## space does.
const NO_BREAK := "\u00a0"

const PAGES: Array[Dictionary] = [
	{
		"title": "A round", "picture": "round",
		"words": [
			"Choose up to {max_play} cards that make a hand, and press PLAY.",
			"A play scores chips times mult: the hand gives some of each, and every card played adds its chips.",
			"Reach the round's target in {plays} plays. DISCARD swaps unwanted cards for new ones, {discards} times a round.",
			"A run is {nights} nights of {rounds} rounds each.",
		],
	},
	{
		"title": "Two men, one deck", "picture": "men",
		"words": [
			"Jekyll plays Paper Roots; Hyde only Ink Roots, and scores more.",
			"Drink the draught and Hyde has the table; each drink leaves more Ink Roots in your deck. A dose of salt brings Jekyll back.",
			"Every play of Jekyll's fills one step of restraint. Fill all {limit} and Hyde breaks out: he takes the table, with {breakout} more Ink Roots.",
		],
	},
	{
		"title": "Roots, Factors and hands", "picture": "hands",
		"words": [
			"Every Root shows a symbol: {symbols}. The Roots in a play make its hand, and each man has his own hands.",
			"Jekyll's best need different symbols; Hyde's need Roots alike.",
			"Factors belong to neither man. Both play them beside their Roots, and each adds something of its own, written on the card.",
		],
	},
	{
		"title": "The gauges", "picture": "gauges",
		"words": [
			"Craving rises as Hyde plays Ink Roots in a {rise} or better. Each Ink Root: +{craving_chips}\u00a0chips.",
			"At {cap} it becomes a Habit, Hyde's, and a new Ink Root joins the deck. Each Ink Root: +{habit_chips}\u00a0chips, +{habit_mult}\u00a0mult for each played.",
			"A {turn} turns Craving into Temper, Jekyll's. Each Paper Root: +{temper_chips}\u00a0chips, +{temper_mult}\u00a0mult once a play.",
		],
	},
	{
		"title": "The line and the night", "picture": "line",
		"words": [
			"The line weighs Paper Roots against Ink Roots in your deck. If Ink is ahead when a round ends, the run is lost.",
			"When the last play falls short, Hyde rescues the round and turns Paper Roots you hold to Ink.",
			"After a night's {rounds} rounds comes dawn: the laboratory if Jekyll has the table, the back alley if Hyde.",
		],
	},
]

## The Roots that show each pattern of RulesConfig.ROWS, by the pattern's key: a symbol, with
## `*` after it for its Ink twin. For the table of hands, and for a hand laid out in cards.
const PATTERNS := {
	"one": ["lamp"],
	"pair": ["lamp", "lamp"],
	"two": ["lamp", "heart"],
	"three": ["lamp", "lamp", "lamp"],
	"all": ["lamp", "heart", "mirror"],
	"sub": ["lamp", "lamp*"],
}


## How many pages the book has.
static func count() -> int:
	return PAGES.size()


## The number of the page that fits the moment on a table (RulesView.table()): the gauges'
## when a gauge is what the player last looked at, the two men's while a drink is on offer,
## and otherwise the first.
static func page_for(table: Dictionary, gauge_last: bool) -> int:
	if gauge_last:
		return _page_of("gauges")
	if bool(table.get("draught", {}).get("ok", false)):
		return _page_of("men")
	return 1


## The paragraphs of page `number` with the rules' names and numbers in them.
static func words(number: int, dials: RulesDials) -> Array[String]:
	var filled := values(dials)
	var out: Array[String] = []
	for paragraph: String in PAGES[number - 1].words:
		out.append(paragraph.format(filled))
	return out


## How many words page `number` holds.
static func word_count(number: int, dials: RulesDials) -> int:
	var n := 0
	for paragraph in words(number, dials):
		n += paragraph.replace(NO_BREAK, " ").split(" ", false).size()
	return n


## What the names in braces stand for: the rules' names (RulesConfig) and the run's numbers.
static func values(dials: RulesDials) -> Dictionary:
	var labels: Array = []
	for sym: String in RulesConfig.ROOTS:
		labels.append(RulesConfig.ROOT[sym].label)
	return {
		"max_play": dials.max_play,
		"plays": dials.plays,
		"discards": dials.discards,
		"nights": ArenaCaptions.NUMBERS[RulesConfig.NIGHTS.size()],
		"rounds": ArenaCaptions.NUMBERS[(RulesConfig.NIGHTS[0].targets as Array).size()],
		"limit": dials.restraint_limit,
		"breakout": dials.breakout_roots,
		"symbols": "%s, %s or %s" % labels,
		"rise": RulesConfig.HANDS.hyde.stirring.name,
		"turn": RulesConfig.HANDS.jekyll.sublimation.name,
		"cap": dials.craving_cap,
		"craving_chips": dials.craving_chips,
		"habit_chips": dials.habit_chips,
		"habit_mult": dials.habit_mult,
		"temper_chips": dials.temper_chips,
		"temper_mult": dials.temper_mult,
	}


## The key of the hand of `stance` ("jekyll" or "hyde") that gives the most, chips times mult.
static func best_hand(stance: String) -> String:
	var hands: Dictionary = RulesConfig.HANDS[stance]
	var best := ""
	for key: String in hands:
		if best == "" or int(hands[key].chips) * int(hands[key].mult) > int(hands[best].chips) * int(hands[best].mult):
			best = key
	return best


## The Roots that show a hand, as the data cards are made from (ArenaTravel.make_card):
## those of its pattern, each worth what a Root is at a run's start.
static func cards_of(stance: String, hand: String, dials: RulesDials) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mark: String in PATTERNS[RulesConfig.HANDS[stance][hand].row]:
		out.append(root(mark.trim_suffix("*"), mark.ends_with("*") or stance == "hyde", dials, out.size()))
	return out


## One Root as the data a card is made from: the Paper Root of `sym`, or its Ink twin.
static func root(sym: String, ink: bool, dials: RulesDials, id: int = 0) -> Dictionary:
	var names: Dictionary = RulesConfig.ROOT[sym]
	return {"id": id, "t": "root", "key": sym, "ink": ink, "name": names.ink if ink else names.paper,
			"chips": dials.root_chips, "text": ""}


static func _page_of(picture: String) -> int:
	for i in PAGES.size():
		if PAGES[i].picture == picture:
			return i + 1
	return 1
