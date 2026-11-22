class_name ArenaCard
extends Control
## One card as it lies on the arena: a worn piece of paper with its shadow, a frame printed in
## heavy ink, a title, a picture and its chips.
##
## A paper card is cream with a heavy upright title; an ink card is stained dark purple with
## a slanted one. The body (outline, paper, stains, shadow) is shaders/card_body.gdshader,
## through shaders/card_paper_material.tres or card_ink_material.tres: change the look there.
## The frame's lines are laid out with Pencil and printed by shaders/card_line.gdshader, and
## the picture by shaders/card_picture.gdshader. All three are printed coarsely, in texels of
## TEXEL pixels. `rng_seed` changes the wear, the stains and the hand of
## the lines, so that no two cards are alike. Set a card up with `show_card`.

const SIZE := Vector2(96.0, 140.0)
## The card is printed coarsely, in square texels this many pixels wide: 0 prints it smooth.
const TEXEL := 1.0
## Room around the card for its shadow, in pixels.
const MARGIN := 24.0
## Distance of the frame from the card's edge, and its width.
const FRAME_INSET := 5.5
const FRAME_WIDTH := 2.2
## Where the title's box ends and where the foot (the chips) begins, from the top.
const TITLE_BOTTOM := 28.0
const FOOT_TOP := 115.0
## Width of the box the chips are written in.
const CHIPS_WIDTH := 20.0

const PAPER_MATERIAL: ShaderMaterial = preload("res://shaders/card_paper_material.tres")
const INK_MATERIAL: ShaderMaterial = preload("res://shaders/card_ink_material.tres")
const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/card_line_material.tres")
const PICTURE_SHADER: Shader = preload("res://shaders/card_picture.gdshader")

const PAPER_LINE := Color(0.07, 0.045, 0.03)
const PAPER_TEXT := Color(0.07, 0.045, 0.03)
## On an ink card the frame and the picture are printed light, to be seen on the dark stain.
const INK_LINE := Color(0.78, 0.68, 0.62)
const INK_TEXT := Color(0.93, 0.85, 0.7)

var title := ""
## True for a card on Hyde's side.
var ink := false
## A line drawing: only its alpha is used.
var picture: Texture2D
var chips := 0
var rng_seed := 1

var _body := Control.new()
var _picture := TextureRect.new()
var _lines := Control.new()
var _title := Label.new()
var _chips := Label.new()
var _upright := FontVariation.new()
var _slanted := FontVariation.new()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5

	# The engine's own font, until the game has its two faces: made heavy and narrow for
	# paper, and slanted for ink.
	_upright.base_font = ThemeDB.fallback_font
	_upright.variation_embolden = 0.9
	_upright.variation_transform = Transform2D(Vector2(0.84, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	_slanted.base_font = ThemeDB.fallback_font
	_slanted.variation_embolden = 0.3
	_slanted.variation_transform = Transform2D(Vector2(1.0, 0.22), Vector2(0.0, 1.0), Vector2.ZERO)

	_body.draw.connect(_draw_body)
	_lines.draw.connect(_draw_lines)
	_lines.material = LINE_MATERIAL
	LINE_MATERIAL.set_shader_parameter("texel", TEXEL)
	var picture_material := ShaderMaterial.new()
	picture_material.shader = PICTURE_SHADER
	_picture.material = picture_material
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var inner := FRAME_INSET + FRAME_WIDTH * 0.5
	_picture.position = Vector2(inner + 6.0, TITLE_BOTTOM + 6.0)
	_picture.size = Vector2(SIZE.x - (inner + 6.0) * 2.0, FOOT_TOP - TITLE_BOTTOM - 12.0)
	_title.position = Vector2(inner, inner)
	_title.size = Vector2(SIZE.x - inner * 2.0, TITLE_BOTTOM - inner)
	_chips.position = Vector2(inner, FOOT_TOP)
	_chips.size = Vector2(CHIPS_WIDTH, SIZE.y - inner - FOOT_TOP)
	for label: Label in [_title, _chips]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for child: Control in [_body, _picture, _lines, _title, _chips]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
	_refresh()


## Sets everything the card shows. `on_ink` is true for a card on Hyde's side.
func show_card(new_title: String, on_ink: bool, new_picture: Texture2D, new_chips: int,
		new_seed: int = rng_seed) -> void:
	title = new_title
	ink = on_ink
	picture = new_picture
	chips = new_chips
	rng_seed = new_seed
	_refresh()


func _refresh() -> void:
	var body := (INK_MATERIAL if ink else PAPER_MATERIAL).duplicate() as ShaderMaterial
	body.set_shader_parameter("card_size", SIZE)
	body.set_shader_parameter("seed", float(rng_seed))
	body.set_shader_parameter("texel", TEXEL)
	body.set_shader_parameter("band_height", TITLE_BOTTOM + 1.0)
	_body.material = body

	var text := INK_TEXT if ink else PAPER_TEXT
	var font: Font = _slanted if ink else _upright
	_title.text = title if ink else title.to_upper()
	_title.add_theme_font_override("font", font)
	_title.add_theme_color_override("font_color", text)
	# The largest size at which the title fits its box.
	var font_size := 14 if ink else 13
	while font_size > 7 and font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			font_size).x > _title.size.x - 5.0:
		font_size -= 1
	_title.add_theme_font_size_override("font_size", font_size)

	_chips.text = str(chips)
	_chips.add_theme_font_override("font", _upright)
	_chips.add_theme_font_size_override("font_size", 14)
	_chips.add_theme_color_override("font_color", text)

	_picture.texture = picture
	var picture_material := _picture.material as ShaderMaterial
	picture_material.set_shader_parameter("tint", INK_LINE if ink else PAPER_LINE)
	picture_material.set_shader_parameter("seed", float(rng_seed))
	if picture:
		# The picture is printed in the body's texels: how many of its own pixels that is.
		var shown := minf(_picture.size.x / picture.get_width(), _picture.size.y / picture.get_height())
		picture_material.set_shader_parameter("texel", TEXEL / shown)

	_body.queue_redraw()
	_lines.queue_redraw()


func _draw_body() -> void:
	_body.draw_rect(Rect2(-Vector2(MARGIN, MARGIN), SIZE + Vector2(MARGIN, MARGIN) * 2.0), Color.WHITE)


## The frame: a heavy line around the card, a line under the title, the foot's line and the
## side of the chips' box, then a little hatching in two corners of the picture's box.
func _draw_lines() -> void:
	var pencil := Pencil.new(rng_seed)
	pencil.colour = INK_LINE if ink else PAPER_LINE
	var inset := Vector2(FRAME_INSET, FRAME_INSET)
	var rect := Rect2(inset, SIZE - inset * 2.0)
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		_rule(pencil, corners[i], corners[(i + 1) % 4], FRAME_WIDTH)
	_rule(pencil, Vector2(rect.position.x, TITLE_BOTTOM), Vector2(rect.end.x, TITLE_BOTTOM), 1.9)
	_rule(pencil, Vector2(rect.position.x, FOOT_TOP), Vector2(rect.end.x, FOOT_TOP), 1.7)
	_rule(pencil, Vector2(rect.position.x + CHIPS_WIDTH + 2.0, FOOT_TOP),
			Vector2(rect.position.x + CHIPS_WIDTH + 2.0, rect.end.y), 1.5)
	_hatch(pencil, Vector2(rect.end.x - 1.5, FOOT_TOP - 1.0), Vector2(-1.0, -1.0), 22.0)
	_hatch(pencil, Vector2(rect.position.x + 1.5, TITLE_BOTTOM + 1.0), Vector2(1.0, 1.0), 12.0)
	pencil.draw(_lines)


## One ruled line: a little off true and running a little past both ends, and gone over again
## for part of the way now and then.
func _rule(pencil: Pencil, from: Vector2, to: Vector2, width: float) -> void:
	var along := (to - from).normalized()
	var across := Vector2(-along.y, along.x)
	from += -along * pencil.randf_range(0.5, 1.5) + across * pencil.randf_range(-0.4, 0.4)
	to += along * pencil.randf_range(0.5, 1.5) + across * pencil.randf_range(-0.4, 0.4)
	pencil.stroke(PackedVector2Array([from, to]), width, 0.5, 0.0)
	if pencil.randf_range(0.0, 1.0) < 0.4:
		var start := pencil.randf_range(0.0, 0.5)
		var end := start + pencil.randf_range(0.25, 0.5)
		pencil.stroke(PackedVector2Array([from.lerp(to, start) + across * 0.7,
				from.lerp(to, end) + across * 0.4]), width * 0.6, 0.4, 0.3)


## Slanting strokes that shade a corner of a box. `corner` is the corner, `inward` points from
## it into the box along both sides, and `reach` is how far along the sides the shading goes.
func _hatch(pencil: Pencil, corner: Vector2, inward: Vector2, reach: float) -> void:
	var k := 3.0
	while k < reach:
		var from := corner + Vector2(inward.x * k, inward.y * 1.0)
		var to := corner + Vector2(inward.x * 1.0, inward.y * k)
		var kept := pencil.randf_range(0.65, 1.0)
		pencil.stroke(PackedVector2Array([from, from.lerp(to, kept)]), 0.9, 0.3, 0.0)
		k += pencil.randf_range(2.6, 3.6)
