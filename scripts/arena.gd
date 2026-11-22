extends Control
## The arena, where every round is played: a page of Dr Jekyll's night journal. For now only
## the page itself, as it looks while Jekyll has the table: the paper and its ruled border.


func _ready() -> void:
	Shot.run_if_requested(self)
