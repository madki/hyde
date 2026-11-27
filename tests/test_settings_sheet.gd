extends "res://tests/case.gd"
## The settings sheet: opened over a screen, worked by key, closed with Escape. The tests have
## no running tree, so the keys are given to the sheet's own input.

const SETTINGS := preload("res://scripts/settings.gd")


func _key(sheet: SettingsSheet, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	sheet._input(press)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	sheet._input(release)


func test_the_sheet_moves_a_slider_by_key_and_closes_with_escape() -> void:
	var kept: String = SETTINGS.path
	SETTINGS.path = "user://test_settings_sheet_%d.cfg" % Time.get_ticks_usec()
	var flashes := ArenaPace.reduce_flashes
	var settings: Node = SETTINGS.new()
	var screen := Control.new()
	var sheet := SettingsSheet.open(screen)
	sheet.settings = settings
	ok(SettingsSheet.is_open(), "the sheet is open")
	eq(sheet.selected(), SettingsSheet.Row.MUSIC, "it opens on Music")
	_key(sheet, KEY_LEFT)
	_key(sheet, KEY_LEFT)
	eq(settings.music, 80, "Left twice: Music down two steps")
	_key(sheet, KEY_RIGHT)
	eq(settings.music, 90, "Right: a step up")
	sheet.select(SettingsSheet.Row.EFFECTS)
	_key(sheet, KEY_RIGHT)
	eq(settings.effects, 100, "Effects is at the top already")
	_key(sheet, KEY_LEFT)
	eq(settings.effects, 90, "Left on Effects: a step down")
	sheet.select(SettingsSheet.Row.REDUCE_FLASHES)
	_key(sheet, KEY_ENTER)
	eq(settings.reduce_flashes, true, "Enter flips Reduce flashes")
	_key(sheet, KEY_RIGHT)
	eq(settings.reduce_flashes, false, "Right flips it back")
	var again: Node = SETTINGS.new()
	again.read_file()
	eq([again.music, again.effects, again.reduce_flashes], [90, 90, false], "each change kept at once")
	again.free()
	var closed := [false]
	sheet.closed.connect(func() -> void: closed[0] = true)
	_key(sheet, KEY_ESCAPE)
	ok(closed[0], "Escape closes the sheet")
	ok(not SettingsSheet.is_open(), "no sheet is open after")
	screen.free()
	settings.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS.path))
	SETTINGS.path = kept
	ArenaPace.reduce_flashes = flashes
