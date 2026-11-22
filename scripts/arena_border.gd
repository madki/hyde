class_name ArenaBorder
extends Control
## The page's ruled border, drawn by hand: an outer heavier line and an inner light one. Each
## side is its own stroke, a little off true and running past the corner, fading where the
## pencil lifted, and gone over again for part of the way.

## Distance of the two rulings from the edge of the page, in pixels.
@export var insets := PackedFloat32Array([28.0, 36.0])
## Usual width of each ruling, in pixels.
@export var widths := PackedFloat32Array([2.6, 1.3])
## How far the hand wavers, in pixels.
@export var wobble := 1.3
## How fully a line fades out where the pencil lifts.
@export_range(0.0, 1.0) var fade := 0.45
@export var colour := Color(0.015, 0.025, 0.035)
## Changes every line a little while keeping the look.
@export var rng_seed := 7


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var pencil := Pencil.new(rng_seed)
	pencil.colour = colour
	for ruling in insets.size():
		var inset := Vector2(insets[ruling], insets[ruling])
		var rect := Rect2(inset, size - inset * 2.0)
		var width := widths[ruling]
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)]
		for i in 4:
			var from: Vector2 = corners[i]
			var to: Vector2 = corners[(i + 1) % 4]
			var along := (to - from).normalized()
			var across := Vector2(-along.y, along.x)
			from += -along * pencil.randf_range(3.0, 11.0) + across * pencil.randf_range(-1.6, 1.6)
			to += along * pencil.randf_range(3.0, 11.0) + across * pencil.randf_range(-1.6, 1.6)
			pencil.stroke(PackedVector2Array([from, to]), width, wobble, fade)
			if pencil.randf_range(0.0, 1.0) < 0.6:
				var start := pencil.randf_range(0.0, 0.5)
				var end := start + pencil.randf_range(0.2, 0.45)
				pencil.stroke(PackedVector2Array([from.lerp(to, start) + across * 0.9,
						from.lerp(to, end) + across * 0.5]), width * 0.7, wobble * 0.8, 0.4)
	pencil.draw(self)
