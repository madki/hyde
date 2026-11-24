class_name ArenaExtraViews
## Views on demand (ArenaViews): every number on a held Shift, the two edge tabs, the
## restraint under the pointer, a pile's cards on a click of it, the Notebook's three cards,
## and night 1's hint.


static func setup(t: ArenaTable) -> void:
	var views := ArenaViews.new()
	t.arena.add_child(views)
	views.bind(t)
