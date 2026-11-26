class_name ArenaCard
extends Control
## One card as it lies on the arena: dark stock with its shadow, a faint edge in the owner's
## light, a title, a picture and its chips on a disc. A Common Factor also has what it does
## written under its picture.
##
## Jekyll's card is dark blue stock with a heavy upright title; Hyde's is dark plum stock with
## a slanted one. Writing is in chalk; the picture and the chips are drawn in the owner's
## light, and the picture glows (shaders/card_picture.gdshader). The body (outline, stock,
## stains, shadow) is shaders/card_body.gdshader,
## through shaders/card_paper_material.tres or card_ink_material.tres: change the look there.
## The edge (or a back's frame) and the picture are laid out with Pencil and printed by
## shaders/card_line.gdshader, in a steady hand. `rng_seed` picks where a card's stain starts.
##
## A card is set up from the rules' data: `show_entry` takes one card of
## RulesView.table().hand, and `show_face` a card that is in no hand (on offer, or seen on
## top of the draw pile). What the card is doing is then shown by plain marks, until each has
## a look of its own: `face_down` (the draw pile), `dimmed` (cannot be played now) and a
## written `set_tag` in the foot ("turns +2", "he takes", "best"). A chosen card is lifted by
## the hand that holds it. `change_face` changes the card where it lies, and `appear` and
## `leave` bring it in and take it away.
##
## In the hand a card is partly covered by the next: `strip` and `foot_strip` write the title
## and the tag in the part that shows. The chips are on a disc under the title, at the left,
## where the next card does not cover them.

const SIZE := Vector2(96.0, 140.0)
## The card's lines are printed in square texels this many pixels wide: 0 prints them smooth.
const TEXEL := 0.0
## Room around the card for its shadow, in pixels.
const MARGIN := 24.0
## Distance of the frame from the card's edge, and its width: the frame of a card's back, and
## the box the face's writing keeps inside.
const FRAME_INSET := 5.5
const FRAME_WIDTH := 2.2
## The face's edge: its distance from the card's edge, its width, and how far it is lit, from
## the stock (0) to the owner's light (1).
const EDGE_INSET := 2.5
const EDGE_WIDTH := 1.0
const EDGE_LIGHT := 0.38
## Where the title's box ends and where the foot (the chips) begins, from the top.
const TITLE_BOTTOM := 28.0
const FOOT_TOP := 115.0
## Radius of the disc the chips are written on while they stand under the title.
const DISC := 10.0
## Half the width of the ribbons the picture's glow is drawn on, in pixels: room for its light.
const GLOW_RIBBON := 4.0
## The rings of copies the glow is drawn in around the picture: each ring's distance from it in
## pixels, and how bright each copy in it is. GLOW_COPIES copies make a ring.
const GLOW_RINGS: Array[Vector2] = [Vector2(2.5, 0.07), Vector2(5.0, 0.035)]
const GLOW_COPIES := 8
## The width of the picture's lines, in pixels.
const PICTURE_WIDTH := 2.0
## How far the light around the disc reaches, in pixels.
const DISC_GLOW := 3
## Height of a Factor's picture: what it does is written in the rest of the picture's box.
const FACTOR_PICTURE := 46.0
## The widest a Factor's drawn picture gets: it stays clear of the chips' disc.
const FACTOR_DRAWING_WIDTH := 42.0
## How dark a card that cannot be played now is printed.
## The time half of a change of face takes (the card closes, then opens), and the time a
## card takes to appear or to leave.
const TURN_TIME := 0.09
const FADE_TIME := 0.18
## The time the rim light takes to come up on a chosen card, or to go.
const RIM_TIME := 0.15
## The wet reflection under a chosen card: how strongly its lines show, the gap between the
## card's lower edge and the line it is mirrored on, and how far up the card it reaches.
const REFLECTION := 0.4
const REFLECTION_GAP := 3.0
const REFLECTION_REACH := 70.0
## The shift's split on one card changing face: how long its three coloured copies are apart,
## and how far apart they go, in pixels, each in its own direction.
const SPLIT_TIME := 0.3
const SPLIT_REACH := 4.0
const SPLIT_WAYS: Array[Vector2] = [Vector2(-1.0, -0.3), Vector2(1.0, 0.3), Vector2(0.2, 1.0)]
## The time the ink takes to creep over a Root that has just become Hyde's, at speed 1.
const STAIN_TIME := 0.6

const PAPER_MATERIAL: ShaderMaterial = preload("res://shaders/card_paper_material.tres")
const INK_MATERIAL: ShaderMaterial = preload("res://shaders/card_ink_material.tres")
const LINE_MATERIAL: ShaderMaterial = preload("res://shaders/card_line_material.tres")
const GLOW_MATERIAL: ShaderMaterial = preload("res://shaders/card_picture_material.tres")
const COPY_MATERIAL: ShaderMaterial = preload("res://shaders/card_copy_material.tres")
## For a picture that is a drawing (ArenaCardPictures.DRAWN): printed, and as light.
const DRAWING_MATERIAL: ShaderMaterial = preload("res://shaders/card_drawing_material.tres")
const DRAWING_LIGHT_MATERIAL: ShaderMaterial = preload("res://shaders/card_drawing_light_material.tres")
## A drawing's halo: how much of it is the lines themselves and how much their blur, and how
## strong it is.
const DRAWING_GLOW := Vector3(0.3, 1.1, 0.45)

## The engine's font drawn from distance fields, for `sharp`. Made once, for every card.
static var _sharp_face: Font


## The card's id in the run, or -1 for a card that is in no deck.
var card_id := -1
## The card's symbol or kind: "lamp", "heart", "mirror", "cup", "eye", "lock", "pen", "cane".
var key := ""
var title := ""
## True for a card that looks like Hyde's: an Ink Root, or a Factor while he has the table.
var ink := false
var chips := 0
## What a Factor does. "" for a Root.
var text := ""
var rng_seed := 1
## Shown from the back, as in the draw pile.
var face_down := false:
	set(value):
		face_down = value
		_refresh()
## The same, the other way about: false while the card lies face down.
var face_up: bool:
	get:
		return not face_down
	set(value):
		if value == face_down:
			face_down = not value
## Cannot be played now.
var dimmed := false:
	set(value):
		if value != dimmed:
			dimmed = value
			_refresh()
## Picked for the next play or discard. The hand that holds the card lifts it.
var chosen := false:
	set(value):
		if value != chosen:
			chosen = value
			_light_rim()
## How much of the card's width shows, from its left edge, while another card lies over the
## rest: the title is then written in that much. 0 for a card that shows whole.
var strip := 0.0:
	set(value):
		if not is_equal_approx(value, strip):
			strip = value
			_refresh_title()
## The same for the card's foot, where the tag is written: a card that has risen shows more
## of its title than of its foot.
var foot_strip := 0.0:
	set(value):
		if not is_equal_approx(value, foot_strip):
			foot_strip = value
			_refresh_tag()
## The card is shown larger than its size (the hand's card under the pointer): its words are
## drawn from distance fields, sharp at any size, instead of being the small card's words
## blown up. Off, the usual face is kept, whose small sizes are the crisper.
var sharp := false:
	set(value):
		if value != sharp:
			sharp = value
			_set_faces()
			_refresh()
## How far the ink stain of a Root that is Hyde's has crept in from its corner, 0 to 1. It is
## settled (1) at rest, and creeps from 0 when the card becomes Hyde's where it lies.
var stain := 1.0:
	set(value):
		stain = value
		_set_body("stain", stain if _stained() else 0.0)

var _body := Control.new()
## The card's lines again, mirrored on the ground under it, while it is chosen.
var _reflection := Node2D.new()
## The three coloured copies of the card's lines while it splits, and how far apart they are
## now (0 to 1: 0 when it is whole).
var _split := Node2D.new()
var _apart := 0.0
var _split_tween: Tween
var _picture := Control.new()
var _glow := Control.new()
## The picture's and the glow's materials for a picture laid out as lines, and for a drawing.
var _picture_lines: ShaderMaterial
var _glow_lines: ShaderMaterial
var _glow_drawing: ShaderMaterial
## The reflection's copy of a drawing: a node of its own, for its own material.
var _reflection_drawing := Node2D.new()
var _lines := Control.new()
var _title := Label.new()
var _chips := Label.new()
var _disc := Control.new()
var _text := Label.new()
var _tag := Label.new()
var _tag_warns := false
var _upright := FontVariation.new()
var _slanted := FontVariation.new()
var _plain := FontVariation.new()
## The chips: the plain face, a little heavier, and not narrowed.
var _number := FontVariation.new()
## The two title faces drawn narrower, for a title written in a strip, and narrower still
## for a long word in a thin one.
var _upright_narrow := FontVariation.new()
var _slanted_narrow := FontVariation.new()
var _upright_tight := FontVariation.new()
var _slanted_tight := FontVariation.new()
var _change: Tween
var _rim_tween: Tween
## How strongly the rim light shows, 0 to 1.
var _rim := 0.0
## How strongly the stain shows, 0 to 1: it fades in, instead of creeping, with "reduce flashes".
var _stain_shown := 1.0
var _stain_tween: Tween
## True once the card has been given a face: a later change to Hyde's is a stain.
var _shown := false
var _built := false


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The engine's own plain sans, until the game has its own faces: upright for paper, and
	# slanted for ink. The narrow and tight faces are for titles squeezed into a strip.
	_set_faces()
	_upright.variation_embolden = 0.3
	_slanted.variation_embolden = 0.3
	_slanted.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
	# Narrowing a face shrinks its letters but not the room each takes, which spreads them
	# apart: the narrow and tight faces close the letters up instead.
	_upright_narrow.variation_embolden = 0.3
	_upright_narrow.spacing_glyph = -1
	_slanted_narrow.variation_embolden = 0.3
	_slanted_narrow.variation_transform = _slanted.variation_transform
	_slanted_narrow.spacing_glyph = -1
	_upright_tight.variation_embolden = 0.3
	_upright_tight.spacing_glyph = -2
	_slanted_tight.variation_embolden = 0.3
	_slanted_tight.variation_transform = _slanted.variation_transform
	_slanted_tight.spacing_glyph = -2
	_title.add_theme_constant_override("line_spacing", -4)
	_plain.variation_embolden = 0.1
	_number.variation_embolden = 0.25

	_body.draw.connect(_draw_body)
	_reflection.draw.connect(_draw_reflection)
	_reflection.scale = Vector2(1.0, -1.0)
	_reflection.position = Vector2(0.0, SIZE.y * 2.0 + REFLECTION_GAP)
	_reflection.visible = false
	var mirrored := COPY_MATERIAL.duplicate() as ShaderMaterial
	mirrored.set_shader_parameter("strength", 0.0)
	mirrored.set_shader_parameter("soft", 0.4)
	mirrored.set_shader_parameter("fade_from", SIZE.y)
	mirrored.set_shader_parameter("fade_reach", REFLECTION_REACH)
	_reflection.material = mirrored
	var mirrored_drawing := DRAWING_LIGHT_MATERIAL.duplicate() as ShaderMaterial
	mirrored_drawing.set_shader_parameter("lines", 0.6)
	mirrored_drawing.set_shader_parameter("blur", 0.5)
	mirrored_drawing.set_shader_parameter("strength", 0.0)
	mirrored_drawing.set_shader_parameter("fade_from", SIZE.y)
	mirrored_drawing.set_shader_parameter("fade_reach", REFLECTION_REACH)
	_add_drawn_copy(_reflection, _reflection_drawing, mirrored_drawing, Color.TRANSPARENT)
	add_child(_reflection)
	_split.visible = false
	for colour: Color in [Palette.SPLIT_JEKYLL, Palette.SPLIT_HYDE, Palette.SPLIT_THIRD]:
		var copy := Node2D.new()
		copy.material = COPY_MATERIAL
		copy.draw.connect(_draw_copy.bind(copy, colour))
		_add_drawn_copy(copy, Node2D.new(), DRAWING_LIGHT_MATERIAL, colour)
		_split.add_child(copy)
	_lines.draw.connect(_draw_lines)
	_picture.draw.connect(_draw_picture)
	_glow.draw.connect(_draw_glow)
	# Each card has its own copies, for its own seed.
	_lines.material = LINE_MATERIAL.duplicate()
	_picture_lines = LINE_MATERIAL.duplicate()
	_glow_lines = GLOW_MATERIAL.duplicate()
	_glow_lines.set_shader_parameter("ribbon_half", GLOW_RIBBON)
	_glow_drawing = DRAWING_LIGHT_MATERIAL.duplicate()
	_glow_drawing.set_shader_parameter("lines", DRAWING_GLOW.x)
	_glow_drawing.set_shader_parameter("blur", DRAWING_GLOW.y)
	_glow_drawing.set_shader_parameter("strength", DRAWING_GLOW.z)
	# A drawing is much bigger than the picture it is printed as.
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var inner := FRAME_INSET + FRAME_WIDTH * 0.5
	_picture.position = Vector2(inner + 6.0, TITLE_BOTTOM + 6.0)
	_picture.size = Vector2(SIZE.x - (inner + 6.0) * 2.0, FOOT_TOP - TITLE_BOTTOM - 12.0)
	_glow.position = _picture.position
	_glow.size = _picture.size
	_title.position = Vector2(inner, inner)
	_title.size = Vector2(SIZE.x - inner * 2.0, TITLE_BOTTOM - inner)
	_disc.position = Vector2(inner + 0.5, TITLE_BOTTOM + 2.0)
	_disc.size = Vector2(DISC, DISC) * 2.0
	_disc.draw.connect(_draw_disc)
	_text.position = Vector2(inner + 2.0, TITLE_BOTTOM + FACTOR_PICTURE + 6.0)
	_text.size = Vector2(SIZE.x - (inner + 2.0) * 2.0, FOOT_TOP - TITLE_BOTTOM - FACTOR_PICTURE - 8.0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_constant_override("line_spacing", -1)
	for label: Label in [_title, _chips, _tag, _text]:
		# Text too long even at the smallest size is cut off at its box, not printed over the frame.
		label.clip_text = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for child: Control in [_body, _glow, _picture, _lines, _disc, _title, _chips, _tag, _text]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
		if child == _lines:
			# The split lies over the lines (hidden while it shows) and under the writing.
			add_child(_split)
	_built = true
	_refresh()


## Gives every face of the card the base font `sharp` asks for.
func _set_faces() -> void:
	var base: Font = _sharp_base() if sharp else ThemeDB.fallback_font
	for face: FontVariation in [_upright, _slanted, _upright_narrow, _slanted_narrow, _upright_tight,
			_slanted_tight, _plain, _number]:
		face.base_font = base


## The engine's font, drawn from distance fields (made the first time it is asked for).
static func _sharp_base() -> Font:
	if _sharp_face == null:
		var face := ThemeDB.fallback_font
		if face is FontFile:
			var copy := (face as FontFile).duplicate() as FontFile
			copy.multichannel_signed_distance_field = true
			face = copy
		_sharp_face = face
	return _sharp_face


## Shows one card of RulesView.table().hand: {id, t, key, ink, name, chips, text, ...}.
## `hyde_has_table` gives a Factor Hyde's look; its name and text already follow the stance.
func show_entry(entry: Dictionary, hyde_has_table: bool) -> void:
	card_id = entry.id
	rng_seed = int(entry.id) * 7 + 3
	show_face(entry.key, entry.ink or (entry.t == "factor" and hyde_has_table), entry.name,
			entry.chips, entry.text)


## Sets everything the face shows. `on_ink` is true for a card that looks like Hyde's.
func show_face(new_key: String, on_ink: bool, new_title: String, new_chips: int,
		new_text: String = "") -> void:
	var turned := _shown and on_ink and not ink
	key = new_key
	ink = on_ink
	title = new_title
	chips = new_chips
	text = new_text
	_shown = true
	_refresh()
	if turned and _stained() and is_inside_tree():
		_creep_stain()


## Shows a card from data shaped like one of RulesView.table().hand, {key, ink, name, chips,
## text}, with any of them left out. A card without a key has no picture.
func show_data(data: Dictionary, new_seed: int = rng_seed) -> void:
	rng_seed = new_seed
	show_face(data.get("key", ""), data.get("ink", false), data.get("name", ""),
			data.get("chips", 0), data.get("text", ""))


## Writes the card's chips anew without redrawing the rest of it: for a count from one value
## to another.
func set_chips(new_chips: int) -> void:
	chips = new_chips
	_chips.text = str(chips)


## Writes a short note in the card's foot, "" for none. One that `warns` is written in red.
func set_tag(tag: String, warns: bool = false) -> void:
	_tag.text = tag
	_tag_warns = warns
	_refresh_tag()


## Changes the card where it lies: it closes, `change` is called (to give it its new face),
## and it opens again. Without `animate` the change is made at once.
func change_face(change: Callable, animate: bool = true) -> void:
	if _change:
		_change.kill()
		scale.x = 1.0
	if not animate or not is_inside_tree():
		change.call()
		return
	if not ArenaPace.reduce_flashes:
		_play_split()
	_change = create_tween()
	_change.tween_property(self, "scale:x", 0.0, TURN_TIME).set_ease(Tween.EASE_IN)
	_change.tween_callback(change)
	_change.tween_property(self, "scale:x", 1.0, TURN_TIME).set_ease(Tween.EASE_OUT)


## Lets the card come into being where it lies.
func appear(animate: bool = true) -> void:
	if not animate or not is_inside_tree():
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)


## Takes the card away for good: it fades and is freed.
func leave(animate: bool = true) -> void:
	if not animate or not is_inside_tree():
		queue_free()
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	fade.tween_callback(queue_free)


func _refresh() -> void:
	if not _built:
		return
	var body := (INK_MATERIAL if ink and not face_down else PAPER_MATERIAL).duplicate() as ShaderMaterial
	body.set_shader_parameter("card_size", SIZE)
	body.set_shader_parameter("seed", float(rng_seed))
	body.set_shader_parameter("rim_colour", Palette.HYDE if ink else Palette.JEKYLL)
	body.set_shader_parameter("rim_strength", _rim)
	body.set_shader_parameter("stain", stain if _stained() else 0.0)
	body.set_shader_parameter("stain_shown", _stain_shown)
	_body.material = body

	for part: Control in [_title, _chips, _tag, _text]:
		part.visible = not face_down
	_show_lines()
	var drawn := _drawing() != null
	_picture.material = DRAWING_MATERIAL if drawn else _picture_lines
	_glow.material = _glow_drawing if drawn else _glow_lines
	_glow_lines.set_shader_parameter("glow_colour", _light())
	_disc.visible = not face_down
	_disc.queue_redraw()
	_text.visible = not face_down and text != ""

	var colour := Palette.CHALK
	_refresh_title()

	var inner := FRAME_INSET + FRAME_WIDTH * 0.5
	_chips.position = _disc.position
	_chips.size = _disc.size
	_chips.text = str(chips)
	_chips.add_theme_font_override("font", _number)
	# The chips are a value: drawn in the owner's light, like the lines.
	_chips.add_theme_color_override("font_color", _light())
	_fit(_chips, _number, 11, 4.0)

	_text.text = text
	_text.add_theme_font_override("font", _plain)
	_text.add_theme_color_override("font_color", colour)
	var text_size := 9
	while text_size > 6 and _plain.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER,
			_text.size.x, text_size).y > _text.size.y:
		text_size -= 1
	_text.add_theme_font_size_override("font_size", text_size)
	_refresh_tag()

	for line_material: ShaderMaterial in [_lines.material, _picture_lines]:
		line_material.set_shader_parameter("texel", TEXEL)
		line_material.set_shader_parameter("seed", float(rng_seed))
	_lines.queue_redraw()
	_picture.queue_redraw()
	_glow.queue_redraw()
	_body.queue_redraw()
	_set_rim(_rim)
	_reflection.queue_redraw()
	_reflection_drawing.queue_redraw()
	for copy: Node2D in _split.get_children():
		copy.queue_redraw()
		(copy.get_child(0) as Node2D).queue_redraw()


## The title, in its whole box or in as much of it as `strip` leaves showing.
func _refresh_title() -> void:
	if not _built:
		return
	var inner := FRAME_INSET + FRAME_WIDTH * 0.5
	var whole := SIZE.x - inner * 2.0
	var squeezed := strip > 0.0 and strip - inner < whole
	var font: Font = _slanted if ink else _upright
	if squeezed:
		font = _slanted_narrow if ink else _upright_narrow
	_title.size.x = maxf(16.0, strip - inner) if squeezed else whole
	_title.text = title if ink else title.to_upper()
	_title.add_theme_color_override("font_color", Palette.CHALK)
	var fits := _fit(_title, font, 14 if ink else 13, 2.0 if squeezed else 5.0, 8 if squeezed else 7)
	if squeezed and not fits:
		# Too long for its strip at a size that reads: two words go on two lines, and one
		# long word is drawn narrower still.
		if _title.text.count(" ") == 1:
			var longer := _title.text.get_slice(" ", 0)
			if _title.text.get_slice(" ", 1).length() > longer.length():
				longer = _title.text.get_slice(" ", 1)
			var both := _title.text.replace(" ", "\n")
			_title.text = longer
			fits = _fit(_title, font, 10, 2.0, 6)
			_title.text = both
		else:
			font = _slanted_tight if ink else _upright_tight
			fits = _fit(_title, font, 10, 2.0, 6)
	_title.add_theme_font_override("font", font)
	# A title too long for its strip is cut at its end, not at both ends.
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if fits else HORIZONTAL_ALIGNMENT_LEFT


## The tag, in the foot: beside the chips' box, or in the whole foot when the chips stand
## above, and in as much of it as `foot_strip` leaves showing.
func _refresh_tag() -> void:
	if not _built:
		return
	var inner := FRAME_INSET + FRAME_WIDTH * 0.5
	var left := inner
	var whole := SIZE.x - inner - left
	_tag.position = Vector2(left, FOOT_TOP)
	_tag.size = Vector2(whole, SIZE.y - inner - FOOT_TOP)
	if foot_strip > 0.0 and foot_strip - left < whole and foot_strip - left >= 28.0:
		_tag.size.x = foot_strip - left
	var colour := Palette.WARN if _tag_warns else Palette.CHALK
	_tag.add_theme_font_override("font", _plain)
	_tag.add_theme_color_override("font_color", colour)
	_fit(_tag, _plain, 11, 2.0)


## Gives a label the largest font size, from `largest` down to `smallest`, at which its text
## fits its box with `room` pixels to spare. False if it does not fit even at the smallest.
func _fit(label: Label, font: Font, largest: int, room: float, smallest: int = 7) -> bool:
	var font_size := largest
	while font_size > smallest and _width(label.text, font, font_size) > label.size.x - room:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	return _width(label.text, font, font_size) <= label.size.x - room


static func _width(words: String, font: Font, font_size: int) -> float:
	return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


## Eases the rim light up on a chosen card, in its owner's light, and down again.
func _light_rim() -> void:
	if _rim_tween:
		_rim_tween.kill()
	var target := 1.0 if chosen else 0.0
	if not is_inside_tree():
		_set_rim(target)
		return
	_rim_tween = create_tween()
	_rim_tween.tween_method(_set_rim, _rim, target, RIM_TIME).set_ease(Tween.EASE_OUT)


func _set_rim(value: float) -> void:
	_rim = value
	_set_body("rim_strength", _rim)
	_reflection.visible = _rim > 0.0 and not face_down
	(_reflection.material as ShaderMaterial).set_shader_parameter("strength", REFLECTION * _rim)
	(_reflection_drawing.material as ShaderMaterial).set_shader_parameter("strength", REFLECTION * _rim)


func _set_body(parameter: String, value: float) -> void:
	var body := _body.material as ShaderMaterial
	if body:
		body.set_shader_parameter(parameter, value)


## True for a card that carries the ink stain: a Root that is Hyde's, face up.
func _stained() -> bool:
	return ink and text == "" and not face_down


## The ink creeps in from its corner over a Root that has just become Hyde's. With "reduce
## flashes" the settled stain fades in instead.
func _creep_stain() -> void:
	if _stain_tween:
		_stain_tween.kill()
	_stain_tween = create_tween()
	var time := STAIN_TIME / ArenaPace.speed
	if ArenaPace.reduce_flashes:
		stain = 1.0
		_stain_tween.tween_method(_set_stain_shown, 0.0, 1.0, time)
	else:
		_set_stain_shown(1.0)
		stain = 0.0
		_stain_tween.tween_property(self, "stain", 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_stain_shown(value: float) -> void:
	_stain_shown = value
	_set_body("stain_shown", _stain_shown)


## The colour the card's lines and chips are drawn in: the light of the man whose stock it is,
## chalk grey on a card that cannot be played now, and a deeper blue on a card's back.
func _light() -> Color:
	if face_down:
		return Palette.JEKYLL_DEEP
	if dimmed:
		return Palette.CHALK_2
	return Palette.HYDE if ink else Palette.JEKYLL


## The chips' disc: dark, ringed in the owner's light, with a little of that light around it.
func _draw_disc() -> void:
	var centre := _disc.size * 0.5
	if not dimmed:
		for k in DISC_GLOW:
			var glow := _light()
			glow.a = 0.1 * (1.0 - float(k) / DISC_GLOW)
			_disc.draw_circle(centre, DISC + 1.0 + k, glow)
	_disc.draw_circle(centre, DISC, Palette.OUTLINE)
	_disc.draw_circle(centre, DISC - 0.75, _light(), false, 1.5, true)


func _draw_body() -> void:
	_body.draw_rect(Rect2(-Vector2(MARGIN, MARGIN), SIZE + Vector2(MARGIN, MARGIN) * 2.0), Color.WHITE)


## The face's edge: one thin line just inside the card's outline, in the owner's light let
## down into the stock. A card that cannot be played has none. On a back, the back's frame.
func _draw_lines() -> void:
	if dimmed and not face_down:
		return
	var pencil := Pencil.new(rng_seed)
	pencil.colour = _edge_colour()
	_lay_frame(pencil)
	pencil.draw(_lines)


## The colour of the face's edge: the owner's light, EDGE_LIGHT of the way up from the stock.
func _edge_colour() -> Color:
	if face_down:
		return _light()
	var stock := Palette.H_STOCK_LIGHT if ink else Palette.J_STOCK_LIGHT
	return stock.lerp(_light(), EDGE_LIGHT)


## Lays the frame out on `pencil`: the face's edge, or on a card's back, the back's lines.
func _lay_frame(pencil: Pencil) -> void:
	if not face_down:
		pencil.steady = true
		var edge := Rect2(Vector2(EDGE_INSET, EDGE_INSET), SIZE - Vector2(EDGE_INSET, EDGE_INSET) * 2.0)
		pencil.stroke(PackedVector2Array([edge.position, Vector2(edge.end.x, edge.position.y),
				edge.end, Vector2(edge.position.x, edge.end.y), edge.position]), EDGE_WIDTH, 0.0)
		return
	var inset := Vector2(FRAME_INSET, FRAME_INSET)
	var rect := Rect2(inset, SIZE - inset * 2.0)
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		_rule(pencil, corners[i], corners[(i + 1) % 4], FRAME_WIDTH)
	_draw_back(pencil, rect)


## The back of a card: a second frame inside the first, crossed by slanting lines both ways.
func _draw_back(pencil: Pencil, rect: Rect2) -> void:
	var inner := rect.grow(-6.0)
	var corners := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
			Vector2(inner.position.x, inner.end.y)]
	for i in 4:
		_rule(pencil, corners[i], corners[(i + 1) % 4], 1.4)
	var step := 14.0
	var k := step
	while k < inner.size.x + inner.size.y:
		# One line down to the left and its mirror image down to the right.
		var from := Vector2(minf(k, inner.size.x), maxf(0.0, k - inner.size.x))
		var to := Vector2(maxf(0.0, k - inner.size.y), minf(k, inner.size.y))
		pencil.stroke(PackedVector2Array([inner.position + from, inner.position + to]), 0.9, 0.3, 0.0)
		pencil.stroke(PackedVector2Array([inner.position + Vector2(inner.size.x - from.x, from.y),
				inner.position + Vector2(inner.size.x - to.x, to.y)]), 0.9, 0.3, 0.0)
		k += step


## The card's picture, from ArenaCardPictures. A Factor's is small, to leave room for its text.
func _draw_picture() -> void:
	if _drawing():
		_draw_drawing(_picture, Vector2.ZERO, _light())
		return
	var pencil := Pencil.new(rng_seed + 5)
	pencil.colour = _light()
	_add_picture(pencil)
	pencil.draw(_picture)


## The picture's halo: its strokes again, under the printed ones, as soft lines
## (shaders/card_picture.gdshader): once in place, and in rings of fainter copies around it
## (GLOW_RINGS), which add up to a smooth light.
func _draw_glow() -> void:
	if _drawing():
		_draw_drawing(_glow, Vector2.ZERO, _light())
		return
	var item := _glow.get_canvas_item()
	var rings: Array[Vector2] = [Vector2(0.0, 0.45)]
	rings.append_array(GLOW_RINGS)
	for ring: Vector2 in rings:
		var pencil := Pencil.new(rng_seed + 5)
		pencil.colour = Color(ring.y, ring.y, ring.y)
		pencil.half_width = GLOW_RIBBON
		_add_picture(pencil)
		var turns := 1 if ring.x == 0.0 else GLOW_COPIES
		for k in turns:
			var offset := Vector2.from_angle(TAU * k / turns) * ring.x
			RenderingServer.canvas_item_add_set_transform(item, Transform2D(0.0, offset))
			pencil.draw(_glow)
	RenderingServer.canvas_item_add_set_transform(item, Transform2D.IDENTITY)


## The card comes apart into three copies of its lines, in the split's three colours, which
## slide away from each other and snap back: the shift, on one card.
func _play_split() -> void:
	if _split_tween:
		_split_tween.kill()
	_split_tween = create_tween()
	_split_tween.tween_method(_set_apart, 0.0, 1.0, SPLIT_TIME)


## `k` runs 0 to 1 through the split: the copies fly apart quickly and come back more slowly.
func _set_apart(k: float) -> void:
	_apart = 0.0 if k >= 1.0 else sin(PI * pow(k, 0.6))
	var copies := _split.get_children()
	for i in copies.size():
		(copies[i] as Node2D).position = SPLIT_WAYS[i] * SPLIT_REACH * _apart
	_show_lines()


## Shows the printed lines, or the split's copies of them while the card is apart.
func _show_lines() -> void:
	var whole := _apart <= 0.0
	_split.visible = not whole
	_lines.visible = whole
	_picture.visible = whole and not face_down
	_glow.visible = whole and not face_down and not dimmed


## The reflection: the frame and the picture in the owner's light, drawn the right way up in
## the card's own place (the node mirrors them under the card).
func _draw_reflection() -> void:
	_draw_copy(_reflection, _light())


## Draws the card's frame and picture again on `item`, in `colour`, in the card's own place.
func _draw_copy(item: CanvasItem, colour: Color) -> void:
	var frame := Pencil.new(rng_seed)
	frame.colour = colour
	_lay_frame(frame)
	frame.draw(item)
	if face_down:
		return
	var picture := Pencil.new(rng_seed + 5)
	picture.colour = colour
	_add_picture(picture, _picture.position)
	picture.draw(item)


## Lays the card's picture out on `pencil`, its box's corner at `at`. Nothing for a picture
## that is a drawing: `_draw_drawing` draws that.
func _add_picture(pencil: Pencil, at: Vector2 = Vector2.ZERO) -> void:
	# A Factor has one picture for both men: its look says whose it is.
	pencil.steady = true
	ArenaCardPictures.add(pencil, ArenaCardPictures.picture_of(key, ink), _picture_box(at), PICTURE_WIDTH)


## The box the card's picture is fitted in, the picture's own box's corner at `at`. A Factor's
## is small, to leave room for its text.
func _picture_box(at: Vector2) -> Rect2:
	var box := Rect2(at, _picture.size)
	if text != "":
		box.size.y = FACTOR_PICTURE
	return box.grow(-2.0)


## The card's picture if it is a drawing, or null.
func _drawing() -> Texture2D:
	return ArenaCardPictures.drawing(ArenaCardPictures.picture_of(key, ink))


## Draws the card's picture on `item` in `colour` if it is a drawing and the card shows its
## face, the picture's own box's corner at `at`.
func _draw_drawing(item: CanvasItem, at: Vector2, colour: Color) -> void:
	var drawing := _drawing()
	if drawing and not face_down:
		var box := _picture_box(at)
		if text != "":
			box = box.grow_individual((FACTOR_DRAWING_WIDTH - box.size.x) * 0.5, 0.0,
					(FACTOR_DRAWING_WIDTH - box.size.x) * 0.5, 0.0)
		item.draw_texture_rect(drawing, ArenaCardPictures.drawing_box(drawing, box), false, colour)


## Gives `copy` (the reflection, or one of the split's copies) the node `drawn` to draw a
## picture that is a drawing on, as light, in `colour`: the owner's light when it is clear.
func _add_drawn_copy(copy: Node2D, drawn: Node2D, light: ShaderMaterial, colour: Color) -> void:
	drawn.material = light
	drawn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	drawn.draw.connect(func() -> void:
		_draw_drawing(drawn, _picture.position, _light() if colour.a == 0.0 else colour))
	copy.add_child(drawn)


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
