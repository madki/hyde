extends Node
## The order of the game's screens. Enter goes on to the next one, and from the last back to
## the first. Loaded with the game (an autoload), so it works whichever screen is run.

const SCENES: Array[String] = [
	"res://scenes/title.tscn",
	"res://scenes/arena.tscn",
	"res://scenes/alley.tscn",
	"res://scenes/lab.tscn",
]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or key.echo or not key.pressed:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		next()


## Goes to the screen after the one that is showing. A screen that is not in the list goes to
## the first, unless it is one of the studio's: Enter must not cut a bake short.
func next() -> void:
	var current := get_tree().current_scene
	if not current: # a change of screen is already under way
		return
	var at := SCENES.find(current.scene_file_path)
	if at == -1 and current.scene_file_path.begins_with("res://studio/"):
		return
	get_tree().change_scene_to_file(SCENES[(at + 1) % SCENES.size()])
