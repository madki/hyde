extends Control
## Stand-alone viewer for the street background.
## Shift / click toggles between the two faces. `--shift=0.5` starts part-way (for screenshots).

@onready var _bg: Background = $Background
@onready var _label: Label = $Label


func _ready() -> void:
	if Shot.has_arg("shift"):
		_bg.shift = float(Shot.arg("shift"))
	Shot.run_if_requested(self)


func _process(_delta: float) -> void:
	var face := "JEKYLL" if _bg.shift < 0.5 else "HYDE"
	_label.text = "%s   shift %.2f   (Shift / click to shift)" % [face, _bg.shift]


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed
	var key := event as InputEventKey
	if (key and key.pressed and not key.echo and key.keycode == KEY_SHIFT) or click:
		_bg.shift_to(0.0 if _bg.shift > 0.5 else 1.0)
