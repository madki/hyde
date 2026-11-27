extends Control
## A bench for one slot of a place's shelf (scripts/shop_ware.gd): every kind of ware in
## every state, to check in a still or by hand. The wares and their reasons are the bench's
## own, made up to drive the slot; a place takes them from the rules.
##
## Six rows: a card, an instrument of the laboratory and a dose of salt, each with a price;
## then a card and one of his instruments, each free, and a service. Four columns: available,
## too dear, not allowed, bought.
##
## By hand: the pointer or the arrows light a slot, a click or Enter takes it. An available
## ware is then bought (its slot is left empty); the last signal is written at the foot.
##
## For a still: `tools/shot.sh /abs/out.png res://scenes/shop_ware_bench.tscn`, with `--hyde`
## for his tone, `--focus=<row>,<column>` (from 0) for the slot that has the focus, and
## `--lit` to light every slot at once. `--take` then presses Enter, and `--point=200,300`
## moves the pointer there, with `--click` for a click there.

const COLUMNS: Array[String] = ["available", "too dear", "not allowed", "bought"]
const LEFT := 40.0
const RIGHT := 620.0
const TOP := 44.0
const PITCH := 124.0

var _wares: Array = []

@onready var _sheet: ColorRect = $Sheet
@onready var _said: Label = $Said


func _ready() -> void:
	var hyde := Shot.has_arg("hyde")
	_sheet.color = Palette.INK_DEEP if hyde else Palette.PAGE_DARK
	var accent := Palette.HYDE if hyde else Palette.JEKYLL
	for block in 2:
		for c in COLUMNS.size():
			var label := Label.new()
			label.text = COLUMNS[c]
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Palette.CHALK_3)
			label.position = Vector2((LEFT if block == 0 else RIGHT) + c * PITCH, 16.0)
			add_child(label)
	_add_row(LEFT, TOP, accent, func(w: ShopWare) -> void:
		w.show_card({"key": "lamp", "name": "Composure", "chips": 15}, 4)
		w.set_price(3), "It costs 3 sovereigns: you hold 1.", "The deck is full.", "sold")
	_add_row(LEFT, TOP + ShopWare.CARD_SLOT.y + 8.0, accent, func(w: ShopWare) -> void:
		w.show_instrument("balance", "Balance", "Restraint holds 2 more.")
		w.set_price(6), "It costs 6 sovereigns: you hold 1.", "You hold three instruments already.", "sold")
	_add_row(LEFT, TOP + ShopWare.CARD_SLOT.y + ShopWare.SMALL_SLOT.y + 16.0, accent, func(w: ShopWare) -> void:
		w.show_salt("A dose of salt", "One more dose for the nights ahead.")
		w.set_price(3), "It costs 3 sovereigns: you hold 1.", "No more salt is sold this dawn.", "sold")
	_add_row(RIGHT, TOP, accent, func(w: ShopWare) -> void:
		w.show_card({"key": "heart", "ink": true, "name": "Appetite", "chips": 15}, 9)
		w.set_price(0), "", "One Habit a dawn.", "taken")
	_add_row(RIGHT, TOP + ShopWare.CARD_SLOT.y + 8.0, accent, func(w: ShopWare) -> void:
		w.show_instrument("hcane", "The Cane", "His Mania gains 2 mult.")
		w.set_price(0), "", "You hold three instruments already.", "taken")
	_add_row(RIGHT, TOP + ShopWare.CARD_SLOT.y + ShopWare.SMALL_SLOT.y + 16.0, accent, func(w: ShopWare) -> void:
		w.show_service("Strike a card", "Takes one card out of the deck for good.")
		w.set_uses(1), "It costs 4 sovereigns: you hold 1.", "One card a dawn.", "struck")
	if Shot.has_arg("lit"):
		for row: Array in _wares:
			for ware: ShopWare in row:
				ware.force_lit(true)
	var focus := Shot.arg("focus").split(",")
	if focus.size() == 2:
		(_wares[int(focus[0])][int(focus[1])] as ShopWare).grab_focus()
	_play_input()
	Shot.run_if_requested(self)


## One row of four slots, each set up by `show` and then put in its column's state.
func _add_row(left: float, top: float, accent: Color, show: Callable, dear: String, barred: String,
		word: String) -> void:
	var row: Array[ShopWare] = []
	for c in COLUMNS.size():
		var ware := ShopWare.new()
		ware.accent = accent
		show.call(ware)
		ware.position = Vector2(left + c * PITCH, top)
		add_child(ware)
		match c:
			1:
				ware.set_state(ShopWare.State.TOO_DEAR, dear)
			2:
				ware.set_state(ShopWare.State.NOT_ALLOWED, barred)
				if COLUMNS[c] == "not allowed" and word == "struck":
					ware.set_uses(0)
			3:
				ware.set_state(ShopWare.State.BOUGHT, "", word)
		var at := "%d,%d" % [_wares.size(), c]
		ware.chosen.connect(func() -> void:
			_said.text = "last signal: chosen %s" % at
			ware.set_state(ShopWare.State.BOUGHT, "", word))
		ware.refused.connect(func(why: String) -> void: _said.text = "last signal: refused %s (%s)" % [at, why])
		row.append(ware)
	_wares.append(row)


## Plays the input asked for on the command line through the game's own input.
func _play_input() -> void:
	if Shot.has_arg("take"):
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		Input.parse_input_event(key)
	var given := Shot.arg("point").split(",")
	if given.size() != 2:
		return
	var point := Vector2(float(given[0]), float(given[1]))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	if Shot.has_arg("click"):
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = true
		button.position = point
		button.global_position = point
		Input.parse_input_event(button)
