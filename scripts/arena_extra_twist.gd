class_name ArenaExtraTwist
## The scene's twist stated in its zone (ArenaTwist): named from the night's first round, in
## full for the whole of the scene, and pulsed once as the scene's round begins. Each part that
## shows a twist at work says so by its own `twist_acted`, and the block pulses with it: the
## hunted hand named, the tight scene's shorter track, a press on the forbidden flask or salt.


static func setup(t: ArenaTable) -> void:
	var twist := ArenaTwist.new()
	t.arena.add_child(twist)
	var tight := func() -> void:
		var night: Dictionary = RulesView.table(t.run).night
		var drop := 0
		if night.twist == "tight":
			drop = Rules.limit_for(t.run, false) - Rules.limit_for(t.run, true)
		t.numbers.restraint.show_tight(drop, night.scene)
	t.move_begun.connect(func(move: String) -> void:
		var night: Dictionary = RulesView.table(t.run).night
		twist.show_night(night)
		tight.call()
		if move == "round" and night.scene:
			twist.pulse())
	t.synced.connect(func(table: Dictionary) -> void:
		twist.show_night(table.night)
		tight.call())
	for part: Object in [t.numbers, t.numbers.restraint, t.means]:
		part.connect("twist_acted", twist.pulse)
