class_name Shot
## Screenshot hook shared by every screen, used to check the look from the command line:
##
##   godot --path . -- --shot=/abs/path.png [--fullscreen]
##
## renders a few frames, saves a screenshot and quits. Each screen calls
## `Shot.run_if_requested(self)` at the end of its `_ready`. `arg` / `has_arg` also read any
## other `--name=value` user argument a screen wants to take (seed, level, actions, ...).


## Value of a `--name=value` user argument, "" if absent (or given without a value).
static func arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.trim_prefix("--" + name + "=")
	return ""


static func has_arg(name: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name or a.begins_with("--" + name + "="):
			return true
	return false


## Call from a screen's _ready.
static func run_if_requested(screen: Node) -> void:
	var path := arg("shot")
	if path:
		_take(screen, path)


static func _take(screen: Node, path: String) -> void:
	# Screenshots are taken windowed at the project's base size so they are always the same,
	# whatever window mode the project starts in.
	var window := screen.get_window()
	var shot_size := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	# Leaving full screen takes the OS a moment: keep asking until the window has settled.
	for i in 300:
		if has_arg("fullscreen"): # shoot the game as it starts on this display instead
			break
		if window.mode == Window.MODE_WINDOWED and window.size == shot_size:
			break
		window.mode = Window.MODE_WINDOWED
		window.size = shot_size
		await screen.get_tree().process_frame
	for i in 10:
		await screen.get_tree().process_frame
	await RenderingServer.frame_post_draw
	screen.get_viewport().get_texture().get_image().save_png(path)
	screen.get_tree().quit()
