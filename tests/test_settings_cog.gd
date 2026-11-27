extends "res://tests/case.gd"
## The settings cog over a screen that takes Escape itself, as the table does (Escape puts the
## held cards back): F2 opens the settings sheet, Escape closes it and leaves the cards held;
## with the sheet closed, Escape is the screen's again. The tests have no running tree, so a
## key is given as the window gives it: to the open sheet's input, else to the cog's, else to
## the screen's unhandled input. (The table itself is not made here: a new one gives up the
## kept run.)


## A screen with a hand: 1 to 9 hold a card, Escape puts them all back, as on the table.
class Screen:
	extends Control
	var held: Array[int] = []

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if not key or not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			held.clear()
		elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
			held.append(key.keycode - KEY_1)


var _screen: Screen
var _cog: SettingsCog
var _sheet: SettingsSheet


func _give(event: InputEventKey) -> void:
	if SettingsSheet.is_open():
		_sheet._input(event) # every key pressed is the open sheet's
	elif not _cog.take_key(event):
		_screen._unhandled_input(event)


func _press(code: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = pressed
		_give(key)


func test_f2_opens_the_sheet_and_escape_closes_it_with_the_cards_still_held() -> void:
	_screen = Screen.new()
	_cog = SettingsCog.add_to(_screen, Palette.CHALK)
	_cog.opened.connect(func(sheet: SettingsSheet) -> void: _sheet = sheet)
	_press(KEY_1)
	_press(KEY_2)
	eq(_screen.held, [0, 1] as Array[int], "two cards are held")
	ok(not SettingsSheet.is_open(), "no sheet at first")
	_press(KEY_F2)
	ok(SettingsSheet.is_open(), "F2 opens the sheet")
	ok(_sheet != null and _sheet.get_parent() == _screen, "over the screen")
	_press(KEY_3)
	_press(KEY_ESCAPE)
	ok(not SettingsSheet.is_open(), "Escape closes it")
	eq(_screen.held, [0, 1] as Array[int], "and the cards are held as they were")
	_press(KEY_ESCAPE)
	ok(_screen.held.is_empty(), "with the sheet closed, Escape puts the cards back")
	_cog.pressed.emit()
	ok(SettingsSheet.is_open(), "a click on the cog opens the sheet")
	ok(_cog.open_sheet() == null, "and no second one over it")
	_press(KEY_ESCAPE)
	ok(not SettingsSheet.is_open(), "Escape closes that one too")
	_screen.free()
