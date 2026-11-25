extends CanvasLayer
## A small panel of performance figures over the game, for finding what is slow: frames and
## sound. Loaded with the game (an autoload, `Perf`), but it does nothing unless it is asked
## for:
##
##   a debug build:   F3 shows and hides it
##   the command line: `-- --perf` shows it from the start
##   the Web build:    add `?perf` to the address (http://localhost:8060/?perf)
##
## Frames: the rate, and how long a frame takes on average and at worst over the last
## seconds. A "hitch" is a frame longer than HITCH_MS. On Web the game has one thread and
## mixes the sound on it, so a frame longer than the sound's buffer is heard as a crackle:
## those frames are counted as "sound at risk".
##
## Sound: how many voices play (the one-shot sounds, the loops, the music), the output's
## delay and rate, and how the Web build plays audio.

## Seconds of frames the figures are taken over.
const WINDOW := 3.0
## A frame longer than this many milliseconds is a hitch (two frames at 60 a second).
const HITCH_MS := 34.0
## How often the words are written again, in seconds.
const REFRESH := 0.25

var _label: Label
var _frames: Array[float] = [] # each frame's length in ms, the newest last
var _span := 0.0
var _since := 0.0
var _hitches := 0
var _risky := 0
var _on := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var asked := Shot.has_arg("perf") or _asked_on_web()
	if not asked and not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.NIGHT_1, 0.85)
	box.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(8.0, 8.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Palette.CHALK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)
	add_child(panel)
	_show(asked)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		_show(not _on)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _on:
		return
	var ms := delta * 1000.0
	_frames.append(ms)
	_span += delta
	while _span > WINDOW and _frames.size() > 1:
		_span -= _frames.pop_front() / 1000.0
	if ms > HITCH_MS:
		_hitches += 1
	if ms > _buffer_ms():
		_risky += 1
	_since += delta
	if _since >= REFRESH:
		_since = 0.0
		_label.text = _words()


func _show(on: bool) -> void:
	_on = on
	visible = on
	_frames.clear()
	_span = 0.0
	_hitches = 0
	_risky = 0


# The Web build was opened with `perf` in its address.
func _asked_on_web() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("window.location.search", true)).contains("perf")


# The length of sound the output holds ahead, in milliseconds: a frame longer than this
# leaves it empty.
func _buffer_ms() -> float:
	return maxf(AudioServer.get_output_latency() * 1000.0, HITCH_MS)


func _words() -> String:
	var worst := 0.0
	var sum := 0.0
	for ms in _frames:
		worst = maxf(worst, ms)
		sum += ms
	var mean := sum / maxf(1.0, _frames.size())
	var lines: Array[String] = []
	lines.append("FRAMES  %d fps" % Engine.get_frames_per_second())
	lines.append("  frame %.1f ms mean, %.1f worst (last %d s)" % [mean, worst, int(WINDOW)])
	lines.append("  script %.1f ms   draw calls %d   nodes %d" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	lines.append("  hitches over %d ms: %d   memory %.0f MB" % [
		int(HITCH_MS), _hitches, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	var sounds := _playing(get_node_or_null("/root/Sfx"))
	var music := _playing(get_node_or_null("/root/Music"))
	lines.append("SOUND   %d sounds, %d music loops playing" % [sounds, music])
	lines.append("  output delay %.0f ms at %d Hz" % [
		AudioServer.get_output_latency() * 1000.0, int(AudioServer.get_mix_rate())])
	lines.append("  frames longer than the buffer (sound at risk): %d" % _risky)
	if OS.has_feature("web"):
		var kind: int = ProjectSettings.get_setting("audio/general/default_playback_type.web", 1)
		lines.append("  Web playback: %s, %s" % [
			"streams" if kind == 0 else "samples",
			"threads" if OS.has_feature("threads") else "one thread"])
	lines.append("F3 hides this; shown again, the counts start over.")
	return "\n".join(lines)


# How many of a node's players are sounding now.
func _playing(holder: Node) -> int:
	var count := 0
	if holder:
		for child in holder.get_children():
			var player := child as AudioStreamPlayer
			if player and player.playing and not player.stream_paused:
				count += 1
	return count
