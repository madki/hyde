extends Control
## A bench for the shop sheet (scripts/shop_sheet.gd): the sheet over a place's picture, at the
## size the picture leaves free, with its header, its headings and Leave. Faint outlines stand
## where a page would lay its wares, to judge the room; they are the bench's own.
##
## `tools/shot.sh /abs/sheet.png res://scenes/shop_sheet_bench.tscn [args]`, or run the scene:
## Tab gives Leave the focus, Enter or a click presses it, T changes the tone.
##
## - (no argument): the laboratory, Jekyll's sheet on the right of the page.
## - `--hyde`: the alley, Hyde's sheet on the left of the page; it has no Service group.
## - `--purse=13`, `--salt=2`: what is held (a number below 0 is not shown).
## - `--next=<words>`: the night to come, on the Leave button.
## - `--focus`: Leave has the focus.
## - `--bare`: without the outlines.

## The part of the page each picture leaves free, as far as the bottom of the window less EDGE.
const LAB_LEFT := 610.0
const LAB_WIDTH := 530.0
const ALLEY_LEFT := 72.0
const ALLEY_WIDTH := 576.0
const EDGE := 8.0
const CARD_GAP := 14.0
const EMBLEM := Vector2(64.0, 64.0)
const PRICE_ROOM := 26.0

var _hyde := false
var _pressed := 0
## Where the wares would lie, on the sheet.
var _slots: Array[Rect2] = []

@onready var _sheet: ShopSheet = $Sheet
@onready var _outlines: Control = $Sheet/Outlines


func _ready() -> void:
	_hyde = Shot.has_arg("hyde")
	_sheet.set_purse(int(Shot.arg("purse")) if Shot.has_arg("purse") else 13,
			int(Shot.arg("salt")) if Shot.has_arg("salt") else 2)
	_sheet.set_leave(Shot.arg("next") if Shot.has_arg("next") else "Night 2: Search for Mr Hyde")
	_sheet.leave.connect(func() -> void:
		_pressed += 1
		print("Leave pressed (%d)" % _pressed))
	_outlines.visible = not Shot.has_arg("bare")
	_outlines.draw.connect(_draw_outlines)
	get_viewport().size_changed.connect(_dress)
	_dress()
	if Shot.has_arg("focus"):
		_sheet.leave_button.grab_focus()
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_T:
		_hyde = not _hyde
		_dress()


# Places the sheet for its room and lays the headings as a page would.
func _dress() -> void:
	$Lab.visible = not _hyde
	$Alley.visible = _hyde
	var height := get_viewport_rect().size.y - 2.0 * EDGE
	_sheet.position = Vector2(ALLEY_LEFT if _hyde else LAB_LEFT, EDGE)
	_sheet.size = Vector2(ALLEY_WIDTH if _hyde else LAB_WIDTH, height)
	_sheet.tone = "hyde" if _hyde else "jekyll"
	_sheet.set_place("The back alley" if _hyde else "The laboratory")
	var room := _sheet.room()
	# The deck strip's room, then the cards, then the lower row in one group or two.
	var y := room.position.y + 40.0
	var headings: Array = [{text = "Cards", at = Vector2(room.position.x, y), width = room.size.x}]
	y += ShopSheet.HEADING_HEIGHT
	_slots.clear()
	var cards := 3
	var row_width := cards * ArenaCard.SIZE.x + (cards - 1) * CARD_GAP
	var cards_box := Rect2(room.position.x + (room.size.x - row_width) * 0.5, y, row_width, ArenaCard.SIZE.y)
	for i in cards:
		_slots.append(Rect2(cards_box.position + Vector2(i * (ArenaCard.SIZE.x + CARD_GAP), 0.0), ArenaCard.SIZE))
	_sheet.wares = cards_box
	y += ArenaCard.SIZE.y + PRICE_ROOM + 14.0
	var split := room.end.x if _hyde else room.position.x + room.size.x * 0.68
	headings.append({text = "Free" if _hyde else "Instruments & salt", at = Vector2(room.position.x, y),
			width = split - room.position.x - (0.0 if _hyde else 14.0)})
	var dividers: Array = []
	if not _hyde:
		headings.append({text = "Service", at = Vector2(split + 14.0, y), width = room.end.x - split - 14.0})
		dividers.append([Vector2(split, y), Vector2(split, y + ShopSheet.HEADING_HEIGHT + EMBLEM.y + PRICE_ROOM)])
		_slots.append(Rect2(Vector2(split + 14.0, y + ShopSheet.HEADING_HEIGHT), EMBLEM))
	for i in 2 if _hyde else 3:
		_slots.append(Rect2(Vector2(room.position.x + i * (EMBLEM.x + 40.0), y + ShopSheet.HEADING_HEIGHT), EMBLEM))
	_sheet.set_headings(headings)
	_sheet.set_dividers(dividers)
	_outlines.queue_redraw()


func _draw_outlines() -> void:
	var room := _sheet.room()
	var colour := Color(Palette.CHALK_3, 0.5)
	_outlines.draw_rect(Rect2(room.position, Vector2(room.size.x, 30.0)), colour, false, 1.0)
	for slot in _slots:
		_outlines.draw_rect(slot, colour, false, 1.0)
