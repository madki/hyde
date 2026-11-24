class_name ArenaMomentDrink
## A drink: the flask tips and empties; the ink on the restraint track becomes stored drops;
## the page shifts to Hyde; on his first arrival his four Roots join the deck, on any later
## drink a Paper Root is stained (or an Ink Root joins when none is left); he brings two
## Roots; and the flask's tag names the next drink's cost.


static func add(t: ArenaTable, result: Dictionary) -> void:
	for e: Dictionary in result.events:
		if e.t == "shift":
			# The page shifts once the flask has tipped and the track has been stored.
			ArenaMomentShift.cue_to_hyde(t, ArenaMeans.TIP_TIME + int(e.ev.stored) * ArenaMomentShift.STORE_STEP)
	t.beats.add(func() -> void:
		t.play_means(t.means.tip_flask)
		await t.beats.wait(ArenaMeans.TIP_TIME))
	for e: Dictionary in result.events:
		if e.t == "shift":
			ArenaMomentShift.store(t, e.ev.stored)
			ArenaMomentShift.page(t, true)
		elif not ArenaMomentShift.add_event(t, e):
			t.unhandled = true
	ArenaMomentShift.means(t)
