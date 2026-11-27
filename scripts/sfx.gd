extends Node
## The game's sounds. Loaded with the game (an autoload, `Sfx`), so any screen can call it:
##
##   Sfx.play("lay")                       # as recorded
##   Sfx.play("draw_1", Sfx.vary(), 0.6)   # a little off pitch each time, and quieter
##   Sfx.play_sided("chips", Sfx.semitones(step))  # chips_j or chips_h, by who has the table
##
## A sound is a file `res://audio/sfx/<name>.ogg`. `pitch` is a rate (1 as recorded, 2 an
## octave up) and `volume` is linear (1 as recorded, 0 silent). A name in NAMES that has no
## file yet is silent: add the file and it plays. A name that is not in NAMES is reported once. A sound the table plays during a move goes through
## ArenaBeats.sound instead, which stays silent while the move is skipped.

const DIR := "res://audio/sfx/"
## Sounds made from licensed libraries are not in the repository: they are built into this
## folder, which is ignored by git. A sound found here is used in place of the one in DIR.
const LOCAL_DIR := "res://audio/sfx_local/"
## Every sound the game asks for: those that have a file are loaded with the game, so that
## none stalls its first play. Only the first three lines have a file in DIR; the rest are
## silent in a copy of the game that has no LOCAL_DIR.
const NAMES: Array[String] = [
	"hover_j", "hover_h", "choose_j", "choose_h", "put_back_j", "put_back_h",
	"draw_1", "draw_2", "draw_3", "lay", "button", "refuse",
	"chips_j", "chips_h", "mult_j", "mult_h", "bloom_j", "bloom_h", "pen",
	"heartbeat", "shift_to_hyde", "breakout", "hyde_card_whisper", "hyde_card_wail",
	"hand_j_1", "hand_j_2", "hand_j_3", "hand_h_1", "hand_h_2", "hand_h_3",
	"round_won", "run_lost",
	"title_visit", "shift_to_jekyll", "drink", "crack_ink", "crack_paper", "coin", "restraint_step",
	"restraint_threat", "tally", "count", "total", "target_struck", "heading", "shuffle", "riffle",
	"card_flip", "lock", "eye", "ink_drop", "rollover", "temper", "cork", "paper", "salt",
	"low_note", "warn", "rescue", "double", "line_holds", "line_floods", "run_end",
	"passage", "dawn_j", "dawn_h", "buy", "take", "amb_title",
	"crack_ink_2", "crack_ink_3", "breakout_build", "notice", "notice_go",
	"impact_1", "impact_2", "impact_3", "ink_surge", "pour",
]
## How many sounds can be heard at once; one more cuts the oldest short.
const VOICES := 16
## The bus every sound plays on, sent to Master: its level is the player's (Settings.effects).
const BUS := "Effects"

## A loop has begun again from its start: `sound` is its name. For what must keep time with it.
signal loop_restarted(sound: String)

## Who has the table, for `play_sided`: Hyde (the `_h` sounds) or Jekyll (the `_j` ones).
var hyde := false

var _streams: Dictionary[String, AudioStream] = {}
var _missing: Dictionary[String, bool] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _loops: Dictionary[String, AudioStreamPlayer] = {}
var _across: AudioStreamPlayer
# For `take`: by sound, which take was given last and when (milliseconds).
var _takes: Dictionary[String, Vector2i] = {}


func _ready() -> void:
	# Sounds go on while the tree is paused, as the beat queue does.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus()
	for sound in NAMES:
		for dir in [LOCAL_DIR, DIR]:
			var path: String = dir + sound + ".ogg"
			if ResourceLoader.exists(path):
				_streams[sound] = load(path) as AudioStream
				break
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS
		add_child(voice)
		_voices.append(voice)
	_across = AudioStreamPlayer.new()
	_across.bus = BUS
	add_child(_across)


## Plays `sound` once. Returns the player it is on (to stop it early, say), or null if there
## is no such sound.
func play(sound: String, pitch: float = 1.0, volume: float = 1.0) -> AudioStreamPlayer:
	var stream := _stream(sound)
	if not stream or volume <= 0.0:
		return null
	var voice := _free_voice()
	_tune(voice, stream, pitch, volume)
	voice.play()
	return voice


## Plays `sound` on a voice of its own, which `hush` and `stop_all` leave alone: for a sound
## that runs across a change of screen (the passage).
func play_across(sound: String, pitch: float = 1.0, volume: float = 1.0) -> void:
	var stream := _stream(sound)
	if stream:
		_tune(_across, stream, pitch, volume)
		_across.play()


## Plays Jekyll's or Hyde's version of `sound` (`<sound>_j` or `<sound>_h`), by `hyde`.
func play_sided(sound: String, pitch: float = 1.0, volume: float = 1.0) -> AudioStreamPlayer:
	return play(sided(sound), pitch, volume)


## The name of Jekyll's or Hyde's version of `sound`, by `hyde`.
func sided(sound: String) -> String:
	return sound + ("_h" if hyde else "_j")


## Plays `sound` over and over until `stop_loop`. Called again while it plays, it only sets
## the pitch and the volume.
func loop(sound: String, pitch: float = 1.0, volume: float = 1.0) -> void:
	var stream := _stream(sound)
	if not stream:
		return
	var voice: AudioStreamPlayer = _loops.get(sound)
	if not voice:
		voice = AudioStreamPlayer.new()
		voice.bus = BUS
		add_child(voice)
		voice.finished.connect(_restart.bind(sound, voice)) # the file itself need not be set to loop
		_loops[sound] = voice
		_tune(voice, stream, pitch, volume)
		voice.play()
	else:
		_tune(voice, stream, pitch, volume)


## True while `sound` is looping.
func is_looping(sound: String) -> bool:
	return _loops.has(sound)


## Ends a loop, fading it out over `fade` seconds. Nothing happens if it is not playing.
func stop_loop(sound: String, fade: float = 0.3) -> void:
	var voice: AudioStreamPlayer = _loops.get(sound)
	if not voice:
		return
	_loops.erase(sound) # so it is not begun again: see `_restart`
	if fade <= 0.0:
		voice.queue_free()
		return
	var tween := voice.create_tween()
	tween.tween_property(voice, "volume_db", -60.0, fade)
	tween.tween_callback(voice.queue_free)


## Ends every loop and every sound at once: for leaving a screen.
func stop_all() -> void:
	for sound: String in _loops.keys():
		stop_loop(sound, 0.0)
	hush()


## Cuts short every sound that is playing once (the loops go on): a move is being skipped.
func hush() -> void:
	for voice in _voices:
		voice.stop()


## The name of the take of `sound` to play now, of its `count` takes (`<sound>`, `<sound>_2`,
## `<sound>_3`...): the first, or the one after the last given when that was no more than
## `within` seconds ago, so that the same sound several times in a row is not one sound
## repeated. After the last take comes the first again.
func take(sound: String, count: int, within: float = 4.0) -> String:
	var now := Time.get_ticks_msec()
	var last: Vector2i = _takes.get(sound, Vector2i(-1, 0))
	var index := 0
	if last.x >= 0 and now - last.y <= int(within * 1000.0):
		index = (last.x + 1) % maxi(count, 1)
	_takes[sound] = Vector2i(index, now)
	return sound if index == 0 else "%s_%d" % [sound, index + 1]


## A rate a little off 1, at most `amount` either way: a sound heard many times in a row
## should not be the same each time.
func vary(amount: float = 0.06) -> float:
	return 1.0 + randf_range(-amount, amount)


## The rate that raises a sound by `steps` semitones (lowers it, below 0).
func semitones(steps: float) -> float:
	return pow(2.0, steps / 12.0)


func _stream(sound: String) -> AudioStream:
	var stream: AudioStream = _streams.get(sound)
	if not stream and not sound in NAMES and not _missing.has(sound):
		_missing[sound] = true
		push_warning("Sfx: there is no sound \"%s\" in %s." % [sound, DIR])
	return stream


# Begins a loop's voice again when it has reached its end, unless the loop has been stopped.
func _restart(sound: String, voice: AudioStreamPlayer) -> void:
	if _loops.get(sound) != voice:
		return
	voice.play()
	loop_restarted.emit(sound)


func _tune(voice: AudioStreamPlayer, stream: AudioStream, pitch: float, volume: float) -> void:
	# A player given its stream again stops: a loop tuned while it plays keeps the one it has.
	if voice.stream != stream:
		voice.stream = stream
	voice.pitch_scale = clampf(pitch, 0.1, 4.0)
	voice.volume_db = linear_to_db(clampf(volume, 0.0001, 2.0))


# A voice that is silent, or else the one that began longest ago.
func _free_voice() -> AudioStreamPlayer:
	for i in VOICES:
		var voice := _voices[(_next + i) % VOICES]
		if not voice.playing:
			_next = (_next + i + 1) % VOICES
			return voice
	var oldest := _voices[_next]
	_next = (_next + 1) % VOICES
	return oldest


func _make_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, "Master")
