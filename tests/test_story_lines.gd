extends "res://tests/case.gd"
## The table of story lines: every moment has its line, each line is well formed, none repeats.
## A line is at most 200 letters; the opening's pages may run to 220, so that the wish to be
## housed apart is kept whole in one sentence.

const KEYS := [
	"opening.1", "opening.2", "opening.3", "first_draught",
	"night.1", "night.2", "night.3", "night.4", "night.5",
	"dawn.1.lab", "dawn.2.lab", "dawn.3.lab", "dawn.4.lab",
	"dawn.1.alley", "dawn.2.alley", "dawn.3.alley", "dawn.4.alley",
	"arrival", "breakout", "window",
	"ending.jekyll", "ending.hyde", "ending.succumbed", "ending.unmet",
]


func test_every_moment_has_a_line() -> void:
	for key: String in KEYS:
		ok(not StoryLines.line(key).is_empty(), "a line for %s" % key)
	eq(StoryLines.keys().size(), KEYS.size(), "no line beyond the moments named")
	eq(StoryLines.line("nowhere"), {}, "an unknown key gives an empty line")


func test_lookups() -> void:
	for no in range(1, 6):
		eq(StoryLines.night(no), StoryLines.line("night.%d" % no), "night %d" % no)
	for no in range(1, 5):
		eq(StoryLines.dawn(no, "lab"), StoryLines.line("dawn.%d.lab" % no), "dawn %d in the laboratory" % no)
		eq(StoryLines.dawn(no, "alley"), StoryLines.line("dawn.%d.alley" % no), "dawn %d in the back alley" % no)
		eq([StoryLines.dawn(no, "lab").hand, StoryLines.dawn(no, "alley").hand], ["jekyll", "hyde"], "dawn %d: each place in its own hand" % no)


func test_each_line_is_well_formed() -> void:
	var seen := {}
	for key: String in StoryLines.keys():
		var l := StoryLines.line(key)
		var text: String = l.get("text", "")
		ok(l.get("hand") in ["jekyll", "hyde"], "%s: hand is jekyll or hyde" % key)
		ok(l.get("by") in ["stevenson", "ours"], "%s: by is stevenson or ours" % key)
		ok(not text.strip_edges().is_empty(), "%s: text is not empty" % key)
		var most := 220 if key.begins_with("opening.") else 200
		ok(text.length() <= most, "%s: at most %d letters (%d)" % [key, most, text.length()])
		ok(l.get("by") == "ours" or not String(l.get("from", "")).is_empty(), "%s: Stevenson's line names its chapter" % key)
		ok(not seen.has(text), "%s: text not used before (by %s)" % [key, seen.get(text, "")])
		seen[text] = key
	for key: String in ["opening.1", "opening.2", "opening.3", "first_draught", "night.1", "night.2", "night.3", "night.4", "night.5", "arrival", "breakout", "window", "ending.jekyll", "ending.hyde", "ending.succumbed", "ending.unmet"]:
		eq(StoryLines.line(key).by, "stevenson", "%s is Stevenson's" % key)
	for no in range(1, 5):
		eq([StoryLines.dawn(no, "lab").by, StoryLines.dawn(no, "alley").by], ["ours", "ours"], "dawn %d is ours" % no)
	eq(StoryLines.line("first_draught").hand, "hyde", "the first draught is in Hyde's hand")
