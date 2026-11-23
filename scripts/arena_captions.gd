class_name ArenaCaptions
## The caption lines of the card moments, in one place: a card joining the deck, a man
## bringing Roots to the hand, and a Root changing side. Each takes the names the engine gives
## (in the stance the table is in) and writes the line; it works out no rule.

const NUMBERS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight"]


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
			return "%s has become a Habit. A copy joins the deck." % _first(names)
		"no_paper":
			return "Nothing is left to stain. %s joins the deck." % _capital(_a(_first(names)))
		"dawn":
			return "Dawn. %s join the deck." % _capital(list(names))
	# A reward or a card bought.
	if names.size() == 1:
		return "%s joins the deck." % _first(names)
	return "%s join the deck." % _capital(list(names))


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
