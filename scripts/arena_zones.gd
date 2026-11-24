class_name ArenaZones
extends Control
## The outlines of ArenaLayout's zones, each with its name, over the arena: for screenshots
## while the page is laid out (`--zones` on the arena's command line). Two zones that overlap
## are named in the output.

const COLOURS: Array[Color] = [Color(1.0, 0.85, 0.3), Color(0.45, 0.95, 1.0), Color(1.0, 0.55, 0.75),
		Color(0.6, 1.0, 0.55)]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var zones := ArenaLayout.zones(size)
	var font := get_theme_default_font()
	var names := zones.keys()
	for i in names.size():
		var rect: Rect2 = zones[names[i]]
		var colour := COLOURS[i % COLOURS.size()]
		draw_rect(rect, Color(colour, 0.1))
		draw_rect(rect, colour, false, 1.5)
		var at := rect.position + Vector2(4.0, 13.0)
		# A narrow zone has its name written down its length.
		if rect.size.x < 60.0:
			draw_set_transform(rect.position + Vector2(rect.size.x - 6.0, 4.0), PI * 0.5)
			at = Vector2(0.0, 10.0)
		draw_string_outline(font, at, names[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, 4, Color(0.0, 0.0, 0.0, 0.85))
		draw_string(font, at, names[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, colour)
		draw_set_transform(Vector2.ZERO)
		for j in range(i + 1, names.size()):
			if rect.intersects(zones[names[j]]):
				print("zones: %s overlaps %s at %s" % [names[i], names[j], size])
	for y: float in [ArenaLayout.top_rule(size), ArenaLayout.foot_rule(size)]:
		draw_string(font, Vector2(4.0, y - 3.0), "y %d" % roundi(y), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color.WHITE)
