class_name ArenaMomentSalt
## A dose of salt: one paper is opened and spent; the stored restraint, if any, is lost; the
## page shifts back to Jekyll, the Factors turn to his faces; and Jekyll brings two Roots.


static func add(t: ArenaTable, result: Dictionary) -> void:
	t.beats.add(func() -> void:
		t.shown.add("salt/doses", -1)
		await t.play(t.means.open_paper))
	for e: Dictionary in result.events:
		if e.t == "shift":
			if int(e.ev.lost_stored) > 0:
				t.beats.add(func() -> void:
					t.stage.show_caption("The stored restraint is lost.")
					t.mark("restraint/stored", 0)
					await t.stage.clear_caption())
			t.beats.add_call(func() -> void:
				if int(t.shown.value("restraint/meter", 0)) != 0:
					t.mark("restraint/meter", 0))
			ArenaMomentShift.page(t, false)
		elif not ArenaMomentShift.add_event(t, e):
			t.unhandled = true
	ArenaMomentShift.means(t)
