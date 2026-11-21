extends Control
## The back alley: Hyde letting himself in by the door, bottom right. The rest of the screen is
## kept clear for a menu.


func _ready() -> void:
	Shot.run_if_requested(self)
