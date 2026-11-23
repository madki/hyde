class_name ArenaMomentBreakout
## He breaks out, from the engine's `breakout` event: after a play of Jekyll's that fills the
## restraint track, or before a round's first play when Jekyll walks in with the track full.
##
## 1. The ink stands at the HYDE! end of the track: a short hold.
## 2. The ink bursts from the track across the page (ArenaBurst), and the page is his: the
##    Factors in the hand turn to his faces. Caption: "He breaks out."
## 3. The track is wiped clean, and nothing is stored: no drop settles by the mult. This, and
##    where the ink comes from, tell a breakout from a drink.
##
## His Roots that join and the two he brings follow from their own events
## (ArenaMomentShift), and the round's end, if the play won it, from its own (ArenaMomentEnd).

const HOLD := 0.45


static func add(t: ArenaTable, _e: Dictionary) -> void:
	t.beats.add_wait(HOLD)
	t.beats.add(func() -> void:
		t.stage.show_caption("He breaks out.")
		var burst := ArenaBurst.new()
		t.arena.add_child(burst)
		t.arena.move_child(burst, t.column.get_index())
		await burst.play(t.beats, t.column.restraint.end_place(), func() -> void:
			t.shown.set_value("stance", "hyde")
			t.ink.is_jekyll = false
			t.ink.snap_to_stance()
			t.column.is_jekyll = false
			t.hand.turn_to(t.entry, true)
			t.mark("restraint/meter", 0))
		burst.queue_free())
	t.beats.add(func() -> void: await t.stage.clear_caption())
