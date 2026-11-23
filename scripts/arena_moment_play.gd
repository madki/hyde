class_name ArenaMomentPlay
## A play. For now only its cards are shown: they leave the hand for the discards while a
## play is taken off the tally, and the hand refills. The score and what the play does are
## not yet performed: the table takes them from the engine at the end of the move.


static func add(t: ArenaTable, result: Dictionary) -> void:
	var events: Array = result.events
	var ends := events.any(func(e: Dictionary) -> bool: return e.t == "round_end")
	for e: Dictionary in events:
		match e.t:
			"discarded":
				t.beats.add_call(func() -> void: t.mark("plays", t.after.plays))
				ArenaMomentCards.leave(t, e.ids)
			"drawn", "reshuffle":
				# A play that ends the round is not refilled: the cards go back to the deck.
				if not ends:
					ArenaMomentCards.add_event(t, e)
			_:
				t.unhandled = true
