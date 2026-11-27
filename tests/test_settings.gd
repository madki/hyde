extends "res://tests/case.gd"
## The kept settings: the file, the defaults, and the two buses they set.

const SETTINGS := preload("res://scripts/settings.gd")


# Runs `body` with a fresh settings node whose file is a scratch one, then removes the file.
func _with_file(body: Callable) -> void:
	var kept: String = SETTINGS.path
	SETTINGS.path = "user://test_settings_%d.cfg" % Time.get_ticks_usec()
	var flashes := ArenaPace.reduce_flashes
	var s: Node = SETTINGS.new()
	body.call(s)
	s.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS.path))
	SETTINGS.path = kept
	ArenaPace.reduce_flashes = flashes


# Runs `body` with the Music and Effects buses there, making those that are not.
func _with_buses(body: Callable) -> void:
	var made: Array[String] = []
	for bus: String in [SETTINGS.MUSIC_BUS, SETTINGS.EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			made.append(bus)
	body.call()
	for bus in made:
		AudioServer.remove_bus(AudioServer.get_bus_index(bus))


func test_the_settings_are_kept_and_read_back() -> void:
	_with_file(func(s: Node) -> void:
		s.set_music(30)
		s.set_effects(70)
		s.set_reduce_flashes(true)
		s.full_screen = true
		s.write_file()
		ok(FileAccess.file_exists(SETTINGS.path), "the settings are written down")
		var again: Node = SETTINGS.new()
		again.read_file()
		eq(again.music, 30, "music read back")
		eq(again.effects, 70, "effects read back")
		eq(again.full_screen, true, "full screen read back")
		eq(again.reduce_flashes, true, "reduce flashes read back")
		again.free()
	)


func test_a_missing_or_bad_file_means_the_defaults() -> void:
	_with_file(func(s: Node) -> void:
		s.read_file()
		eq([s.music, s.effects, s.reduce_flashes], [100, 100, false], "no file: the defaults")
		var f := FileAccess.open(SETTINGS.path, FileAccess.WRITE)
		f.store_string("this is [not a settings file = \n")
		f.close()
		var bad: Node = SETTINGS.new()
		bad.read_file()
		eq([bad.music, bad.effects, bad.full_screen, bad.reduce_flashes], [100, 100, false, false], "a bad file: the defaults")
		bad.free()
	)


func test_a_change_is_signalled_and_levels_are_held_in_range() -> void:
	_with_file(func(s: Node) -> void:
		var count := [0]
		s.changed.connect(func() -> void: count[0] += 1)
		s.set_music(140)
		s.set_effects(-5)
		eq([s.music, s.effects], [100, 0], "levels held to 0..100")
		eq(count[0], 2, "each change is signalled")
	)


func test_reduce_flashes_sets_the_pace() -> void:
	_with_file(func(s: Node) -> void:
		s.set_reduce_flashes(true)
		ok(ArenaPace.reduce_flashes, "on")
		s.set_reduce_flashes(false)
		ok(not ArenaPace.reduce_flashes, "off")
	)


func test_music_and_effects_are_two_buses_and_0_mutes() -> void:
	_with_buses(func() -> void:
		_with_file(func(s: Node) -> void:
			var music := AudioServer.get_bus_index(SETTINGS.MUSIC_BUS)
			var effects := AudioServer.get_bus_index(SETTINGS.EFFECTS_BUS)
			ok(music != effects, "two buses")
			s.set_music(0)
			s.set_effects(50)
			ok(AudioServer.is_bus_mute(music), "music at 0 is muted")
			ok(not AudioServer.is_bus_mute(effects), "effects at 50 is heard")
			ok(absf(AudioServer.get_bus_volume_db(effects) - linear_to_db(0.5)) < 0.01, "effects at half")
			s.set_music(100)
			s.set_effects(0)
			ok(not AudioServer.is_bus_mute(music), "music at 100 is heard")
			ok(absf(AudioServer.get_bus_volume_db(music)) < 0.01, "music as made")
			ok(AudioServer.is_bus_mute(effects), "effects at 0 is muted")
		)
	)


func test_the_sounds_play_on_the_effects_bus() -> void:
	var sfx: GDScript = load("res://scripts/sfx.gd")
	eq(sfx.BUS, SETTINGS.EFFECTS_BUS, "Sfx plays on the bus Settings sets")
