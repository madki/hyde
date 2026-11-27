class_name ArenaCardNote
extends PanelContainer
## The note a card has when the pointer rests on it, in the look of the page's other notes
## (ArenaViews): cream, pencilled, 14 px. `words` says what the card is: for a Root, how its
## chips are made up and what it is worth now; for a Factor, the other man's reading of it.
## The hand adds to it, printed dark, why a card cannot be played.
##
## As a node it is the note itself, for a page that has none of its own: `say` puts the
## words in, broken into lines no wider than `width`.

## The words are broken into lines no wider than this, in pixels.
var width := 330.0

var _words := Label.new()
var _font := FontVariation.new()


## The note's words for a card. `entry` is the card's face (RulesView.entry), `symbols` the
## gauges of RulesView.table().symbols, `stance` the man at the table.
static func words(entry: Dictionary, symbols: Dictionary, d: RulesDials, stance: String) -> String:
	var hyde := stance == "hyde"
	var key: String = entry.key
	if entry.t == "factor":
		var faces: Dictionary = RulesConfig.FACTOR[key]
		var other := "jekyll" if hyde else "hyde"
		var does := RulesConfig.factor_text(key, other, d)
		# The faces turn at a shift: the other man's reading, and what it does for him.
		return "Factor, %s's face: %s. %s reads it as %s, after a shift: %s" % [
				"Hyde" if hyde else "Jekyll", faces.ink if hyde else faces.paper,
				other.capitalize(), faces.paper if hyde else faces.ink, does.left(1).to_lower() + does.substr(1)]
	var root: Dictionary = RulesConfig.ROOT[key]
	var s: Dictionary = symbols[key]
	if entry.ink:
		return "Ink Root of the %s, Hyde's. %d chips, +%d for each Craving (%d), +%d for each Habit (%d): %d now." % [
				root.label, d.root_chips, d.craving_chips, s.craving, d.habit_chips, s.habit, entry.chips]
	return "Paper Root of the %s, Jekyll's. %d chips, +%d for each Temper (%d): %d now." % [
			root.label, d.root_chips, d.temper_chips, s.temper, entry.chips]


func _init() -> void:
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 0.5
	var box := StyleBoxFlat.new()
	box.bg_color = ArenaViews.CREAM
	box.border_color = ArenaViews.PENCIL
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(12)
	box.shadow_color = Color(Palette.OUTLINE, 0.3)
	box.shadow_size = 5
	add_theme_stylebox_override("panel", box)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_words.add_theme_font_override("font", _font)
	_words.add_theme_font_size_override("font_size", ArenaViews.NOTE_SIZE)
	_words.add_theme_color_override("font_color", ArenaViews.PENCIL)
	add_child(_words)


## Puts the words in, broken into lines no wider than `width`, and fits the note to them.
func say(text: String) -> void:
	var px := ArenaViews.NOTE_SIZE
	var lines := PackedStringArray()
	for said in text.split("\n"):
		var line := ""
		for word in said.split(" ", false):
			var next := word if line == "" else line + " " + word
			if line != "" and _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > width:
				lines.append(line)
				line = word
			else:
				line = next
		lines.append(line)
	_words.text = "\n".join(lines)
	size = Vector2.ZERO
	reset_size()
