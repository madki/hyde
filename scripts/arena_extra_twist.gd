class_name ArenaExtraTwist
## The scene's twist stated in its zone (ArenaTwist): named from the night's first round, in
## full for the whole of the scene, and pulsed once as the scene's round begins.


static func setup(t: ArenaTable) -> void:
	var twist := ArenaTwist.new()
	t.arena.add_child(twist)
	t.move_begun.connect(func(move: String) -> void:
		var night: Dictionary = RulesView.table(t.run).night
		twist.show_night(night)
		if move == "round" and night.scene:
			twist.pulse())
	t.synced.connect(func(table: Dictionary) -> void:
		twist.show_night(table.night))
