class_name ArenaCardPictures
## The picture of each card, as pencil lines laid out by code: placeholders until the cards
## have drawn pictures. One table maps a card's key and side to its picture.
##
## A picture is a list of lines, each a list of points in a box that runs from (0, 0) at the
## top left to (1, 1) at the bottom right. `add` lays one out with a Pencil.

## Paper pictures by key: a Root's Paper side, or a Factor (which has one picture for both men).
const PAPER := {
	"lamp": "lamp", "heart": "heart", "mirror": "mirror",
	"cup": "cup", "eye": "eye", "lock": "lock", "pen": "pen", "cane": "cane",
}
## The pictures of the three Ink Roots.
const INK := {"lamp": "fog", "heart": "apple", "mirror": "pride"}


## The name of the picture of the card with this key, on this side.
static func picture_of(key: String, ink: bool) -> String:
	if ink and INK.has(key):
		return INK[key]
	return PAPER.get(key, "")


## Lays the picture out with `pencil`, inside `box`, keeping its shape.
static func add(pencil: Pencil, picture: String, box: Rect2, width: float = 1.5) -> void:
	var side := minf(box.size.x, box.size.y)
	var origin := box.get_center() - Vector2(side, side) * 0.5
	for line: PackedVector2Array in lines(picture):
		var path := PackedVector2Array()
		for point in line:
			path.append(origin + point * side)
		pencil.stroke(path, width, 0.35, 0.0)


## The lines of a picture, in the unit box.
static func lines(picture: String) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	match picture:
		"lamp":
			# An oil lamp: its foot, its bowl, the glass and the flame.
			out.append(_path([0.3, 0.92, 0.7, 0.92, 0.62, 0.84, 0.38, 0.84, 0.3, 0.92]))
			out.append(_arc(Vector2(0.5, 0.72), Vector2(0.2, 0.12), 0.0, 360.0))
			out.append(_path([0.42, 0.61, 0.36, 0.42, 0.42, 0.2, 0.46, 0.08, 0.54, 0.08, 0.58, 0.2, 0.64, 0.42, 0.58, 0.61]))
			out.append(_path([0.5, 0.52, 0.45, 0.42, 0.5, 0.28, 0.55, 0.42, 0.5, 0.52]))
		"fog":
			# The lamp gone: drifts of fog.
			for i in 5:
				var y := 0.18 + i * 0.16
				var from := 0.08 + 0.1 * (i % 2)
				var points: Array = []
				for k in 9:
					points.append(from + k * 0.09)
					points.append(y + 0.035 * sin(k * 1.6 + i))
				out.append(_path(points))
		"heart":
			var heart := PackedVector2Array()
			for k in 41:
				var t := TAU * k / 40.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				heart.append(Vector2(0.5 + x * 0.024, 0.47 - y * 0.024))
			out.append(heart)
		"apple":
			# An apple with a bite out of it.
			out.append(_arc(Vector2(0.47, 0.58), Vector2(0.3, 0.32), 40.0, 325.0))
			out.append(_arc(Vector2(0.78, 0.47), Vector2(0.13, 0.15), 110.0, 262.0))
			out.append(_path([0.47, 0.28, 0.5, 0.12]))
			out.append(_path([0.5, 0.18, 0.62, 0.08, 0.7, 0.14, 0.58, 0.2, 0.5, 0.18]))
		"mirror":
			# A hand mirror.
			out.append(_arc(Vector2(0.5, 0.36), Vector2(0.25, 0.3), 0.0, 360.0))
			out.append(_arc(Vector2(0.5, 0.36), Vector2(0.19, 0.24), 0.0, 360.0))
			out.append(_path([0.46, 0.66, 0.45, 0.94, 0.55, 0.94, 0.54, 0.66]))
			out.append(_path([0.42, 0.3, 0.52, 0.2]))
		"pride":
			# The mirror, crowned.
			out.append(_arc(Vector2(0.5, 0.52), Vector2(0.22, 0.26), 0.0, 360.0))
			out.append(_path([0.46, 0.78, 0.45, 0.96, 0.55, 0.96, 0.54, 0.78]))
			out.append(_path([0.3, 0.22, 0.26, 0.04, 0.4, 0.14, 0.5, 0.02, 0.6, 0.14, 0.74, 0.04, 0.7, 0.22, 0.3, 0.22]))
			out.append(_path([0.4, 0.5, 0.5, 0.4, 0.5, 0.56, 0.6, 0.46]))
		"cup":
			# A goblet.
			out.append(_path([0.24, 0.1, 0.76, 0.1]))
			out.append(_arc(Vector2(0.5, 0.1), Vector2(0.26, 0.42), 0.0, 180.0))
			out.append(_path([0.5, 0.52, 0.5, 0.84]))
			out.append(_path([0.3, 0.9, 0.38, 0.84, 0.62, 0.84, 0.7, 0.9, 0.3, 0.9]))
		"eye":
			out.append(_path([0.06, 0.5, 0.2, 0.34, 0.38, 0.25, 0.5, 0.23, 0.62, 0.25, 0.8, 0.34, 0.94, 0.5]))
			out.append(_path([0.06, 0.5, 0.2, 0.66, 0.38, 0.75, 0.5, 0.77, 0.62, 0.75, 0.8, 0.66, 0.94, 0.5]))
			out.append(_arc(Vector2(0.5, 0.5), Vector2(0.2, 0.2), 0.0, 360.0))
			out.append(_arc(Vector2(0.5, 0.5), Vector2(0.07, 0.07), 0.0, 360.0))
		"lock":
			# A padlock.
			out.append(_path([0.22, 0.46, 0.78, 0.46, 0.78, 0.92, 0.22, 0.92, 0.22, 0.46]))
			out.append(_path([0.33, 0.46, 0.33, 0.3]))
			out.append(_arc(Vector2(0.5, 0.3), Vector2(0.17, 0.2), 180.0, 360.0))
			out.append(_path([0.67, 0.3, 0.67, 0.46]))
			out.append(_arc(Vector2(0.5, 0.64), Vector2(0.06, 0.06), 0.0, 360.0))
			out.append(_path([0.5, 0.7, 0.5, 0.82]))
		"pen":
			# A quill.
			out.append(_path([0.16, 0.94, 0.3, 0.72, 0.84, 0.08]))
			out.append(_path([0.3, 0.72, 0.36, 0.44, 0.58, 0.18, 0.84, 0.08]))
			out.append(_path([0.3, 0.72, 0.58, 0.62, 0.8, 0.36, 0.84, 0.08]))
			out.append(_path([0.16, 0.94, 0.22, 0.8]))
		"cane":
			# A walking cane.
			out.append(_path([0.62, 0.94, 0.4, 0.26]))
			out.append(_arc(Vector2(0.54, 0.22), Vector2(0.15, 0.15), 165.0, 380.0))
			out.append(_path([0.38, 0.2, 0.47, 0.5]))
	return out


## A line through pairs of numbers: x, y, x, y and so on.
static func _path(numbers: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, numbers.size() - 1, 2):
		out.append(Vector2(numbers[i], numbers[i + 1]))
	return out


## Part of an ellipse, from one angle to another in degrees: 0 points right and 90 down.
static func _arc(centre: Vector2, radius: Vector2, from: float, to: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pieces := maxi(4, int(absf(to - from) / 15.0))
	for k in pieces + 1:
		var angle := deg_to_rad(lerpf(from, to, float(k) / pieces))
		out.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return out
