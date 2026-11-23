class_name ArenaMomentDiscard
## A discard, the quickest move on the table: the chosen cards travel to the discards while a
## discard is taken off the tally, and the hand closes up and refills from the draw pile (the
## discards turning over into a new draw pile first if it has run out). No caption.


static func add(t: ArenaTable, result: Dictionary) -> void:
	for e: Dictionary in result.events:
		if e.t == "discarded":
			t.beats.add_call(func() -> void: t.mark("discards", t.after.discards))
		if not ArenaMomentCards.add_event(t, e):
			t.unhandled = true
