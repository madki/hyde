extends Node
## Bakes the figure layer of the title screen: Jekyll and Hyde standing still, further up the
## street than in the game, so that they are seen down to their feet. Desktop only; run with
## Forward+ (tools/bake_title.sh runs it after the title's streets):
##
##   art/bg/title_figures.png        drawing data in RGB (see studio/figure_data.gdshaderinc)
##                                   and how much of the pixel the figure covers in A
##   art/bg/title_figures_depth.png  how far the figure is from the camera, at half the size
##
## The same layer the streets have (studio/figure_bake.gd), with two pictures on the sheet:
## Jekyll, then Hyde. The game draws them over the baked streets with
## shaders/background.gdshader. The camera and the lamps are read from
## studio/street_jekyll.tscn and studio/street_hyde.tscn, where the men stand from
## studio/title_street.gd, and the part of the picture the layer covers from
## TitleBackground.FIGURE_RECT: re-bake after changing any of them.
## `--frames=/abs/dir` also writes each man as his own PNG.

const FigureBake := preload("res://studio/figure_bake.gd")
const FULL := Vector2(1920.0, 1080.0) # size the streets are baked at
const OUT := "res://art/bg/title_figures.png"
const OUT_DEPTH := "res://art/bg/title_figures_depth.png"

var _viewport: SubViewport
var _men := {} # "jekyll" / "hyde" -> the figure
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_setup()
	var px := TitleBackground.FIGURE_PX
	var sheet := Image.create(px * 2, px, false, Image.FORMAT_RGBA8)
	var depth_sheet := Image.create(px, px / 2, false, Image.FORMAT_L8)
	var column := 0
	for man: String in TitleStreet.MEN:
		for other: String in _men:
			(_men[other] as Node3D).visible = other == man
		var img := await _draw(px, false)
		if FigureBake._touches_edge(img):
			push_warning("%s reaches the edge of TitleBackground.FIGURE_RECT: move or enlarge it" % man)
		var used := img.get_used_rect()
		var corner := TitleBackground.FIGURE_RECT.position * FULL
		print(man, " covers ", Rect2(corner + Vector2(used.position), used.size), " of the bake")
		if Shot.arg("frames") != "":
			img.save_png(Shot.arg("frames").path_join("title_%s.png" % man))
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(column * px, 0))
		var depth := await _draw(px / 2, true)
		depth_sheet.blit_rect(depth, Rect2i(0, 0, px / 2, px / 2), Vector2i(column * px / 2, 0))
		column += 1
	var feet := (_viewport.get_camera_3d().unproject_position(TitleStreet.STAND) / float(_viewport.size.x)
			* TitleBackground.FIGURE_RECT.size + TitleBackground.FIGURE_RECT.position) * FULL
	print("they stand at ", feet, " of the bake: TitleBackground.FEET")
	sheet.save_png(OUT)
	depth_sheet.save_png(OUT_DEPTH)
	print("baked ", OUT)
	get_tree().quit()


func _setup() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var streets := {}
	for man: String in TitleStreet.MEN:
		var street: Node3D = (load("res://studio/street_%s.tscn" % man) as PackedScene).instantiate()
		# The lamp that lights the mist behind the game's figure is not one of the street's own:
		# from here it would shine on these men's fronts.
		var backlight := street.get_node_or_null("FigureBacklight")
		if backlight:
			backlight.free()
		streets[man] = street
	var street_cam := (streets.jekyll as Node3D).get_node("Camera") as Camera3D
	var tan_y := tan(deg_to_rad(street_cam.fov) * 0.5)
	var tan_x := tan_y * FULL.x / FULL.y
	var rect := TitleBackground.FIGURE_RECT

	# A camera that sees only FIGURE_RECT of the street camera's picture.
	var cam := Camera3D.new()
	_viewport.add_child(cam)
	cam.transform = FigureBake._in_scene(street_cam, streets.jekyll)
	var centre := (rect.get_center() * 2.0 - Vector2.ONE) * Vector2(1.0, -1.0)
	var near := 0.1
	cam.set_frustum(2.0 * near * tan_y * rect.size.y, centre * Vector2(tan_x, tan_y) * near, near, 100.0)

	for man: String in TitleStreet.MEN:
		var figure := TitleStreet.figure(man)
		_viewport.add_child(figure)
		_men[man] = figure
		for body: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
			var mat := body.material_override as ShaderMaterial
			mat.set_shader_parameter("data_pass", true)
			mat.set_shader_parameter("street", 1.0 if man == "hyde" else 0.0)
			mat.set_shader_parameter("depth_range", TitleBackground.FIGURE_DEPTH_RANGE)
			_materials.append(mat)
	# Every material is given both streets' lamps; each man is lit by his own street's.
	for street: String in streets:
		for group: String in ["key", "wall"]:
			var lamps := FigureBake._lamps(streets[street], "pass_" + group, TitleStreet.STAND + Vector3.UP)
			for mat in _materials:
				mat.set_shader_parameter("%s_lamps_%s" % [group, street], lamps[0])
				mat.set_shader_parameter("%s_energy_%s" % [group, street], lamps[1])
		(streets[street] as Node).free()


## The visible man, `px` pixels square: his drawing data and coverage, or his depth.
func _draw(px: int, depth: bool) -> Image:
	_viewport.size = Vector2i.ONE * px
	for mat in _materials:
		mat.set_shader_parameter("depth_pass", depth)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if depth:
		img.srgb_to_linear() # the viewport encodes colour; depth is a plain number
		img.convert(Image.FORMAT_L8)
	return img
