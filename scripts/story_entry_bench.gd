extends Control
## A bench for a story entry, on the journal's page:
##
##   tools/shot.sh /abs/out.png res://scenes/story_entry_bench.tscn [--line=<text>]
##       [--hand=jekyll|hyde] [--plain] [--at=<seconds>]
##
## With `--at` the still is taken that many seconds into the line; without it, once the
## line is whole and dry. Run without `--shot`, it writes the line over and over: a press
## completes it, the next writes it again. `\n` in `--line` starts a new line.

const LINES := {
	"jekyll": "Between these two, I now felt I had to choose. My two natures had memory in common, but all other faculties were most unequally shared between them.\n\nI chose the better part, and was found wanting in the strength to keep to it.",
	"hyde": "I was the first that could plod in the public eye with a load of genial respectability, and in a moment, like a schoolboy, strip off these lendings and spring headlong into the sea of liberty.",
}

@onready var _entry: StoryEntry = $Entry


func _ready() -> void:
	StoryEntry.easy_read = Shot.has_arg("plain")
	var hand := Shot.arg("hand") if Shot.arg("hand") == "hyde" else "jekyll"
	var line: String = Shot.arg("line").replace("\\n", "\n") if Shot.arg("line") else LINES[hand]
	if Shot.has_arg("shot"):
		_entry.write(line, hand)
		if Shot.has_arg("at"):
			_entry.pass_time(float(Shot.arg("at")))
		else:
			while not _entry.is_waiting():
				_entry.pass_time(0.5)
			_entry.pass_time(StoryInk.APPEAR + StoryInk.DRY)
		# Hold the page as it is for the still.
		_entry.set_process(false)
		Sfx.stop_all()
		Shot.run_if_requested(self)
		return
	while true:
		await _entry.write(line, hand)
