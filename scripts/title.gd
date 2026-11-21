extends Control
## The title screen: the street, with Jekyll waiting in it. Shift changes him into Hyde, and
## Hyde back into him, through the dark.
## For screenshots: `--shift=1` starts on Hyde, `--lamps=0.3` and `--dark=0.5` show a moment of
## the change. In debug builds F shows sliders for the fog (scripts/fog_panel.gd).

@onready var _bg: TitleBackground = $Background


func _ready() -> void:
	if Shot.has_arg("shift"):
		_bg.shift = float(Shot.arg("shift"))
	if Shot.has_arg("lamps"):
		_bg.lamps = float(Shot.arg("lamps"))
	if Shot.has_arg("dark"):
		_bg.darkness = float(Shot.arg("dark"))
	Shot.run_if_requested(self)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_SHIFT:
		_bg.change_to(0.0 if _bg.shift > 0.5 else 1.0)
