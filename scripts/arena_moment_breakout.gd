class_name ArenaMomentBreakout
## He breaks out, from the engine's `breakout` event: after a play of Jekyll's that fills the
## restraint track, or before a round's first play when Jekyll walks in with the track full.
##
## 1. The ink stands at the HYDE! end of the track: a short hold, in which the track's last
##    step and the word HYDE! tremble harder and harder.
## 2. The ink bursts from the track across the page (ArenaBurst). As it covers the page the
##    blow lands, heavy, and the page is his: the Factors in the hand turn to his faces, one
##    after another. "He breaks out." is written across the page in his hand.
## 3. The track is wiped clean, and nothing is stored: no drop settles by the mult. This, and
##    where the ink comes from, tell a breakout from a drink.
##
## With "reduce flashes" on nothing trembles or shakes. A move played back at once shows
## none of the staging.
##
## His Roots that join and the two he brings follow from their own events
## (ArenaMomentShift), and the round's end, if the play won it, from its own (ArenaMomentEnd).

const HOLD := 0.45


static func add(t: ArenaTable, _e: Dictionary) -> void:
	t.beats.add(func() -> void:
		if ArenaMomentShift.staged(t) and not ArenaPace.reduce_flashes:
			t.follow(t.numbers.restraint.tremble_over(HOLD))
		await t.beats.wait(HOLD))
	t.beats.add(func() -> void:
		# Its impact lands as the burst covers the page.
		t.beats.sound("breakout")
		var burst := ArenaBurst.new()
		t.arena.add_child(burst)
		t.arena.move_child(burst, t.numbers.get_index())
		await burst.play(t.beats, t.numbers.restraint.end_place(), func() -> void:
			t.shown.set_value("stance", "hyde")
			t.ink.is_jekyll = false
			t.ink.snap_to_stance()
			t.numbers.is_jekyll = false
			t.numbers.restraint.still()
			var gap := ArenaMomentShift.TURN_GAP if ArenaMomentShift.staged(t) else 0.0
			t.follow(t.hand.turn_to(t.entry, true, gap))
			t.mark("restraint/meter", 0)
			ArenaMomentShift.name_across(t, "He breaks out.", true))
		burst.queue_free())
	# The words stay while the ink thins away, and a little longer.
	t.beats.add_wait(ArenaMomentShift.NAME_TIME + ArenaMomentShift.NAME_FADE_WAIT - ArenaBurst.THIN_TIME)
