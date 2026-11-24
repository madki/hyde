extends Node
## The game's sounds. Loaded with the game (an autoload, `Sfx`), so any screen can call it:
##
##   Sfx.play("lay")                       # as recorded
##   Sfx.play("draw_1", Sfx.vary(), 0.6)   # a little off pitch each time, and quieter
##   Sfx.play_sided("chips", Sfx.semitones(step))  # chips_j or chips_h, by who has the table
##
## A sound is a file `res://audio/sfx/<name>.ogg`. `pitch` is a rate (1 as recorded, 2 an
## octave up) and `volume` is linear (1 as recorded, 0 silent). A name with no file plays
## nothing and is reported once. A sound the table plays during a move goes through
## ArenaBeats.sound instead, which stays silent while the move is skipped.

const DIR := "res://audio/sfx/"
## Every sound there is: all are loaded with the game, so that none stalls its first play.
const NAMES: Array[String] = [
	"hover_j", "hover_h", "choose_j", "choose_h", "put_back_j", "put_back_h",
	"draw_1", "draw_2", "draw_3", "lay", "button", "refuse",
	"chips_j", "chips_h", "mult_j", "mult_h", "bloom_j", "bloom_h",
	"heartbeat", "shift_to_hyde", "breakout", "hyde_card_whisper", "hyde_card_wail",
	"hand_j_1", "hand_j_2", "hand_j_3", "hand_h_1", "hand_h_2", "hand_h_3",
	"round_won", "run_lost",
]
## How many sounds can be heard at once; one more cuts the oldest short.
const VOICES := 12

## Who has the table, for `play_sided`: Hyde (the `_h` sounds) or Jekyll (the `_j` ones).
var hyde := false

var _streams: Dictionary[String, AudioStream] = {}
var _missing: Dictionary[String, bool] = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _loops: Dictionary[String, AudioStreamPlayer] = {}


func _ready() -> void:
	# Sounds go on while the tree is paused, as the beat queue does.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in NAMES:
		var path := DIR + sound + ".ogg"
		if ResourceLoader.exists(path):
			_streams[sound] = load(path) as AudioStream
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)


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
		add_child(voice)
		voice.finished.connect(voice.play) # the file itself need not be set to loop
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
	_loops.erase(sound)
	voice.finished.disconnect(voice.play)
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
	for voice in _voices:
		voice.stop()


## A rate a little off 1, at most `amount` either way: a sound heard many times in a row
## should not be the same each time.
func vary(amount: float = 0.06) -> float:
	return 1.0 + randf_range(-amount, amount)


## The rate that raises a sound by `steps` semitones (lowers it, below 0).
func semitones(steps: float) -> float:
	return pow(2.0, steps / 12.0)


func _stream(sound: String) -> AudioStream:
	var stream: AudioStream = _streams.get(sound)
	if not stream and not _missing.has(sound):
		_missing[sound] = true
		push_warning("Sfx: there is no sound \"%s\" in %s." % [sound, DIR])
	return stream


func _tune(voice: AudioStreamPlayer, stream: AudioStream, pitch: float, volume: float) -> void:
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
