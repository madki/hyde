class_name ArenaExtraPreviews
## Before a drink or a dose of salt: while the pointer rests on a flask that can be drunk,
## the restraint on the track is outlined as the drops it would store beside the mult; on
## salt that can be taken, the stored drops are struck through, because they would be lost.
## Nothing asks "are you sure": the marks are the warning.


static func setup(t: ArenaTable) -> void:
	t.means.preview_changed.connect(func(kind: String) -> void:
		var restraint: Dictionary = t.after.get("restraint", {"meter": 0})
		t.column.preview_stored(int(restraint.meter) if kind == "drink" else 0, kind == "salt"))
	t.move_begun.connect(func(_move: String) -> void: t.column.preview_stored(0, false))
