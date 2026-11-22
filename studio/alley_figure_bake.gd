extends Node
## Bakes the figure layer of the back-alley picture: the man at the door, standing still.
## Desktop only; run with Forward+ (tools/bake_alley.sh runs it after the alley's own bake):
##
##   art/bg/alley_figure.png        drawing data in RGB (see studio/figure_data.gdshaderinc)
##                                  and how much of the pixel the figure covers in A
##   art/bg/alley_figure_depth.png  how far the figure is from the camera, at half the size
##
## The same kind of layer the title has (studio/title_figure_bake.gd), with one picture on the
## sheet: the game draws it over the baked alley with shaders/background.gdshader. The camera, the lamps
## and the figure are read from studio/alley.tscn, and the part of the picture the layer covers
## from AlleyBackground.FIGURE_RECT: re-bake after changing any of them.

const FigureBake := preload("res://studio/figure_bake.gd")
const FULL := Vector2(1920.0, 1080.0) # size the alley is baked at
const OUT := "res://art/bg/alley_figure.png"
const OUT_DEPTH := "res://art/bg/alley_figure_depth.png"

var _viewport: SubViewport
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_setup()
	var px := AlleyBackground.FIGURE_PX
	var img := await _draw(px, false)
	if FigureBake._touches_edge(img):
		push_warning("the figure reaches the edge of AlleyBackground.FIGURE_RECT: move or enlarge it")
	img.save_png(OUT)
	(await _draw(px / 2, true)).save_png(OUT_DEPTH)
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

	var alley: Node3D = (load("res://studio/alley.tscn") as PackedScene).instantiate()
	var alley_cam := alley.get_node("Camera") as Camera3D
	var tan_y := tan(deg_to_rad(alley_cam.fov) * 0.5)
	var tan_x := tan_y * FULL.x / FULL.y
	var rect := AlleyBackground.FIGURE_RECT

	# A camera that sees only FIGURE_RECT of the alley camera's picture.
	var cam := Camera3D.new()
	_viewport.add_child(cam)
	cam.transform = FigureBake._in_scene(alley_cam, alley)
	var centre := (rect.get_center() * 2.0 - Vector2.ONE) * Vector2(1.0, -1.0)
	var near := 0.1
	cam.set_frustum(2.0 * near * tan_y * rect.size.y, centre * Vector2(tan_x, tan_y) * near, near, 100.0)

	# The man: taken out of the alley, standing where he stood.
	var figure := alley.get_node("Hyde") as Node3D
	var xf := FigureBake._in_scene(figure, alley)
	figure.get_parent().remove_child(figure)
	figure.owner = null
	_viewport.add_child(figure)
	figure.transform = xf
	for body: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
		var mat := (body.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		body.material_override = mat
		mat.set_shader_parameter("data_pass", true)
		mat.set_shader_parameter("street", 0.0) # the shader's first set of lamps
		mat.set_shader_parameter("depth_range", AlleyBackground.FIGURE_DEPTH_RANGE)
		for group: String in ["key", "wall"]:
			var lamps := FigureBake._lamps(alley, "pass_" + group, xf.origin + Vector3.UP)
			mat.set_shader_parameter(group + "_lamps_jekyll", lamps[0])
			mat.set_shader_parameter(group + "_energy_jekyll", lamps[1])
		_materials.append(mat)
	alley.free()


## The figure, `px` pixels square: its drawing data and coverage, or its depth.
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
