extends Control
## A bench for the deck's strip (scripts/shop_deck_strip.gd) and the deck it opens
## (scripts/shop_deck_view.gd): two strips on the two sheets' colours, Jekyll's above and
## Hyde's under it, both showing one new run's deck. Click a strip, or press D, to open the
## deck; S opens it as a picker, with the rules' prices and the first card shut.
##
## For a still: `tools/shot.sh /abs/out.png res://scenes/shop_deck_strip_bench.tscn`, with:
##
## - `--ink=<n>`: that many Ink Roots join the deck (0 by default: a new run holds none).
## - `--factors=<n>`: that many Factors join it.
## - `--counts=8,4,0`: the strips show these counts instead (Paper Roots, Ink Roots, others),
##   whatever the deck holds.
## - `--focus`: the upper strip has the focus.
## - `--open`: the deck is open; `--picker`: it is open as a picker.
## - `--keys=rrde`: keys pressed as a player would, in turn: l Left, r Right, u Up, d Down,
##   e Enter, x Escape.
## - `--point=300,200`: the pointer moved there, and `--click` a click there.
##
## `--check` asks the strip what a still cannot show, prints a line for each and DECK STRIP
## CHECK PASS or FAIL, and quits. It needs no window:
##
##   godot --headless --path . res://scenes/shop_deck_strip_bench.tscn -- --check

@onready var _upper: ShopDeckStrip = $Jekyll/Strip
@onready var _lower: ShopDeckStrip = $Hyde/Strip
@onready var _said: Label = $Said

var _run: RulesRun


func _ready() -> void:
	_run = Rules.new_run()
	for i in int(Shot.arg("ink")):
		Rules.add_card(_run, RulesConfig.ROOTS[i % RulesConfig.ROOTS.size()], true, false)
	for i in int(Shot.arg("factors")):
		Rules.add_card(_run, RulesConfig.FACTORS[i % RulesConfig.FACTORS.size()], false, false)
	for strip: ShopDeckStrip in [_upper, _lower]:
		strip.show_run(_run)
		strip.card_picked.connect(_on_picked)
		strip.opened.connect(func() -> void: _said.text = "opened")
		strip.closed.connect(func() -> void: _said.text = "closed")
	var counts := Shot.arg("counts").split(",")
	if counts.size() == 3:
		for strip: ShopDeckStrip in [_upper, _lower]:
			strip.set_counts(int(counts[0]), int(counts[1]), int(counts[2]))
	if Shot.has_arg("check"):
		await _check()
		return
	if Shot.has_arg("focus"):
		_upper.grab_focus()
	if Shot.has_arg("picker"):
		_open_picker()
	elif Shot.has_arg("open"):
		_upper.open()
	if Shot.has_arg("shot"):
		await _play_input()
		await get_tree().create_timer(0.6).timeout
	Shot.run_if_requested(self)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_S:
		_open_picker()


# The picker as a page would open it to strike a card: every card with the rules' price, and
# one of them shut with a reason, to show that state.
func _open_picker() -> void:
	var cards: Array = []
	for c: RulesCard in _run.cards:
		var entry := RulesView.entry(_run, c, _run.stance)
		entry.price = Rules.strike_price(c)
		entry.ok = cards.size() != 1
		entry.why = "" if entry.ok else "The bench shuts this card, to show one that cannot be chosen."
		cards.append(entry)
	_upper.open_picker(cards, "Strike a card", "A card struck here leaves the deck for good.")


func _on_picked(card: Dictionary) -> void:
	_said.text = "picked: %s (id %d)" % [card.get("name", "?"), int(card.get("id", -1))]


func _play_input() -> void:
	const KEYS := {"l": KEY_LEFT, "r": KEY_RIGHT, "u": KEY_UP, "d": KEY_DOWN, "e": KEY_ENTER, "x": KEY_ESCAPE}
	for letter in Shot.arg("keys"):
		if KEYS.has(letter):
			await _send(KEYS[letter])
	var given := Shot.arg("point").split(",")
	if given.size() != 2:
		return
	var point := Vector2(float(given[0]), float(given[1]))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	if Shot.has_arg("click"):
		await _click(point)


func _send(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame


func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = point
		button.global_position = point
		# In the page's own coordinates, whatever the window's size is.
		get_viewport().push_input(button, true)
		await get_tree().process_frame
		await get_tree().process_frame


# ---------- the check ----------

func _check() -> void:
	var failed := [0]
	var say := func(ok: bool, what: String) -> void:
		print("  %s  %s" % ["ok  " if ok else "FAIL", what])
		if not ok:
			failed[0] += 1
	var picked: Array = []
	_upper.card_picked.connect(func(card: Dictionary) -> void: picked.append(card))
	var gone := ShopDeckView.SHADE_OUT + 0.1
	var line := Rules.line_info(_run)
	say.call(_upper.deck_count() == int(line.total), "the strip's count is the rules' (%d cards)" % int(line.total))

	await _click(_upper.get_global_rect().get_center())
	say.call(_upper.is_open(), "a click on the strip opens the deck")
	await _send(KEY_ESCAPE)
	await get_tree().create_timer(gone).timeout
	say.call(not _upper.is_open(), "Escape closes it")

	await _send(KEY_D)
	say.call(_upper.is_open() != _lower.is_open(), "the key opens one deck")
	await _click(Vector2(8.0, 8.0))
	await get_tree().create_timer(gone).timeout
	say.call(not _upper.is_open() and not _lower.is_open(), "a click closes it")

	_upper.grab_focus()
	await _send(KEY_ENTER)
	say.call(_upper.is_open(), "Enter on the strip with the focus opens it")
	await _send(KEY_ENTER)
	await get_tree().create_timer(gone).timeout
	say.call(not _upper.is_open() and _upper.has_focus(), "Enter closes it, and the focus is back on the strip")

	_open_picker()
	await get_tree().process_frame
	await _send(KEY_RIGHT)
	await _send(KEY_ENTER)
	say.call(picked.is_empty() and _upper.is_open(), "a card that cannot be chosen is not picked")
	await _send(KEY_RIGHT)
	await _send(KEY_ENTER)
	say.call(picked.size() == 1 and int(picked[0].id) == _run.cards[2].id, "the arrow keys and Enter pick a card")
	await get_tree().create_timer(gone).timeout
	say.call(not _upper.is_open(), "the picker closes when a card is picked")

	_open_picker()
	await get_tree().process_frame
	await _send(KEY_ESCAPE)
	await get_tree().create_timer(gone).timeout
	say.call(picked.size() == 1 and not _upper.is_open(), "Escape leaves the picker with nothing picked")

	_upper.set_counts(3, 1, 2)
	say.call(_upper.deck_count() == 6, "the counts given are the counts shown")

	print("DECK STRIP CHECK %s" % ("PASS" if failed[0] == 0 else "FAIL (%d)" % failed[0]))
	get_tree().quit(0 if failed[0] == 0 else 1)
