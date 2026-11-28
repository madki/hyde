extends "res://tests/case.gd"
## Every card's picture, on both sides, is a drawing.


func test_every_root_and_factor_has_a_drawing_on_both_sides() -> void:
	var keys: Array[String] = []
	keys.append_array(RulesConfig.ROOTS)
	keys.append_array(RulesConfig.FACTORS)
	for key: String in keys:
		for ink: bool in [false, true]:
			var picture := ArenaCardPictures.picture_of(key, ink)
			ok(picture != "", "%s (%s) has a picture" % [key, "ink" if ink else "paper"])
			ok(ArenaCardPictures.drawing(picture) != null, "%s (%s): '%s' is a drawing" % [key,
					"ink" if ink else "paper", picture])
