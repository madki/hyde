extends Control
## The back alley, where a run comes at dawn when Hyde has the table: Hyde letting himself in
## by the door, bottom right, and a panel in the clear of the street. For now the panel holds
## one row, Leave, which goes back to the table; there the next night begins.
##
## Run on its own (a still, or from the editor) it shows a run played to a dawn of its own:
## `tools/shot.sh /abs/out.png res://scenes/alley.tscn --seed=3` (see SceneFlow.run_for_place).

const WHERE := "alley"
const HEADING := "The Back Alley"
const ROW_LEAVE := "Leave"

## The run at this dawn. Null only if no run could be played to one.
var _run: RulesRun

@onready var _panel: PlacePanel = $Panel


func _ready() -> void:
	_run = SceneFlow.run_for_place(WHERE)
	_panel.accent = Palette.HYDE
	_panel.set_heading(HEADING)
	_panel.set_rows([{text = ROW_LEAVE}])
	if _run != null:
		_panel.note = "Dawn %d" % int(_run.dawn.no)
	_panel.row_chosen.connect(_on_row_chosen)
	Shot.run_if_requested(self)


func _on_row_chosen(_index: int) -> void:
	SceneFlow.back_to_table()
