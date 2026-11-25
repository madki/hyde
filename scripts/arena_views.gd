class_name ArenaViews
extends Control
## Views on demand: what the table does not keep on the page, one step away.
##
## - Hold Shift (or Tab, or rest the pointer on the tab at the right edge, which says so):
##   every number at once, for as long as it is held. A sheet in the centre gives each
##   symbol's gauges in numbers, its Roots and what one is worth, the restraint's limit and
##   why, what the next drink costs, the scene's twist, what the dawn brings, and both men's
##   hands with their base chips and mult.
## - Rest the pointer on the tab at the left edge, which names the scene's twist: the twist
##   and what the dawn brings. On the restraint track: its limit and why.
## - Click the draw pile or the discards: the cards that lie in that pile, and no others,
##   in a shuffled order (the pile's own order is not shown). A click or a key closes it.
## - With the Notebook held, the next three cards of the draw pile lie face up over it.
## - On night 1 the small word "Hint", right of DISCARD, chooses the cards of the best hand the rules find.
##   It shows no score.
##
## None of it shows the score of the chosen cards. It reads RulesView.table() and the run's
## deck; it works out no rule.

const CREAM := Palette.CHALK
const PENCIL := Palette.OUTLINE
const SMALL := 0.46
## The Notebook's first card, from the middle of the draw pile's zone.
const NOTEBOOK_FROM_PILE := Vector2(-20.0, -104.0)

var t: ArenaTable

var _note := PanelContainer.new()
var _words := Label.new()
var _deck := Control.new()
var _deck_title := Label.new()
var _notebook := Control.new()
var _hint := Button.new()
var _tabs := ArenaTabs.new()
var _table: Dictionary = {}
var _open := true
var _held := false
var _hover := ""
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
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", PENCIL)
	_note.add_child(_words)
	# The deck's page: it takes every click while it is open.
	_deck.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck.visible = false
	_deck.gui_input.connect(func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button and button.pressed:
			_close_deck())
	_deck_title.add_theme_font_override("font", font)
	_deck_title.add_theme_font_size_override("font_size", 17)
	_deck_title.add_theme_color_override("font_color", CREAM)
	_deck_title.add_theme_color_override("font_outline_color", Color(Palette.OUTLINE, 0.9))
	_deck_title.add_theme_constant_override("outline_size", 6)
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
	for child: Control in [_tabs, _notebook, _hint, _note, _deck]:
		add_child(child)


## Ties the views to the table. Call once.
func bind(table: ArenaTable) -> void:
	t = table
	t.synced.connect(_on_synced)
	resized.connect(_place_hint)
	t.move_begun.connect(func(_move: String) -> void:
		_name_twist(RulesView.table(t.run).night)
		_open = false
		_hint.visible = false
		_clear(_notebook)
		_close_deck())


func _on_synced(table: Dictionary) -> void:
	_table = table
	_open = table.phase == "play"
	_hint.visible = _open and int(table.night.no) == 1
	_place_hint()
	_name_twist(table.night)
	_show_notebook()


## The word "Hint" stands in its zone, right of DISCARD, wherever the page's size puts it.
func _place_hint() -> void:
	var zone := ArenaLayout.hint(size)
	_hint.position = zone.position
	_hint.size = zone.size


func _process(_delta: float) -> void:
	if t == null or _table.is_empty():
		return
	var point := get_global_mouse_position()
	var tab := "" if _deck.visible or not _pointer_here else _tabs.tab_at(_tabs.get_global_transform().affine_inverse() * point)
	_tabs.lit = tab
	var held := (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_TAB) or tab == "right") and not _deck.visible
	var hover := ""
	if not held and not _deck.visible and _pointer_here:
		if tab == "left":
			hover = "night"
		elif t.numbers.restraint.get_global_rect().has_point(point):
			hover = "restraint"
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
	if held:
		# In the middle of the page.
		_say(_every_number(), Vector2(0.0, ArenaLayout.note_top(size)), true)
	elif hover == "night":
		var left := _tabs.rect_of("left")
		_say(_night_words(), Vector2(left.end.x + 12.0, left.position.y))
	elif hover == "restraint":
		_say(_restraint_words(), ArenaLayout.stage(size).position + Vector2(0.0, 6.0))
	else:
		_note.visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var button := event as InputEventMouseButton
	if _deck.visible:
		if key and key.pressed and not key.echo:
			get_viewport().set_input_as_handled()
			_close_deck()
		return
	# A key held to look is no press: it must not reach the table, which may wait for one.
	if key and key.keycode in ArenaBeats.LOOK_KEYS:
		get_viewport().set_input_as_handled()
	if _open and button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		for which: String in ["draw", "discards"]:
			if t.piles.pile(which).get_global_rect().has_point(get_global_mouse_position()):
				get_viewport().set_input_as_handled()
				_open_pile(which)
				return


# Writes the scene's twist on the left tab: `night` is RulesView.table().night.
func _name_twist(night: Dictionary) -> void:
	var twist: String = night.twist
	_tabs.left = "Twist: %s" % (twist.capitalize() if twist != "" else "none")


# Shows the note with these words, its top left corner at `at`, or `centred` across the page
# at that height.
func _say(words: String, at: Vector2, centred: bool = false) -> void:
	_words.text = words
	_note.size = Vector2.ZERO
	_note.reset_size()
	if centred:
		at.x = (size.x - _note.size.x) * 0.5
	# Kept on the page, whatever its words' length.
	_note.position = Vector2(clampf(at.x, 8.0, maxf(8.0, size.x - _note.size.x - 44.0)), minf(at.y, size.y - _note.size.y - 44.0))
	_note.visible = true


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

func _open_pile(which: String) -> void:
	_clear(_deck)
	var run := t.run
	# Only the cards that lie in this pile, shuffled anew each time it is looked at: the
	# pile's own order is never shown. The shuffle is the view's, not the run's.
	var ids: Array = (run.discard if which == "discards" else run.draw).duplicate()
	ids.shuffle()
	var entries: Array = []
	for id: int in ids:
		entries.append(t.entry(id))
	var shade := ColorRect.new()
	shade.color = Color(Palette.NIGHT_1, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck.add_child(shade)
	# A few cards are shown nearly full size, many small.
	var card_scale := 0.85 if entries.size() <= 8 else (0.62 if entries.size() <= 14 else SMALL)
	var pitch := Vector2(ArenaCard.SIZE.x * card_scale + 8.0, ArenaCard.SIZE.y * card_scale + 10.0)
	var a_row := maxi(1, int((size.x - 160.0) / pitch.x))
	var rows := ceili(entries.size() / float(a_row))
	var top := (size.y - rows * pitch.y) * 0.5 + 16.0
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var card := ArenaCard.new()
		card.show_entry(entry, t.hyde())
		card.scale = Vector2(card_scale, card_scale)
		@warning_ignore("integer_division")
		var in_row := mini(a_row, entries.size() - (i / a_row) * a_row)
		@warning_ignore("integer_division")
		var middle := Vector2((size.x - in_row * pitch.x) * 0.5 + (i % a_row + 0.5) * pitch.x, top + (i / a_row + 0.5) * pitch.y)
		card.position = middle - card.pivot_offset
		_deck.add_child(card)
	var pile_name := "discards" if which == "discards" else "draw pile"
	if entries.is_empty():
		_deck_title.text = "The %s is empty. Click to close." % pile_name
	else:
		_deck_title.text = "The %s: %d card%s, in no order. Click to close." % [pile_name, entries.size(),
				"" if entries.size() == 1 else "s"]
	_deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_title.position = Vector2(0.0, top - 44.0)
	_deck_title.size = Vector2(size.x, 26.0)
	_deck.add_child(_deck_title)
	_deck.visible = true
	Sfx.play("riffle", 1.15, 0.8) # the pile fanned out
	_note.visible = false
	# The hand lies under the view: no card of it grows there while the view is open.
	t.hand.enabled = false


func _close_deck() -> void:
	if not _deck.visible:
		return
	_deck.visible = false
	Sfx.play("riffle", 0.9, 0.5)
	if _deck_title.get_parent() == _deck:
		_deck.remove_child(_deck_title)
	_clear(_deck)
	# The hand takes the pointer again, unless a move has begun meanwhile.
	t.hand.enabled = _open


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
		if child != _deck_title:
			child.queue_free()
