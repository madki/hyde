extends SceneTree
## Bakes a card's picture, art/card_pictures/<name>.png, from a line drawing: dark lines on a white or
## clear sheet (CREDITS.md names the drawings; the sheets themselves are not in the repository):
##
##   godot --headless --path . -s studio/card_picture_bake.gd -- /abs/path/drawing.png <name> [thicken]
##
## Only where the lines are is kept: scripts/arena_card.gd supplies the colour. The drawing is
## cut out of its sheet (stray specks away from it are left behind), given room around it for
## its glow (PAD pixels on every side: scripts/arena_card_pictures.gd has the same number), and
## saved small, its longer side OUT_SIDE pixels, with the lines in red and the same lines
## blurred, for the glow, in green.
##
## So that drawings made with different brushes, or at different sizes, sit together on the
## cards, the drawing's usual line width is measured and every line is made wider by the same
## amount, to bring that usual width up to LINE_WIDTH: thick and thin lines stay different, as
## drawn. No line is made wider than MOST_THICKEN on each side, and none is made thinner.
## `thicken`, when given, is used instead of the measured amount. Below zero it widens the gaps
## instead, for a drawing of filled shapes with thin clear lines cut through them: every shape
## is cut back by that much on each side, and a line too thin to be cut back is left as drawn.
## That is done on the sheet itself, before the drawing is made small, so the gaps keep clean
## edges.
##
## A gauge's picture, art/gauge_pictures/<name>.png, is baked from the same sheet in chalk:
##
##   godot --headless --path . -s studio/card_picture_bake.gd -- /abs/path/drawing.png <name> chalk <width> [inner]
##
## For a drawing of filled shapes cut through by thin clear lines, it keeps the clear lines and
## an outline round each shape, and lets the fills go: chalk on a slate, where the cards print
## ink on paper. Every line is made `width` pixels of the baked picture wide (the gauges show
## the picture about a tenth of its size, so a line much thinner than ten would vanish there),
## and the outline is as wide, half inside the shape and half out. `inner`, when given, is the
## width of the lines inside the shapes instead, for a drawing with many of them close together. The picture is laid out as
## a card's is, PAD and all, so scripts/arena_card_pictures.gd fits either the same way.

const OUT := "res://art/card_pictures/%s.png"
const CHALK_OUT := "res://art/gauge_pictures/%s.png"
const OUT_SIDE := 256
## The room left around the drawing, in pixels of the baked picture.
const PAD := 18
## How far the glow spreads, in pixels of the baked picture.
const GLOW_REACH := 7
## The sheet is searched for the drawing in cells this many pixels wide; a cell with less than
## this share of ink is a speck, not part of the drawing.
const CELL := 16
const CELL_INK := 0.12
## The usual width of a drawing's lines once baked, in pixels of the baked picture, and the
## most that is added to each side of a line to reach it.
const LINE_WIDTH := 4.0
const MOST_THICKEN := 1.0
## In chalk, how wide a clear line can be, in pixels of the sheet, and still be closed up when
## the drawing's shapes are found.
const CLOSE_FOR := 40.0

## The size of the baked picture.
var _size := Vector2i.ZERO


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var chalk := args.size() >= 4 and args.size() <= 5 and args[2] == "chalk"
	if args.size() < 2 or args.size() > 3 and not chalk:
		printerr("usage: -- /abs/path/drawing.png <name> [thicken], or <name> chalk <width> [inner]")
		quit(1)
		return
	var sheet := Image.load_from_file(args[0])
	if sheet == null:
		printerr("cannot read ", args[0])
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var size := sheet.get_size()
	# Ink: dark and not clear.
	var bytes := sheet.get_data()
	var ink := PackedFloat32Array()
	ink.resize(size.x * size.y)
	for i in ink.size():
		var light := (bytes[i * 4] * 0.299 + bytes[i * 4 + 1] * 0.587 + bytes[i * 4 + 2] * 0.114) / 255.0
		ink[i] = (1.0 - light) * bytes[i * 4 + 3] / 255.0

	# Where the drawing is: the cells with enough ink in them.
	var found := Rect2i()
	for cy in size.y / CELL:
		for cx in size.x / CELL:
			var sum := 0.0
			for y in CELL:
				for x in CELL:
					sum += ink[(cy * CELL + y) * size.x + cx * CELL + x]
			if sum / (CELL * CELL) >= CELL_INK:
				var cell := Rect2i(cx * CELL, cy * CELL, CELL, CELL)
				found = cell if found.size == Vector2i.ZERO else found.merge(cell)
	if found.size == Vector2i.ZERO:
		printerr("no drawing found on the sheet")
		quit(1)
		return

	# The drawing in the middle of a square, as greys, made small. In chalk the outline reaches
	# out past the shapes, so room is left for it.
	var inner := OUT_SIDE - PAD * 2
	var scale := float(inner) / maxi(found.size.x, found.size.y)
	if chalk:
		found = found.grow(int(ceil(float(args[3]) / scale))).intersection(Rect2i(Vector2i.ZERO, size))
		scale = float(inner) / maxi(found.size.x, found.size.y)
	var cut := Image.create(found.size.x, found.size.y, false, Image.FORMAT_L8)
	var cut_bytes := PackedByteArray()
	cut_bytes.resize(found.size.x * found.size.y)
	for y in found.size.y:
		for x in found.size.x:
			cut_bytes[y * found.size.x + x] = int(round(ink[(found.position.y + y) * size.x + found.position.x + x] * 255.0))
	var thicken_given := args.size() == 3
	if chalk:
		var inner_width := float(args[4] if args.size() == 5 else args[3])
		cut_bytes = _chalk(cut_bytes, found.size, float(args[3]) / scale, inner_width / scale)
	elif thicken_given and float(args[2]) < 0.0:
		cut_bytes = _widen_gaps(cut_bytes, found.size, -float(args[2]) / scale)
	cut.set_data(found.size.x, found.size.y, false, Image.FORMAT_L8, cut_bytes)
	var small := Vector2i(maxi(1, int(round(found.size.x * scale))), maxi(1, int(round(found.size.y * scale))))
	cut.resize(small.x, small.y, Image.INTERPOLATE_LANCZOS)
	_size = small + Vector2i(PAD, PAD) * 2
	var lines := PackedFloat32Array()
	lines.resize(_size.x * _size.y)
	var at := Vector2i(PAD, PAD)
	var small_bytes := cut.get_data()
	for y in small.y:
		for x in small.x:
			lines[(at.y + y) * _size.x + at.x + x] = small_bytes[y * small.x + x] / 255.0
	var usual := _line_width(small_bytes, small)
	var thicken := clampf((LINE_WIDTH - usual) * 0.5, 0.0, MOST_THICKEN)
	if chalk:
		thicken = 0.0
	elif thicken_given:
		thicken = float(args[2])
	if thicken > 0.0:
		lines = _thicken(lines, thicken)

	# The glow: the lines blurred (a box blur three times over is close to a soft round one).
	var glow := lines.duplicate()
	for pass_number in 3:
		glow = _blur(glow, GLOW_REACH / 2, true)
		glow = _blur(glow, GLOW_REACH / 2, false)

	var out_bytes := PackedByteArray()
	out_bytes.resize(_size.x * _size.y * 3)
	for i in lines.size():
		out_bytes[i * 3] = int(round(clampf(lines[i], 0.0, 1.0) * 255.0))
		out_bytes[i * 3 + 1] = int(round(clampf(glow[i], 0.0, 1.0) * 255.0))
	var out := Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGB8, out_bytes)
	var path := (CHALK_OUT if chalk else OUT) % args[1]
	out.save_png(path)
	if chalk:
		print("baked %s in chalk: the drawing is %s on its sheet, %s here" % [path, found, _size])
	else:
		print("baked %s: the drawing is %s on its sheet, %s here; its lines are %.1f px wide, made %.2f px wider on each side" % [
				path, found, _size, usual, thicken])
	quit()


## The usual width of the lines of a drawing (greys, `size` pixels): every row and column is
## cut into its runs of ink, and most runs cross a line rather than follow it, so a run from
## the short end of them all is about one line wide.
func _line_width(greys: PackedByteArray, size: Vector2i) -> float:
	var runs: Array[float] = []
	for across: bool in [true, false]:
		var outer := size.y if across else size.x
		var along := size.x if across else size.y
		for a in outer:
			var run := 0.0
			for b in along + 1:
				var ink := 0.0
				if b < along:
					ink = greys[(a * size.x + b) if across else (b * size.x + a)] / 255.0
				if ink > 0.25:
					run += ink
				elif run > 0.0:
					runs.append(run)
					run = 0.0
	if runs.is_empty():
		return LINE_WIDTH
	runs.sort()
	return runs[runs.size() * 3 / 10]


## Every line made `by` pixels wider on each side: each pixel takes the most ink found within
## that distance of it, with a soft edge.
func _thicken(from: PackedFloat32Array, by: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(from.size())
	var reach := int(ceil(by))
	for y in _size.y:
		for x in _size.x:
			var most := 0.0
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var px := x + dx
					var py := y + dy
					if px < 0 or py < 0 or px >= _size.x or py >= _size.y:
						continue
					var weight := clampf(by + 0.5 - Vector2(dx, dy).length(), 0.0, 1.0)
					most = maxf(most, from[py * _size.x + px] * weight)
			out[y * _size.x + x] = most
	return out


## Every filled shape of a drawing (greys, `size` pixels) cut back by `by` pixels on each side,
## which widens the gaps between shapes. A line too thin to be cut back would be lost, so it
## is kept as drawn: what is not within `by` of anything left after the cut is such a line, if
## it is a long piece (a short piece is only the tip of a sharp corner, and goes).
func _widen_gaps(greys: PackedByteArray, size: Vector2i, by: float) -> PackedByteArray:
	var count := size.x * size.y
	var clear := PackedByteArray()
	clear.resize(count)
	for i in count:
		clear[i] = 0 if greys[i] > 127 else 1
	var depth := _distance(clear, size, true)
	var left := PackedByteArray()
	left.resize(count)
	for i in count:
		left[i] = 1 if depth[i] - by > 0.5 else 0
	var from_left := _distance(left, size, false)

	# The pieces that the cut would lose, and of them the long ones.
	var lost := PackedByteArray()
	lost.resize(count)
	for i in count:
		lost[i] = 1 if clear[i] == 0 and from_left[i] > by + 2.0 else 0
	var kept := PackedByteArray()
	kept.resize(count)
	for start in count:
		if lost[start] != 1:
			continue
		var piece := PackedInt32Array([start])
		lost[start] = 2
		var low := Vector2i(size)
		var high := Vector2i.ZERO
		var next := 0
		while next < piece.size():
			var i := piece[next]
			next += 1
			var x := i % size.x
			var y := i / size.x
			low = Vector2i(mini(low.x, x), mini(low.y, y))
			high = Vector2i(maxi(high.x, x), maxi(high.y, y))
			if x > 0 and lost[i - 1] == 1:
				lost[i - 1] = 2
				piece.append(i - 1)
			if x < size.x - 1 and lost[i + 1] == 1:
				lost[i + 1] = 2
				piece.append(i + 1)
			if y > 0 and lost[i - size.x] == 1:
				lost[i - size.x] = 2
				piece.append(i - size.x)
			if y < size.y - 1 and lost[i + size.x] == 1:
				lost[i + size.x] = 2
				piece.append(i + size.x)
		if maxi(high.x - low.x, high.y - low.y) >= by * 8.0:
			for i in piece:
				kept[i] = 1
	var from_kept := _distance(kept, size, false)

	var out := PackedByteArray()
	out.resize(count)
	for i in count:
		var ink := clampf(depth[i] - by, 0.0, 1.0) * 255.0
		# A kept line, and what joins it to the shape it runs into.
		if from_kept[i] <= by + 3.0:
			ink = maxf(ink, greys[i])
		out[i] = int(round(ink))
	return out


## The chalk of a drawing (greys, `size` pixels) of filled shapes cut by clear lines: the clear
## lines inside the shapes, `inner` pixels wide, and an outline round each, `width` wide. A shape is the
## ink with its clear lines closed up (any gap narrower than CLOSE_FOR across is filled) and
## every hole in it filled.
func _chalk(greys: PackedByteArray, size: Vector2i, width: float, inner: float) -> PackedByteArray:
	var count := size.x * size.y
	var close_by := maxf(width, CLOSE_FOR) * 0.5
	var ink := PackedByteArray()
	ink.resize(count)
	for i in count:
		ink[i] = 1 if greys[i] > 127 else 0
	var from_ink := _distance(ink, size, false)
	var grown := PackedByteArray()
	grown.resize(count)
	for i in count:
		grown[i] = 0 if from_ink[i] <= close_by else 1
	var from_outside := _distance(grown, size, false)
	# The shapes: the grown ink cut back again, and what the sheet's edge cannot reach.
	var outside := PackedByteArray()
	outside.resize(count)
	var reach := PackedInt32Array()
	for i in count:
		var x := i % size.x
		var y := i / size.x
		if (x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1) and from_outside[i] <= close_by:
			outside[i] = 1
			reach.append(i)
	var next := 0
	while next < reach.size():
		var i := reach[next]
		next += 1
		var x := i % size.x
		for j: int in [i - 1 if x > 0 else -1, i + 1 if x < size.x - 1 else -1, i - size.x, i + size.x]:
			if j >= 0 and j < count and outside[j] == 0 and from_outside[j] <= close_by:
				outside[j] = 1
				reach.append(j)
	var shape := PackedByteArray()
	shape.resize(count)
	var gaps := PackedByteArray()
	gaps.resize(count)
	for i in count:
		shape[i] = 1 - outside[i]
		gaps[i] = 1 if shape[i] == 1 and ink[i] == 0 else 0
	var from_shape := _distance(shape, size, false)
	var from_outline := _distance(outside, size, false)
	var from_gap := _distance(gaps, size, false)
	var half := width * 0.5
	var out := PackedByteArray()
	out.resize(count)
	for i in count:
		var edge := from_outline[i] if shape[i] == 1 else from_shape[i]
		var c := maxf(clampf(half + 0.5 - edge, 0.0, 1.0), clampf(inner * 0.5 + 0.5 - from_gap[i], 0.0, 1.0))
		out[i] = int(round(c * 255.0))
	return out


## How far every pixel is from the nearest one that is set in `marks`, in pixels (a little
## off along slanted ways: it is found in two sweeps). `edge_set` counts everything outside
## the picture as set.
func _distance(marks: PackedByteArray, size: Vector2i, edge_set: bool) -> PackedFloat32Array:
	const STRAIGHT := 0.9619
	const SLANTED := 1.3604
	var far := 1.0e9
	var out := PackedFloat32Array()
	out.resize(marks.size())
	var w := size.x
	for y in size.y:
		for x in w:
			var i := y * w + x
			var d := 0.0 if marks[i] != 0 else far
			if d > 0.0:
				if edge_set and (x == 0 or y == 0 or x == w - 1 or y == size.y - 1):
					d = 1.0
				if x > 0:
					d = minf(d, out[i - 1] + STRAIGHT)
				if y > 0:
					d = minf(d, out[i - w] + STRAIGHT)
					if x > 0:
						d = minf(d, out[i - w - 1] + SLANTED)
					if x < w - 1:
						d = minf(d, out[i - w + 1] + SLANTED)
			out[i] = d
	for y in range(size.y - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var d := out[i]
			if d > 0.0:
				if x < w - 1:
					d = minf(d, out[i + 1] + STRAIGHT)
				if y < size.y - 1:
					d = minf(d, out[i + w] + STRAIGHT)
					if x < w - 1:
						d = minf(d, out[i + w + 1] + SLANTED)
					if x > 0:
						d = minf(d, out[i + w - 1] + SLANTED)
				out[i] = d
	return out


## A box blur along one direction, `reach` pixels each way.
func _blur(from: PackedFloat32Array, reach: int, across: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(from.size())
	var step := 1 if across else _size.x
	var length := _size.x if across else _size.y
	for y in _size.y:
		for x in _size.x:
			var along := x if across else y
			var sum := 0.0
			for d in range(-reach, reach + 1):
				if along + d >= 0 and along + d < length:
					sum += from[y * _size.x + x + d * step]
			out[y * _size.x + x] = sum / (reach * 2 + 1)
	return out
