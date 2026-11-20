extends Node
## Bakes the figure layer: the two men standing still and the flipbook of Jekyll turning into
## Hyde. Desktop only; run with Forward+:
##
##   tools/bake_figures.sh [--frames=/abs/dir] [--time=0.7]
##
## The streets are baked with nobody in them (studio/bake.gd); this layer is drawn over them by
## shaders/background.gdshader. It writes two sheets with the same layout:
##
##   art/bg/figures.png        drawing data in RGB (see studio/figure_data.gdshaderinc) and
##                             how much of the pixel the figure covers in A
##   art/bg/figures_depth.png  how far the figure is from the camera, at half the size
##
## The flipbook frames come first, left to right, top to bottom: Jekyll flowing into Hyde (the
## game plays them backwards for the change back). Under them is a row with Jekyll and then Hyde
## standing still, at the full size of the street bake.
##
## The still men are the meshes in the street scenes. The frames are drawn by
## studio/morph.gdshader from the two figures' distance fields (studio/figure_sdf.gd; the first
## run builds them, which takes about half a minute). The moves and their timing are parameters
## of that shader: change them on `MOVES` below.
##
## The camera, the lamps and where the two figures stand are read from
## studio/street_jekyll.tscn and studio/street_hyde.tscn, so the layer lines up with the baked
## streets and is lit by their lamps: re-bake it after changing any of those, and after
## replacing a figure model.
## `--frames` also writes every picture as its own PNG; `--time` bakes nothing and writes the
## one flipbook frame at that many seconds to the `--frames` folder, for trying settings quickly.

const FULL := Vector2(1920.0, 1080.0) # size the streets are baked at
const OUT := "res://art/bg/figures.png"
const OUT_DEPTH := "res://art/bg/figures_depth.png"
const SUPERSAMPLE := 2 # flipbook frames are drawn this many times larger and shrunk
const MAX_LAMPS := 8 # as in studio/figure_data.gdshaderinc
const DURATION := Background.MORPH_FRAMES / Background.MORPH_FPS # seconds the change takes

## Overrides for the `moves` parameters of studio/morph.gdshader, e.g. { "swell": 0.09 }.
const MOVES := {}

var _viewport: SubViewport
var _clay: MeshInstance3D # the changing figure
var _stills := {} # "jekyll" / "hyde" -> the figure from that street
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	var px := Background.MORPH_FRAME_PX
	var still_px := Background.FIGURE_STILL_PX
	var grid := Background.MORPH_GRID
	_setup()
	var dump := Shot.arg("frames")
	if Shot.has_arg("time"):
		_show(_clay)
		(await _draw(float(Shot.arg("time")), px, false)).save_png(dump.path_join("morph_time.png"))
		get_tree().quit()
		return

	var sheet := Image.create(maxi(px * grid.x, still_px * 2), px * grid.y + still_px, false,
			Image.FORMAT_RGBA8)
	var depth_sheet := Image.create(sheet.get_width() / 2, sheet.get_height() / 2, false,
			Image.FORMAT_L8)
	_show(_clay)
	for f in Background.MORPH_FRAMES:
		var at := Vector2i(f % grid.x, f / grid.x) * px
		# The first frame is Jekyll untouched and the last is Hyde.
		var seconds := f * DURATION / (Background.MORPH_FRAMES - 1)
		var img := await _draw(seconds, px, false)
		if _touches_edge(img):
			push_warning("frame %d reaches the edge of Background.FIGURE_RECT: make it larger" % f)
		if dump != "":
			img.save_png(dump.path_join("morph_%02d.png" % f))
		sheet.blit_rect(img, Rect2i(0, 0, px, px), at)
		var depth := await _draw(seconds, px / 2, true)
		depth_sheet.blit_rect(depth, Rect2i(0, 0, px / 2, px / 2), at / 2)
	var column := 0
	for fig: String in ["jekyll", "hyde"]:
		_show(_stills[fig])
		var at := Vector2i(column * still_px, px * grid.y)
		var img := await _draw(0.0, still_px, false)
		if dump != "":
			img.save_png(dump.path_join(fig + ".png"))
		sheet.blit_rect(img, Rect2i(0, 0, still_px, still_px), at)
		var depth := await _draw(0.0, still_px / 2, true)
		depth_sheet.blit_rect(depth, Rect2i(0, 0, still_px / 2, still_px / 2), at / 2)
		column += 1
	sheet.save_png(OUT)
	depth_sheet.save_png(OUT_DEPTH)
	print("baked ", OUT, ": ", Background.MORPH_FRAMES, " frames and 2 stills")
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
	for fig: String in ["jekyll", "hyde"]:
		streets[fig] = (load("res://studio/street_%s.tscn" % fig) as PackedScene).instantiate()
	var street_cam := (streets.jekyll as Node3D).get_node("Camera") as Camera3D
	var cam_xf := _in_scene(street_cam, streets.jekyll)
	var tan_y := tan(deg_to_rad(street_cam.fov) * 0.5)
	var tan_x := tan_y * FULL.x / FULL.y
	var rect := Background.FIGURE_RECT

	# A camera that sees only FIGURE_RECT of the street camera's picture.
	var cam := Camera3D.new()
	_viewport.add_child(cam)
	cam.transform = cam_xf
	var centre := (rect.get_center() * 2.0 - Vector2.ONE) * Vector2(1.0, -1.0)
	var near := 0.1
	cam.set_frustum(2.0 * near * tan_y * rect.size.y, centre * Vector2(tan_x, tan_y) * near, near, 100.0)

	# The still men: taken out of their streets, standing where they stood.
	var xf := {}
	for fig: String in ["jekyll", "hyde"]:
		var street: Node3D = streets[fig]
		var node := street.get_node("Hyde" if fig == "hyde" else "Jekyll") as Node3D
		xf[fig] = _in_scene(node, street)
		node.get_parent().remove_child(node)
		node.owner = null
		_viewport.add_child(node)
		node.transform = xf[fig]
		_stills[fig] = node
		for body: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var mat := (body.material_override as ShaderMaterial).duplicate() as ShaderMaterial
			body.material_override = mat
			mat.set_shader_parameter("data_pass", true)
			mat.set_shader_parameter("street", 1.0 if fig == "hyde" else 0.0)
			_materials.append(mat)

	# The changing figure: a sheet over the whole picture, drawn by the morph shader.
	var clay_mat := ShaderMaterial.new()
	clay_mat.shader = load("res://studio/morph.gdshader")
	_materials.append(clay_mat)
	_clay = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_clay.mesh = quad
	_clay.material_override = clay_mat
	_clay.custom_aabb = AABB(Vector3.ONE * -1e4, Vector3.ONE * 2e4) # never culled
	_viewport.add_child(_clay)
	clay_mat.set_shader_parameter("camera", cam_xf)
	clay_mat.set_shader_parameter("view_tan", Vector2(tan_x, tan_y))
	clay_mat.set_shader_parameter("crop", rect)
	clay_mat.set_shader_parameter("jekyll_from_world", (xf.jekyll as Transform3D).affine_inverse())
	clay_mat.set_shader_parameter("hyde_from_world", (xf.hyde as Transform3D).affine_inverse())
	clay_mat.set_shader_parameter("hyde_scale", (xf.hyde as Transform3D).basis.get_scale().y)
	clay_mat.set_shader_parameter("duration", DURATION)
	var field_j := FigureSdf.load_or_build("jekyll")
	var field_h := FigureSdf.load_or_build("hyde")
	clay_mat.set_shader_parameter("jekyll_field", field_j.texture)
	clay_mat.set_shader_parameter("jekyll_box_pos", field_j.box.position)
	clay_mat.set_shader_parameter("jekyll_box_size", field_j.box.size)
	clay_mat.set_shader_parameter("hyde_field", field_h.texture)
	clay_mat.set_shader_parameter("hyde_box_pos", field_h.box.position)
	clay_mat.set_shader_parameter("hyde_box_size", field_h.box.size)
	# A ball round both figures, with room for the swelling.
	var both: AABB = ((xf.jekyll as Transform3D) * (field_j.box as AABB)).merge(
			(xf.hyde as Transform3D) * (field_h.box as AABB))
	clay_mat.set_shader_parameter("bounds", Vector4(both.get_center().x, both.get_center().y,
			both.get_center().z, both.size.length() * 0.5 + 0.3))
	for move: String in MOVES:
		clay_mat.set_shader_parameter(move, MOVES[move])

	# Every material is lit by both streets' lamps (the shaders pick or blend).
	for fig: String in ["jekyll", "hyde"]:
		for group: String in ["key", "wall"]:
			var lamps := _lamps(streets[fig], "pass_" + group, (xf[fig] as Transform3D).origin + Vector3.UP)
			for mat in _materials:
				mat.set_shader_parameter("%s_lamps_%s" % [group, fig], lamps[0])
				mat.set_shader_parameter("%s_energy_%s" % [group, fig], lamps[1])
	for mat in _materials:
		mat.set_shader_parameter("depth_range", Background.FIGURE_DEPTH_RANGE)
	for fig: String in streets:
		(streets[fig] as Node).free()


## The lamps of `street` in `group` nearest to `near`: [places and reaches, brightnesses],
## padded to MAX_LAMPS.
func _lamps(street: Node3D, group: String, near: Vector3) -> Array:
	var found: Array[Dictionary] = []
	for light: OmniLight3D in street.find_children("*", "OmniLight3D", true, false):
		if light.is_in_group(group):
			var at := _in_scene(light, street).origin
			found.append({"at": at, "reach": light.omni_range, "energy": light.light_energy,
					"far": at.distance_to(near)})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.far < b.far)
	var places := PackedVector4Array()
	var energies := PackedFloat32Array()
	for i in MAX_LAMPS:
		if i < found.size():
			var at: Vector3 = found[i].at
			places.append(Vector4(at.x, at.y, at.z, found[i].reach))
			energies.append(found[i].energy)
		else:
			places.append(Vector4(0.0, 0.0, 0.0, 1.0))
			energies.append(0.0)
	return [places, energies]


## Leaves only `node` of the figures visible.
func _show(node: Node3D) -> void:
	_clay.visible = node == _clay
	for fig: String in _stills:
		(_stills[fig] as Node3D).visible = node == _stills[fig]


## The visible figure, `px` pixels square: its drawing data and coverage, or its depth. For the
## changing figure, at `seconds` into the change.
func _draw(seconds: float, px: int, depth: bool) -> Image:
	_viewport.size = Vector2i.ONE * px * (SUPERSAMPLE if _clay.visible else 1)
	for mat in _materials:
		mat.set_shader_parameter("depth_pass", depth)
	_clay.material_override.set_shader_parameter("time", seconds)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if depth:
		img.srgb_to_linear() # the viewport encodes colour; depth is a plain number
	if img.get_width() != px:
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	if depth:
		img.convert(Image.FORMAT_L8)
	return img


## Whether the figure runs off the left, top or right of the frame (the bottom always does).
func _touches_edge(img: Image) -> bool:
	var last := img.get_width() - 1
	for i in img.get_width():
		if img.get_pixel(i, 0).a > 0.05 or img.get_pixel(0, i).a > 0.05 or img.get_pixel(last, i).a > 0.05:
			return true
	return false


func _in_scene(node: Node3D, scene: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != scene and cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
