extends Node
## The game's music. Loaded with the game (an autoload, `Music`). Three loops, each a seamless
## loop of one piece in `res://audio/music/`:
##
##   jekyll: his table, the title and the laboratory
##   hyde:   his table and the back alley
##   dread:  a bed under both that rises with the danger
##
## A screen says where we are (`Music.enter("table")`); who has the table comes from
## `Sfx.hyde`, and the danger from `Music.set_dread(source, amount)`. The loops crossfade
## on their own and a loop that is faded out waits where it was, so it carries on from there.

## Where we are, and how loud each loop is there (dB, before the master level). Hyde's piece
## measures 3.6 dB quieter than Jekyll's and has more of its weight in the sub, which small
## speakers lose: it is played 2 dB up, so that his table does not sound smaller than Jekyll's.
const PLACES: Dictionary[String, Dictionary] = {
	"none": {jekyll = -80.0, hyde = -80.0},
	"title": {jekyll = 0.0, hyde = -80.0},
	"table": {jekyll = 0.0, hyde = 2.0},
	"lab": {jekyll = -3.0, hyde = -80.0},
	"alley": {jekyll = -80.0, hyde = -1.0},
}
## The level of all the music, under the sounds.
const MASTER_DB := -9.0
## The dread bed at full danger, and its lowest level while any danger is felt.
const DREAD_DB := -4.0
const SILENT_DB := -80.0
## How fast a level moves toward its target, in dB a second: a swap takes about a second.
const FADE_RATE := 60.0
## The loop's low-pass at full danger: the melody darkens as the line nears.
const DARKEST_HZ := 1400.0
const BUS := "Music"

var _place := "none"
var _dread: Dictionary[String, float] = {}
var _players: Dictionary[String, AudioStreamPlayer] = {}
var _level: Dictionary[String, float] = {}
var _filter: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus()
	for loop in ["jekyll", "hyde", "dread"]:
		var path := "res://audio/music/music_%s.ogg" % loop
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStreamOggVorbis
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players[loop] = player
		_level[loop] = SILENT_DB


## Says which screen the player is on: "title", "table", "lab", "alley" or "none" (silent).
## Leaving the table clears the danger.
func enter(place: String) -> void:
	assert(PLACES.has(place), "Music: no place \"%s\"." % place)
	_place = place
	if place != "table":
		_dread.clear()


## Sets how near the danger is, 0 to 1, from `source` (the restraint, the last play...).
## The loudest source is the one heard.
func set_dread(source: String, amount: float) -> void:
	_dread[source] = clampf(amount, 0.0, 1.0)


## The danger heard now, 0 to 1.
func dread() -> float:
	var most := 0.0
	for amount in _dread.values():
		most = maxf(most, amount)
	return most


func _process(delta: float) -> void:
	var target: Dictionary = PLACES[_place]
	var danger := dread()
	for loop in _players:
		var db := SILENT_DB
		if loop == "dread":
			if _place == "table" or _place == "lab" or _place == "alley":
				db = lerpf(-36.0, DREAD_DB, danger) if danger > 0.0 else SILENT_DB
		elif loop == "jekyll":
			db = target.jekyll if _place != "table" or not Sfx.hyde else SILENT_DB
			# Jekyll's piece sinks as the danger comes, so the dread has the room.
			db = db - 6.0 * danger if db > SILENT_DB else db
		else:
			db = target.hyde if _place != "table" or Sfx.hyde else SILENT_DB
		_level[loop] = move_toward(_level[loop], db, FADE_RATE * delta)
		_apply(_players[loop], _level[loop])
	_filter.cutoff_hz = lerpf(20500.0, DARKEST_HZ, danger * danger)


func _apply(player: AudioStreamPlayer, db: float) -> void:
	player.volume_db = db + MASTER_DB if db > SILENT_DB else SILENT_DB
	if db <= SILENT_DB + 0.5:
		# Faded out: wait where it is, and carry on from there.
		if player.playing:
			player.stream_paused = true
	elif not player.playing:
		player.play()
	elif player.stream_paused:
		player.stream_paused = false


func _make_bus() -> void:
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
	_filter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(index, _filter)
