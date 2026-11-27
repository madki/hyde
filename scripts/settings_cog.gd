class_name SettingsCog
extends BaseButton
## The settings cog: a small cog in a screen's top-right corner that opens the settings sheet
## (SettingsSheet) over that screen. F2 opens it too, from anywhere on the screen.
##
##   SettingsCog.add_to(self, Palette.CHALK)
##
## Drawn in the screen's own ink; under the pointer it is lit, pressed it is drawn lower. It
## takes no focus, so the screen's keys never land on it. Escape is left to the screen: the
## sheet takes it first while it is open. `--settings` opens the sheet for a still.

## The sheet has been opened from the cog or by F2.
signal opened(sheet: SettingsSheet)

## How big the cog is drawn.
const SIZE := 32.0
## How big the place is that a click finds it in.
const TARGET := 40.0
## How far the drawn cog sits in from the screen's top and right edges.
const MARGIN := 16.0
## How far a pressed cog is drawn lower.
const LOWER := 2.0
const TEETH := 8
const KEY := KEY_F2

## The cog's ink, and its ink under the pointer.
var ink := Palette.CHALK
var lit := Palette.HOT
## The light of the sheet's chosen row, or a Callable that gives it when the sheet opens.
var accent: Variant = Palette.JEKYLL


## Makes a cog, lays it in `screen`'s top-right corner and adds it, last, to `screen`. When
## `clear_of` (something of the screen's) reaches the corner, the cog is laid `down` lower.
static func add_to(screen: Control, ink_colour: Color, sheet_accent: Variant = Palette.JEKYLL,
		clear_of: Control = null, down: float = 0.0) -> SettingsCog:
	var cog := SettingsCog.new()
	cog.ink = ink_colour
	cog.lit = ink_colour.lerp(Palette.HOT, 0.6)
	cog.accent = sheet_accent
	cog._clear_of = clear_of
	cog._down = down
	cog.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cog.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cog._place(0.0)
	screen.add_child(cog)
	if clear_of:
		screen.resized.connect(cog._lay_out)
		clear_of.resized.connect(cog._lay_out)
		cog._lay_out.call_deferred()
	return cog


var _clear_of: Control
var _down := 0.0


# Lays the cog `down` below the corner.
func _place(down: float) -> void:
	var out := MARGIN - (TARGET - SIZE) / 2.0
	offset_left = -out - TARGET
	offset_right = -out
	offset_top = out + down
	offset_bottom = out + down + TARGET


# In the corner, or lower if the thing it keeps clear of reaches the corner.
func _lay_out() -> void:
	if not is_instance_valid(_clear_of) or not is_inside_tree():
		return
	_place(0.0)
	var corner := Rect2(get_global_rect().position + Vector2.ONE * (TARGET - SIZE) / 2.0,
			Vector2(SIZE, SIZE))
	if _clear_of.get_global_rect().intersects(corner):
		_place(_down)


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(TARGET, TARGET)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	pressed.connect(open_sheet)


func _ready() -> void:
	# For a still: `--settings` opens the sheet over the screen, as on the title.
	if Shot.has_arg("settings"):
		open_sheet.call_deferred()


## Opens the settings sheet over the screen, unless one is open already. Returns it, or null.
func open_sheet() -> SettingsSheet:
	if SettingsSheet.is_open() or get_parent() == null:
		return null
	var light: Color = accent.call() if accent is Callable else accent
	var sheet := SettingsSheet.open(get_parent(), light)
	queue_redraw()
	opened.emit(sheet)
	return sheet


## A key, as the cog takes it: F2 pressed opens the sheet. True if it did.
func take_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.keycode == KEY \
			and open_sheet() != null


# Before the screen's own `_input` and `_unhandled_input`; while the sheet is open, the sheet
# takes every key before the cog does.
func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and take_key(event):
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var colour := lit if is_hovered() or is_pressed() else ink
	var centre := size / 2.0 + (Vector2(0, LOWER) if is_pressed() else Vector2.ZERO)
	var outer := SIZE / 2.0
	var body := outer * 0.72
	var hole := outer * 0.3
	# The teeth: a ring of blocks standing out from the wheel.
	for i in TEETH:
		var angle := TAU * i / TEETH
		var along := Vector2.from_angle(angle)
		var across := along.orthogonal()
		var half := outer * 0.2
		var tooth := PackedVector2Array([
			centre + along * (body - 2.0) - across * half * 1.15,
			centre + along * outer - across * half,
			centre + along * outer + across * half,
			centre + along * (body - 2.0) + across * half * 1.15,
		])
		draw_colored_polygon(tooth, colour)
	# The wheel, a ring around its hole.
	var width := body - hole
	draw_arc(centre, hole + width / 2.0, 0.0, TAU, 40, colour, width, true)
