class_name ArenaMomentPass
## A pass: nothing in the hand can be played and no discard is left. One beat, "Nothing to
## play.", in which a play is taken off the tally; then as Jekyll a step of the restraint
## track is inked. What may follow (the breakout, the win, the rescue) is as after any play.


static func add(t: ArenaTable, result: Dictionary) -> void:
	t.beats.add(func() -> void:
		t.stage.show_caption("Nothing to play.")
		t.mark("plays", t.after.plays)
		await t.stage.clear_caption())
	var rescue := {}
	for e: Dictionary in result.events:
		match e.t:
			"restraint":
				t.add_mark("restraint/meter", e.n)
			"breakout":
				ArenaMomentBreakout.add(t, e)
			"joined", "brought":
				# In a rescue his first four Roots join the gathered deck, at the round's end.
				if e.t == "joined" and rescue.has("last"):
					rescue.first = e
				else:
					ArenaMomentShift.add_event(t, e)
			"rescue", "converted":
				ArenaMomentRescue.add_event(t, e, rescue)
			"round_end":
				ArenaMomentEnd.add(t, e, rescue.get("first", {}))
			_:
				t.unhandled = true
