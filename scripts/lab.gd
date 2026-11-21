extends Control
## The laboratory: Jekyll's table, window and chair, bottom left. The rest of the screen is
## kept clear for a menu.


func _ready() -> void:
	Shot.run_if_requested(self)
