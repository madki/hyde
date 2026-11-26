extends "res://tests/case.gd"
## The table of story lines: every moment has its line, each line is well formed, none repeats,
## and every word is Stevenson's. A line is at most 200 letters; the opening's pages may run to
## 220, so that the wish to be housed apart is kept whole in one sentence. A dawn may have no
## line. The four endings' letters: each has a greeting, a body and a signature, in at most
## 45 words.

const KEYS := [
	"opening.1", "opening.2", "opening.3", "first_draught",
	"night.1", "night.2", "night.3", "night.4", "night.5",
	"arrival", "breakout", "window",
	"ending.jekyll", "ending.hyde", "ending.succumbed", "ending.unmet",
]
## Moments that may go without a line, when the book has none apt to them.
const DAWNS := [
	"dawn.1.lab", "dawn.2.lab", "dawn.3.lab", "dawn.4.lab",
	"dawn.1.alley", "dawn.2.alley", "dawn.3.alley", "dawn.4.alley",
]
const ENDINGS := ["jekyll", "hyde", "succumbed", "unmet"]
const LETTER_WORDS := 45


func test_every_moment_has_a_line() -> void:
	for key: String in KEYS:
		ok(not StoryLines.line(key).is_empty(), "a line for %s" % key)
	for key: String in StoryLines.keys():
		ok(key in KEYS or key in DAWNS, "%s is a moment named" % key)
	eq(StoryLines.line("nowhere"), {}, "an unknown key gives an empty line")


func test_lookups() -> void:
	for no in range(1, 6):
		eq(StoryLines.night(no), StoryLines.line("night.%d" % no), "night %d" % no)
	for no in range(1, 5):
		eq(StoryLines.dawn(no, "lab"), StoryLines.line("dawn.%d.lab" % no), "dawn %d in the laboratory" % no)
		eq(StoryLines.dawn(no, "alley"), StoryLines.line("dawn.%d.alley" % no), "dawn %d in the back alley" % no)
		var lab := StoryLines.dawn(no, "lab")
		var alley := StoryLines.dawn(no, "alley")
		ok(lab.is_empty() or lab.hand == "jekyll", "dawn %d in the laboratory is in Jekyll's hand" % no)
		ok(alley.is_empty() or alley.hand == "hyde", "dawn %d in the back alley is in Hyde's hand" % no)


func test_each_line_is_well_formed() -> void:
	var seen := {}
	for key: String in StoryLines.keys():
		var l := StoryLines.line(key)
		var text: String = l.get("text", "")
		ok(l.get("hand") in ["jekyll", "hyde"], "%s: hand is jekyll or hyde" % key)
		eq(l.get("by"), "stevenson", "%s: the words are Stevenson's" % key)
		ok(not text.strip_edges().is_empty(), "%s: text is not empty" % key)
		var most := 220 if key.begins_with("opening.") else 200
		ok(text.length() <= most, "%s: at most %d letters (%d)" % [key, most, text.length()])
		ok(not String(l.get("from", "")).is_empty(), "%s: names its chapter" % key)
		ok(not seen.has(text), "%s: text not used before (by %s)" % [key, seen.get(text, "")])
		seen[text] = key
	eq(StoryLines.line("first_draught").hand, "hyde", "the first draught is in Hyde's hand")


func test_each_letter_is_whole() -> void:
	eq(StoryLines.letter("nowhere"), [], "an unknown ending gives no letter")
	eq(StoryLines.LETTERS.keys().size(), ENDINGS.size(), "a letter for each ending and no more")
	for id: String in ENDINGS:
		var parts := StoryLines.letter(id)
		var roles := []
		var words := 0
		for part: Dictionary in parts:
			ok(part.get("hand") in ["jekyll", "hyde"], "%s: hand is jekyll or hyde" % id)
			eq(part.get("by"), "stevenson", "%s: the words are Stevenson's (%s)" % [id, part.get("text")])
			ok(part.get("role") in ["greeting", "body", "signature"], "%s: role is greeting, body or signature" % id)
			ok(not String(part.get("from", "")).is_empty(), "%s: a part names its chapter" % id)
			ok(not String(part.get("text", "")).strip_edges().is_empty(), "%s: a part is not empty" % id)
			if not roles.has(part.role):
				roles.append(part.role)
			words += String(part.text).split(" ", false).size()
		eq(roles, ["greeting", "body", "signature"], "%s: a greeting, a body and a signature, in that order" % id)
		ok(words <= LETTER_WORDS, "%s: at most %d words (%d)" % [id, LETTER_WORDS, words])


func test_succumbed_is_in_both_hands_and_strikes_one_name() -> void:
	var hands := {}
	var struck := 0
	for part: Dictionary in StoryLines.letter("succumbed"):
		hands[part.hand] = true
		if part.get("struck", false):
			struck += 1
			eq(part.role, "signature", "the struck part is a name")
	eq(hands.keys().size(), 2, "written in both hands")
	eq(struck, 1, "one name struck through")
	for id: String in ["jekyll", "hyde", "unmet"]:
		for part: Dictionary in StoryLines.letter(id):
			ok(not part.get("struck", false), "%s: no name struck" % id)
