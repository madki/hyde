class_name ArenaViews
extends Control
## Views on demand: what the table does not keep on the page, one step away.
##
## - Hold Shift (or Tab, or rest the pointer on the tab at the edge, which says so):
##   every number at once, for as long as it is held. A sheet in the centre gives each
##   symbol's gauges in numbers, its Roots and what one is worth, the restraint's limit and
##   why, what the next drink costs, the scene's twist, what the dawn brings, and both men's
##   hands with their base chips and mult.
## - Rest the pointer (REST seconds, while no move plays) on a thing for its note: on the
##   twist's block or on the night's heading, the night, its twist and what the dawn brings
##   (on the heading, the road under it too); on the restraint track, its limit and why; on
##   the line's bar, the Roots on each side and what Ink ahead costs; on the score and target,
##   what is left to reach and, on the last play, the rescue; on a tally of PLAY or DISCARD,
##   what is left of it; on the sovereigns, how they are won and spent; on a pile, its count.
##   None opens over a notice, the piles' view, or while a key is held.
##   `--hover=<name>` (a name of `_THINGS`, or "night", "twist", "restraint") holds one open
##   as though the pointer rested on it, for a still, while a note may open.
## - Click the draw pile or the discards: one view of both piles (ArenaPileView), the
##   clicked one lit. Esc, a click, or any key that does not scroll it closes it.
## - With the Notebook held, the next three cards of the draw pile lie face up over it.
## - F1, or a click on the "?" under the tab at the edge: the help book (HelpBook), at the
##   page that fits the moment. Only while the player may act and nothing else lies over the table.
## - On night 1 the small word "Hint", right of DISCARD, chooses the cards of the best hand the rules find.
##   It shows no score.
##
## None of it shows the score of the chosen cards. It reads RulesView.table() and the run's
## deck; it works out no rule.

const CREAM := Palette.CHALK
const PENCIL := Palette.OUTLINE
const SMALL := 0.46
## How long the pointer rests on a thing, still, before its note opens.
const REST := 0.25
## The words of a hover's note, and of the held sheet.
const NOTE_SIZE := 14
const SHEET_SIZE := 13
## The things a note is about besides the night and the restraint, in the order the pointer
## finds them.
const _THINGS: Array[String] = ["line", "goal", "purse", "plays", "discards", "draw_pile", "discard_pile"]
## The Notebook's first card, from the middle of the draw pile's zone.
const NOTEBOOK_FROM_PILE := Vector2(-20.0, -104.0)
## How long after the pointer has left a gauge the help book still opens at the gauges' page,
## in milliseconds: long enough to cross the page to the "?".
const GAUGE_FRESH := 8000

var t: ArenaTable

var _note := PanelContainer.new()
var _words := Label.new()
## The view of the two piles.
var _deck := ArenaPileView.new()
var _notebook := Control.new()
var _hint := Button.new()
var _tabs := ArenaTabs.new()
var _book := HelpBook.new()
## When the pointer was last on a gauge, in ticks: the book then opens at the gauges' page.
## Below 0 when it has since rested on something else that has a note.
var _gauge_at := -1
var _table: Dictionary = {}
var _open := true
## True from the piles' view's opening until it begins to close.
var _deck_up := false
var _held := false
var _hover := ""
## The thing under the pointer whose note waits for it to rest, and for how much longer.
var _resting := ""
var _rest_left := 0.0
var _last_point := Vector2.INF
## The note held open by `--hover`, for a still.
var _forced := ""
## False while the pointer is outside the window.
var _pointer_here := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.5
	var box := StyleBoxFlat.new()
	box.bg_color = CREAM
	box.border_color = PENCIL
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(12)
	box.shadow_color = Color(Palette.OUTLINE, 0.3)
	box.shadow_size = 5
	_note.add_theme_stylebox_override("panel", box)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.visible = false
	_words.add_theme_font_override("font", font)
	_words.add_theme_font_size_override("font_size", NOTE_SIZE)
	_words.add_theme_color_override("font_color", PENCIL)
	_note.add_child(_words)
	_forced = Shot.arg("hover")
	# The piles' view takes every click and the wheel while it is open.
	_deck.closed.connect(func() -> void:
		# The hand takes the pointer again, unless a move has begun meanwhile.
		_deck_up = false
		t.hand.covered = _covering()
		t.hand.enabled = _open)
	_notebook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A written word, as PLAY and DISCARD are, and smaller.
	_hint.text = "Hint"
	_hint.focus_mode = Control.FOCUS_NONE
	_hint.tooltip_text = "Chooses the cards of a good hand."
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Palette.CHALK_2)
	_hint.add_theme_color_override("font_focus_color", Palette.CHALK_2)
	_hint.add_theme_color_override("font_hover_color", Palette.CHALK)
	_hint.add_theme_color_override("font_pressed_color", Palette.CHALK)
	_hint.add_theme_color_override("font_outline_color", Color(Palette.OUTLINE, 0.9))
	_hint.add_theme_constant_override("outline_size", 5)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_hint.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_hint.visible = false
	_hint.pressed.connect(_show_a_hand)
	_tabs.right = "Hold Shift"
	_book.closed.connect(func() -> void:
		# The pointer is followed again; what it lies on must be rested on before its note opens.
		_resting = "")
	for child: Control in [_tabs, _notebook, _hint, _note, _deck, _book]:
		add_child(child)


## Ties the views to the table. Call once.
func bind(table: ArenaTable) -> void:
	t = table
	_deck.t = table
	t.synced.connect(_on_synced)
	if t.arena.has_signal("settled"):
		t.arena.connect("settled", _on_settled)
	resized.connect(_place_hint)
	t.move_begun.connect(func(_move: String) -> void:
		_open = false
		_hint.visible = false
		_clear(_notebook)
		_close_deck())


func _on_synced(table: Dictionary) -> void:
	_table = table
	# The table is also synced inside a move (before a notice of it): the views stay shut
	# until the move is over.
	_open = table.phase == "play" and not _notice_up() and bool(t.arena.call("is_idle"))
	_hint.visible = _open and int(table.night.no) == 1
	_place_hint()
	_show_notebook()
	# An open note says what the table holds now.
	if _hover != "" and not _held:
		_show_note()


# The move is over and the player may act: the views open on the table as it was last synced.
func _on_settled() -> void:
	if not _table.is_empty():
		_on_synced(_table)


## The word "Hint" stands in its zone, right of DISCARD, wherever the page's size puts it.
func _place_hint() -> void:
	var zone := ArenaLayout.hint(size)
	_hint.position = zone.position
	_hint.size = zone.size


func _process(delta: float) -> void:
	if t == null:
		return
	# Under a notice, the help book or the piles' view no card of the hand answers the pointer.
	t.hand.covered = _covering()
	# Nothing here follows the pointer while the book is open.
	if _table.is_empty() or _book.is_open():
		return
	var point := get_global_mouse_position()
	# Under a notice nothing answers the pointer or the look keys.
	var covered := _notice_up()
	var tab := "" if _deck.visible or covered or not _pointer_here else _tabs.tab_at(_tabs.get_global_transform().affine_inverse() * point)
	_tabs.lit = tab
	var held := (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_TAB) or tab == "right") and not _deck.visible and not covered
	var under := {}
	if not held and _quiet_ok() and _pointer_here:
		under = _thing_at(point)
	var name: String = under.get("name", "")
	var hover := ""
	if _forced != "" and not held and _quiet_ok():
		hover = _forced
	elif name == "":
		_resting = ""
	elif name == _hover:
		hover = _hover
	else:
		# Its note waits for the pointer to rest on it, so that crossing the page does not
		# flash one note after another.
		if name != _resting or point.distance_squared_to(_last_point) > 0.25:
			_resting = name
			_rest_left = REST
		_rest_left -= delta
		if _rest_left <= 0.0:
			hover = name
	_last_point = point
	if held == _held and hover == _hover:
		return
	if held != _held:
		# The sheet of every number: a page turned in, and softer as it goes.
		Sfx.play("paper", 1.0 if held else 0.85, 0.8 if held else 0.45)
	elif hover != "":
		Sfx.play("hover_j", Sfx.vary(), 0.35)
	_held = held
	_hover = hover
	t.symbols.show_numbers(held)
	_show_note()


# Shows the held sheet, the note `_hover` names, or nothing.
func _show_note() -> void:
	var hover := _hover
	if _held:
		# In the middle of the page.
		_say(_every_number(), Vector2(0.0, ArenaLayout.note_top(size)), true, SHEET_SIZE)
	elif hover == "":
		_note.visible = false
	elif hover == "restraint":
		_say(_restraint_words(), ArenaLayout.stage(size).position + Vector2(0.0, 6.0))
	else:
		var at := _rect_of(hover)
		if at.has_area():
			_say_by(_words_of(hover), get_global_transform().affine_inverse() * at)
		else:
			_note.visible = false


# True while a note may open: no move plays, and no notice or piles' view is up. (A gauge's
# ledger opens only while the pointer rests on its gauge, where none of these things lies.)
func _quiet_ok() -> bool:
	if _deck.visible or t.waiting_press:
		return false
	if _notice_up():
		return false
	return bool(t.arena.call("is_idle"))


# True while a notice lies over the table.
func _notice_up() -> bool:
	return t.moments.notice != null and t.moments.notice.showing


# True while something lies over the hand: a notice, the help book or the piles' view.
func _covering() -> bool:
	return _notice_up() or _book.is_open() or _deck_up


# The thing under the pointer: {name}, or empty for none.
func _thing_at(point: Vector2) -> Dictionary:
	var heading := t.numbers.heading_rect()
	if heading.has_point(point):
		return {"name": "night"}
	if String(_table.night.twist) != "" and (get_global_transform() * ArenaLayout.twist(size)).has_point(point):
		return {"name": "twist"}
	if t.numbers.restraint.get_global_rect().has_point(point):
		return {"name": "restraint"}
	for name in _THINGS:
		if _rect_of(name).has_point(point):
			return {"name": name}
	return {}


# Where a thing a note is about lies, on the page.
func _rect_of(name: String) -> Rect2:
	match name:
		"night":
			return t.numbers.heading_rect()
		"twist":
			return get_global_transform() * ArenaLayout.twist(size) if String(_table.night.twist) != "" else Rect2()
		"restraint":
			return t.numbers.restraint.get_global_rect()
		"line":
			return t.symbols.line_rect()
		"goal", "purse", "plays", "discards":
			return t.numbers.note_rect(name)
		"draw_pile":
			return t.piles.pile("draw").get_global_rect()
		"discard_pile":
			return t.piles.pile("discards").get_global_rect()
	return Rect2()


func _words_of(name: String) -> String:
	match name:
		"night":
			return _night_words() + "\n" + _road_words()
		"twist":
			return _night_words()
		"line":
			return _line_words()
		"goal":
			return _goal_words()
		"purse":
			return _purse_words()
		"plays", "discards":
			return _tally_words(name)
		"draw_pile", "discard_pile":
			return _pile_words(name)
	return ""


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if _deck.visible:
		# The scroll keys scroll it; any other key closes it.
		if key and not _deck.scroll_key(key) and key.pressed and not key.echo:
			_close_deck()
		if key:
			get_viewport().set_input_as_handled()
		return
	# A key held to look is no press: it must not reach the table, which may wait for one.
	if key and key.keycode in ArenaBeats.LOOK_KEYS:
		get_viewport().set_input_as_handled()
	var on_help := button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
			and _tabs.tab_at((_tabs.make_input_local(button) as InputEventMouseButton).position) == "help"
	if on_help or (key and key.pressed and not key.echo and key.keycode == KEY_F1):
		get_viewport().set_input_as_handled()
		_open_help()
		return
	if _open and button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		for which: String in ["draw", "discards"]:
			if t.piles.pile(which).get_global_rect().has_point(get_global_mouse_position()):
				get_viewport().set_input_as_handled()
				_open_pile(which)
				return


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if ArenaLayout.symbols(size).has_point((make_input_local(event) as InputEventMouseMotion).position):
			_gauge_at = Time.get_ticks_msec()
		elif _hover != "":
			_gauge_at = -1


# Opens the help book at the page that fits the moment (HelpPages.page_for), in the colours
# of the man at the table. Not while a move is played back, a notice or the piles' view is
# up, or a key is held to look. Nothing here follows the pointer while the book is open: no
# note opens under it, and when it closes a note waits for the pointer's rest anew.
func _open_help() -> void:
	if not _open or _held or not _quiet_ok() or t.beats.is_running():
		return
	_note.visible = false
	_hover = ""
	_resting = ""
	_tabs.lit = ""
	var gauge_last := _gauge_at >= 0 and Time.get_ticks_msec() - _gauge_at < GAUGE_FRESH
	_book.open(HelpPages.page_for(_table, gauge_last), _table.stance == "hyde", t.run.dials)
	t.hand.covered = true


# Shows the note with these words, its top left corner at `at`, or `centred` across the page
# at that height.
func _say(words: String, at: Vector2, centred: bool = false, font_size: int = NOTE_SIZE) -> void:
	_words.add_theme_font_size_override("font_size", font_size)
	_words.text = words
	_note.size = Vector2.ZERO
	_note.reset_size()
	if centred:
		at.x = (size.x - _note.size.x) * 0.5
	# Kept on the page, whatever its words' length.
	_note.position = Vector2(clampf(at.x, 8.0, maxf(8.0, size.x - _note.size.x - 44.0)), minf(at.y, size.y - _note.size.y - 44.0))
	_note.visible = true


# Shows the note with these words by `rect` (in this control's coordinates): under it, its
# middle under the rect's, or above it where there is no room under it.
func _say_by(words: String, rect: Rect2) -> void:
	_say(words, Vector2.ZERO)
	var extent := _note.size
	var at := Vector2(rect.get_center().x - extent.x * 0.5, rect.end.y + 8.0)
	if at.y + extent.y > size.y - 44.0:
		at.y = rect.position.y - 8.0 - extent.y
	_say(words, at)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		_pointer_here = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_pointer_here = false


# ---------- the words ----------

func _night_words() -> String:
	var night: Dictionary = _table.night
	var dawn: Dictionary = night.dawn
	var lines: Array[String] = ["Night %d: %s" % [night.no, night.title], "Its scene: %s" % night.twist_text]
	if dawn.ends:
		lines.append("This night's scene ends the run.")
	else:
		var brings := "Dawn brings no Roots of his."
		if dawn.brings_name != "":
			brings = "Dawn brings two %s%s." % [dawn.brings_name, " (his strongest Habit)" if dawn.by_habit else ""]
		if dawn.unlocks_name != "":
			brings += " %s can then be found." % dawn.unlocks_name
		lines.append(brings)
		lines.append("The dawn is spent in %s." % ("the back alley" if dawn.place == "alley" else "the laboratory"))
	return "\n".join(lines)


# The night's road, under its heading: where on it the table stands.
func _road_words() -> String:
	var night: Dictionary = _table.night
	var after := "the run's end" if night.dawn.ends else "the dawn"
	if night.scene:
		return "The road: both rounds are behind; this is the night's scene, then %s." % after
	return "The road: round %d of 2, then the night's scene, then %s." % [night.round, after]


func _line_words() -> String:
	var line: Dictionary = _table.line
	var paper := int(line.paper)
	var ink := int(line.ink)
	var lines: Array[String] = [
		"%d Paper Root%s against %d Ink Root%s, in the whole deck." % [paper, "" if paper == 1 else "s", ink, "" if ink == 1 else "s"],
		"The bar is shared between them, Paper from the left, Ink from the right.",
		"Past the mark at its middle, Ink is ahead.",
	]
	if bool(line.over):
		lines.append("Ink is ahead now. If it still is when this round ends, the run is lost.")
	else:
		lines.append("If Ink is ahead when a round ends, the run is lost.")
		if paper == ink:
			lines.append("They are level: one more Ink Root puts it ahead.")
	return "\n".join(lines)


func _goal_words() -> String:
	var plays := int(_table.plays)
	var target := _grouped(int(_table.target))
	var lines: Array[String] = ["Score %s of %s." % [_grouped(int(_table.score)), target]]
	lines.append("Reach %s with the plays you have. %d play%s left." % [target, plays, "" if plays == 1 else "s"])
	if plays == 1:
		lines.append("This is the last play. If it falls short, the Paper Roots still in your hand")
		lines.append("turn to Ink one by one, each doubling what the play scored, until the target")
		lines.append("is reached; the round then pays nothing. If even all of them fall short, the run is lost.")
	return "\n".join(lines)


# 1000 as "1,000", as the goal writes it.
static func _grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


func _purse_words() -> String:
	var sov := int(_table.sov)
	var dials := t.run.dials
	return "\n".join([
		"%d sovereign%s." % [sov, "" if sov == 1 else "s"],
		"A round won pays %d, and %d more for each play left. A rescued round pays nothing." % [dials.round_pay, dials.unused_play_pay],
		"They are spent at dawn. Jekyll's dawn is in the laboratory: cards, instruments,",
		"salt, and a card struck from the deck. Hyde's is in the back alley: only salt, dearer.",
	])


func _tally_words(which: String) -> String:
	var n := int(_table[which])
	if which == "plays":
		return "%d play%s left this round.\nA round won pays %d sovereign more for each play left." % [
			n, "" if n == 1 else "s", t.run.dials.unused_play_pay]
	if n == 0:
		return "No discards left this round."
	return "%d discard%s left: a discard draws new cards and scores nothing." % [n, "" if n == 1 else "s"]


func _pile_words(which: String) -> String:
	var n := int(_table.draw_count if which == "draw_pile" else _table.discard_count)
	var words := "%s, %d card%s." % ["Draw pile" if which == "draw_pile" else "Discards", n, "" if n == 1 else "s"]
	if _open:
		words += "\nClick to look through both piles."
	return words


func _restraint_words() -> String:
	var r: Dictionary = _table.restraint
	var words := "Restraint holds %d this round" % r.limit
	if _table.instruments.has("balance"):
		words += ", with the Balance"
	words += ". At the last step he breaks out."
	if int(r.scene_limit) != int(r.limit):
		words += "\nIn this night's scene it holds %d." % r.scene_limit
	if int(r.stored) > 0:
		words += "\n%d stored: +%d mult on his first hand." % [r.stored, int(r.stored) * t.run.dials.restraint_pay]
	return words


func _every_number() -> String:
	var lines: Array[String] = []
	for sym in RulesConfig.ROOTS:
		var s: Dictionary = _table.symbols[sym]
		var names: Dictionary = RulesConfig.ROOT[sym]
		lines.append("%s: Craving %d, Habit %d, Temper %d.  %d %s at %d chips, %d %s at %d." % [
			names.label, s.craving, s.habit, s.temper, s.paper, names.paper, s.paper_chips, s.ink, names.ink, s.ink_chips])
	lines.append("")
	lines.append(_restraint_words())
	var draught: Dictionary = _table.draught
	lines.append("The next drink: %s%s" % [
		"his four Roots join the deck." if draught.cost == "first" else "a Paper Root is stained.",
		"" if draught.ok else "  (%s)" % draught.why])
	var salt: Dictionary = _table.salt
	lines.append("Salt: %d doses.%s" % [salt.doses, "" if salt.ok else "  (%s)" % salt.why])
	for key: String in _table.instruments:
		lines.append("%s: %s" % [RulesConfig.INSTRUMENTS[key].name, RulesConfig.instrument_text(key, t.run.dials)])
	lines.append("")
	lines.append(_night_words())
	lines.append("")
	for stance: String in ["jekyll", "hyde"]:
		var hands: Array[String] = []
		for key: String in RulesConfig.HANDS[stance]:
			var hand: Dictionary = RulesConfig.HANDS[stance][key]
			hands.append("%s %d×%d" % [hand.name, hand.chips, hand.mult])
		lines.append("%s: %s." % ["Jekyll" if stance == "jekyll" else "Hyde", ", ".join(hands.slice(0, 3))])
		lines.append("    %s." % ", ".join(hands.slice(3)))
	return "\n".join(lines)


# ---------- the deck ----------

## Opens the view of both piles, the section of `which` ("draw" or "discards") lit. Only
## while the player may act.
func _open_pile(which: String) -> void:
	if not _open:
		return
	_deck.open(which)
	_deck_up = true
	t.hand.covered = true
	_note.visible = false
	# The hand lies under the view: no card of it takes the pointer while the view is open.
	t.hand.enabled = false


func _close_deck() -> void:
	_deck.close()


# ---------- the Notebook ----------

func _show_notebook() -> void:
	_clear(_notebook)
	var next: Variant = _table.notebook
	if next == null or not _open:
		return
	# Over the pile's zone, between it and the lower rule, left of the hand's zone.
	var at := ArenaLayout.pile_draw(size).get_center() + NOTEBOOK_FROM_PILE
	# The next card lies on top, at the right.
	for i in range(next.size() - 1, -1, -1):
		var card := ArenaTravel.make_card(t.card_data(next[i].id))
		card.scale = Vector2(SMALL, SMALL)
		card.rotation_degrees = -6.0 + 6.0 * (next.size() - 1 - i)
		card.position = at + Vector2(22.0 * (next.size() - 1 - i), 0.0) - card.pivot_offset
		_notebook.add_child(card)


# ---------- the hint ----------

func _show_a_hand() -> void:
	if not _open:
		return
	var best: Dictionary = Rules.best(t.run)
	t.hand.clear_chosen()
	if not best.get("ids", []).is_empty():
		Sfx.play("choose_j", 1.12, 0.7) # a card lifted, a touch brighter: a thought arriving
	for id: int in best.get("ids", []):
		t.hand.toggle(id)


func _clear(holder: Control) -> void:
	for child in holder.get_children():
		child.queue_free()
