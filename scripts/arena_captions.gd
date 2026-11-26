class_name ArenaCaptions
## The caption lines of the card moments, in one place: a card joining the deck, a man
## bringing Roots to the hand, and a Root changing side. Each takes the names the engine gives
## (in the stance the table is in) and writes the line; it works out no rule.

const NUMBERS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight"]
## What an Ink Root in the deck means, in the rules' words.
const INK_MEANS := "Only Hyde plays Ink Roots; Jekyll only in a Sublimation. If Ink Roots outnumber Paper Roots when a round ends, the run is lost."


## Why cards join the deck, for `joins`:
## - "arrival": his first arrival (a group of four).
## - "breakout": a breakout's two.
## - "rollover": a copy of a Root whose Craving rolled over into a Habit.
## - "no_paper": a drink with no Paper Root left to stain.
## - "dawn": his two Roots at dawn.
## - "reward", "bought": a card taken after a won round, or bought.
static func joins(cause: String, names: Array) -> String:
	match cause:
		"arrival":
			return "He arrives. Four of his Roots join the deck."
		"breakout":
			return "He breaks out. %s join the deck." % _capital(list(names))
		"rollover":
			return "%s joins the deck." % _first(names)
		"no_paper":
			return "Nothing is left to stain. %s joins the deck." % _capital(_a(_first(names)))
		"dawn":
			return "Dawn. %s join the deck." % _capital(list(names))
	# A reward or a card bought.
	if names.size() == 1:
		return "%s joins the deck." % _first(names)
	return "%s join the deck." % _capital(list(names))


## The notice shown when Roots of his join the deck by a rule: {title, lines}, the lines being
## why they join, what it means, and the line as it will stand (`paper` and `ink` Roots once
## they have joined). `cause` is one of those of `joins` but "reward" and "bought", which show
## no notice; `symbol` is the label of the symbol whose Craving rolled over, for "rollover".
static func joins_notice(cause: String, paper: int, ink: int,
		symbol: String = "") -> Dictionary:
	var said: Array
	match cause:
		"arrival":
			said = arrival()
		"breakout":
			said = breakout()
		"rollover":
			said = rollover(symbol)
		"no_paper":
			said = no_paper()
		_:
			said = dawn()
	return {"title": said[0], "lines": [said[1], INK_MEANS, line_stands(paper, ink)]}


## Each cause's title and why, for `joins_notice`.
static func arrival() -> Array:
	return ["Hyde arrives", "The first draught brings him, and four of his Roots come with him."]


static func breakout() -> Array:
	return ["He breaks out", "Restraint gave way, and two of his Roots come with him."]


static func rollover(symbol: String) -> Array:
	return ["A Habit forms", "Craving for the %s reached 3, and the Habit breeds a copy." % symbol]


static func no_paper() -> Array:
	return ["Nothing left to stain", "The draught found no Paper Root to stain, so an Ink Root joins."]


static func dawn() -> Array:
	return ["Dawn", "The night is over, and it leaves two of his Roots in the deck."]


## The line as it will stand.
static func line_stands(paper: int, ink: int) -> String:
	return "The line: Paper %d, Ink %d." % [paper, ink]


## Why a gauge grew, said while its new value stands beside it: `cause` is "rollover" (a
## Craving of three became a Habit) or "turn" (a Sublimation), `symbol` the symbol's name.
static func grows(cause: String, symbol: String) -> String:
	if cause == "turn":
		return "Sublimation: its Craving is turned to Temper."
	return "Craving reached 3: %s is a Habit now." % symbol


## A man brings Roots to the hand: `man` is "Jekyll" or "Hyde", `names` what he brings.
static func brings(man: String, names: Array) -> String:
	if names.is_empty():
		return "He finds none of his Roots to bring."
	return "%s brings %s." % [man, list(names)]


## A Root changes side: `change` is "stain" (a drink), "convert" (the rescue) or "turn" (a
## Sublimation). `from` is the card's name before, `to` its twin's.
static func changes(change: String, from: String, to: String) -> String:
	match change:
		"stain":
			return "The draught stains %s. It is %s now." % [_a(from), _a(to)]
		"convert":
			return "He takes the %s." % from
	return "%s is turned to %s." % [from, to]


## Names as a phrase: "a Fog", "two Fog", "a Composure and a Scruple", "two Fog and a Pride".
static func list(names: Array) -> String:
	var counts := {}
	for name: String in names:
		counts[name] = counts.get(name, 0) + 1
	var parts: Array[String] = []
	for name: String in counts:
		var n: int = counts[name]
		parts.append(_a(name) if n == 1 else "%s %s" % [NUMBERS[mini(n, NUMBERS.size() - 1)], name])
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]


static func _a(name: String) -> String:
	return ("an " if name.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + name


static func _first(names: Array) -> String:
	return names[0] if not names.is_empty() else ""


static func _capital(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)
