extends Node
## The player's settings, kept between sittings. Loaded with the game (an autoload, `Settings`),
## before Sfx and Music:
##
##   Settings.set_music(40)            # the Music bus at 40 of 100; 0 mutes it
##   Settings.set_effects(0)           # the Effects bus (Sfx's voices) silent
##   Settings.set_full_screen(true)    # on the Web, only from a click
##   Settings.set_reduce_flashes(true) # ArenaPace.reduce_flashes
##
## Each set_* applies at once, writes `path` and emits `changed`. The file is read once, when
## the game starts; a missing or unreadable one means the defaults. When the bench drives the
## game from the command line (shot, keys, quit, selftest), nothing is read or written: the
## defaults hold, as with ArenaFirsts.

## A setting has changed.
signal changed

## The buses the two levels are set on. Music makes its own; Sfx makes Effects.
const MUSIC_BUS := "Music"
const EFFECTS_BUS := "Effects"

## Where the settings are kept.
static var path := "user://settings.cfg"

## The music's level and the sounds' level, 0 (silent) to 100 (as made).
var music := 100
var effects := 100
## The window fills the screen.
var full_screen := false
## Flares become plain changes, and nothing shakes.
var reduce_flashes := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	full_screen = _window_full()
	if not _driven():
		read_file()
	ArenaPace.reduce_flashes = reduce_flashes
	# On the Web a window is let fill the screen only from a click: there it is read, not set.
	if not OS.has_feature("web") and full_screen != _window_full():
		_apply_window()
	# The buses are made by Sfx and Music, which are ready after this one.
	apply_sound.call_deferred()


func set_music(v: int) -> void:
	music = clampi(v, 0, 100)
	apply_sound()
	_kept()


func set_effects(v: int) -> void:
	effects = clampi(v, 0, 100)
	apply_sound()
	_kept()


func set_full_screen(on: bool) -> void:
	full_screen = on
	_apply_window()
	_kept()


func set_reduce_flashes(on: bool) -> void:
	reduce_flashes = on
	ArenaPace.reduce_flashes = on
	_kept()


## Reads `path` into the settings. What is missing from it, or a file that cannot be read,
## leaves the setting as it is.
func read_file() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	music = clampi(int(file.get_value("sound", "music", music)), 0, 100)
	effects = clampi(int(file.get_value("sound", "effects", effects)), 0, 100)
	full_screen = bool(file.get_value("picture", "full_screen", full_screen))
	reduce_flashes = bool(file.get_value("picture", "reduce_flashes", reduce_flashes))


## Writes the settings to `path`. Not when the bench drives the game.
func write_file() -> void:
	if _driven():
		return
	var file := ConfigFile.new()
	file.set_value("sound", "music", music)
	file.set_value("sound", "effects", effects)
	file.set_value("picture", "full_screen", full_screen)
	file.set_value("picture", "reduce_flashes", reduce_flashes)
	file.save(path)


## Sets the Music and Effects buses to the two levels. A bus not made yet is left alone.
func apply_sound() -> void:
	set_bus_level(MUSIC_BUS, music)
	set_bus_level(EFFECTS_BUS, effects)


## Sets the bus `bus_name` to `level` of 100: 0 mutes it.
static func set_bus_level(bus_name: String, level: int) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, level <= 0)
	AudioServer.set_bus_volume_db(index, level_db(level))


## The bus volume, in dB, for `level` of 100. 0 is the quietest the bus has; the mute is what
## silences it.
static func level_db(level: int) -> float:
	return linear_to_db(clampf(level / 100.0, 0.0001, 1.0))


func _kept() -> void:
	write_file()
	changed.emit()


func _apply_window() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full_screen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


static func _window_full() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# True when the bench drives the game from the command line: nothing kept is read or changed.
static func _driven() -> bool:
	for name: String in ["shot", "keys", "quit", "selftest"]:
		if Shot.has_arg(name):
			return true
	return false
