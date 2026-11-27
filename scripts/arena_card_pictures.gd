class_name ArenaCardPictures
## The picture of each card. One table maps a card's key and side to its picture.
##
## A picture is a drawing (DRAWN: baked from the artist's sheet by studio/card_picture_bake.gd)
## or, until it has one, pencil lines laid out by code: a list of lines, each a list of points
## in a box that runs from (0, 0) at the top left to (1, 1) at the bottom right. `add` lays
## those out with a Pencil; a drawing is drawn by scripts/arena_card.gd.

## Paper pictures by key: a Root's Paper side, or a Factor (which has one picture for both men).
const PAPER := {
	"lamp": "cloak", "heart": "quill", "mirror": "cane_hand",
	"cup": "cup", "eye": "hourglass", "lock": "lock", "pen": "mask", "cane": "cane",
}
## The pictures of the Ink Roots that have one of their own: the others keep their Paper
## picture, in Ink's light.
const INK := {}
## The pictures that are drawings: the drawing's lines are in the texture's red and their glow
## in its green, with DRAWN_PAD pixels of the texture left clear on every side of the drawing.
const DRAWN := {
	"cloak": preload("res://art/card_pictures/cloak.png"),
	"quill": preload("res://art/card_pictures/quill.png"),
	"cane_hand": preload("res://art/card_pictures/cane_hand.png"),
	"cup": preload("res://art/card_pictures/cup.png"),
	"mask": preload("res://art/card_pictures/mask.png"),
	"hourglass": preload("res://art/card_pictures/hourglass.png"),
}
const DRAWN_PAD := 18.0


## The name of the picture of the card with this key, on this side.
static func picture_of(key: String, ink: bool) -> String:
	if ink and INK.has(key):
		return INK[key]
	return PAPER.get(key, "")


## The drawing of a picture, or null for one that is laid out as lines.
static func drawing(picture: String) -> Texture2D:
	return DRAWN.get(picture)


## Where a drawing's texture goes for the drawing itself to fit in `box`, keeping its shape.
static func drawing_box(drawn: Texture2D, box: Rect2) -> Rect2:
	var whole := drawn.get_size()
	var inner := whole - Vector2(DRAWN_PAD, DRAWN_PAD) * 2.0
	var size := whole * minf(box.size.x / inner.x, box.size.y / inner.y)
	return Rect2(box.get_center() - size * 0.5, size)


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
		"lock":
			# A padlock.
			out.append(_path([0.22, 0.46, 0.78, 0.46, 0.78, 0.92, 0.22, 0.92, 0.22, 0.46]))
			out.append(_path([0.33, 0.46, 0.33, 0.3]))
			out.append(_arc(Vector2(0.5, 0.3), Vector2(0.17, 0.2), 180.0, 360.0))
			out.append(_path([0.67, 0.3, 0.67, 0.46]))
			out.append(_arc(Vector2(0.5, 0.64), Vector2(0.06, 0.06), 0.0, 360.0))
			out.append(_path([0.5, 0.7, 0.5, 0.82]))
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
