class_name ArenaExtraViews
## Views on demand (ArenaViews): every number on a held Tab, the night and the restraint
## under the pointer, the deck on a click of the draw pile, the Notebook's three cards, and
## night 1's hint.


static func setup(t: ArenaTable) -> void:
	var views := ArenaViews.new()
	t.arena.add_child(views)
	views.bind(t)
