extends Control
## The transformation: Jekyll turns to liquid, flows into Hyde's shape and sets, while the
## street's colours cross over. Space / click plays it, and plays it back the other way from Hyde.
## `--at=0.5` starts part-way through (for screenshots).

@onready var _bg: Background = $Background
@onready var _label: Label = $Label


func _ready() -> void:
	if Shot.has_arg("at"):
		_bg.transformation = float(Shot.arg("at"))
	Shot.run_if_requested(self)


func _process(_delta: float) -> void:
	_label.text = "transformation %.2f   (Space / click to play)" % _bg.transformation


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed
	if event.is_action_pressed("ui_accept") or click:
		_bg.transform_to(0.0 if _bg.transformation > 0.5 else 1.0)
