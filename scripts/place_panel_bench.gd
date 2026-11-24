extends Control
## Shows the place panel on the alley's picture, with every kind of row, to check it in a
## still: `tools/shot.sh /abs/panel.png res://scenes/place_panel_bench.tscn`.
## `--jekyll` lights it with Jekyll's light instead of Hyde's.

@onready var _panel: PlacePanel = $Panel


func _ready() -> void:
	_panel.accent = Palette.JEKYLL if Shot.has_arg("jekyll") else Palette.HYDE
	_panel.set_heading("The back door")
	_panel.set_rows([
		{text = "Go in"},
		{text = "A bottle of salts", price = 4},
		{text = "Black tonic", price = 12, enabled = false},
		{text = "Ask about the doctor"},
		{text = "Back to the street"},
	])
	_panel.move_selection(1)
	_panel.note = "Up and Down to choose, Enter to take"
	_panel.row_chosen.connect(func(index: int) -> void: print("Chosen: ", index))
	Shot.run_if_requested(self)
