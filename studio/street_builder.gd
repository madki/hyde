class_name StreetBuilder
## Generates the two 3D street scenes the game background is baked from:
## studio/street_jekyll.tscn and studio/street_hyde.tscn (see studio/bake.gd).
## Those scenes are the source of truth and are meant to be edited in the 3D editor;
## this script only makes a fresh starting point (`tools/bake_bg.sh --rebuild` OVERWRITES them).
## Desktop-only authoring code: nothing in studio/ is exported with the game.
##
## Everything that emits light belongs to one pass group ("pass_key", "pass_wall",
## "pass_windows", "pass_ambient") so the baker can render each contribution on its own.

const ASSETS := "res://studio/assets/"
const KIT := ASSETS + "modular_urban_apartments_facade/modular_urban_apartments_facade.gltf"
const POST_LAMP := ASSETS + "street_lamp_01/street_lamp_01.gltf"
const WALL_LAMP := ASSETS + "street_lamp_02/street_lamp_02.gltf"
const CHEMISTRY := ASSETS + "chemistry_set/chemistry_set.gltf"
const COBBLES := ASSETS + "cobblestone_floor_04/cobblestone_floor_04_"
const KIT_DIR := "res://studio/kit/" # facade pieces saved as their own mesh files

const MODULE := 3.0 # width and height of one facade module, in metres
const BASE_H := 0.75
const CORNICE_H := 0.2
const CROWN_H := 0.75

# Both faces are seen from the same spot, so the shift changes the mood, not the view.
# Chest height, close to the right-hand wall, turned a little towards it and tilted up about
# 10 degrees through a fairly long lens: the figure shows down to the knees, the wall's lines
# run down to a vanishing point low on the left, and uprights only lean gently.
const CAM_POS := Vector3(1.17, 1.2, 5.63)
const CAM_TARGET := Vector3(3.52, 2.94, -3.93)
const CAM_FOV := 46.0
const FIGURE_POS := Vector3(2.0, 0.0, 2.63) # the man himself, close to the camera
# The key lamp stands across the street from the lit wall, behind the figure, a little larger
# than life.
const KEY_LAMP_SCALE := 1.28
const KEY_LAMP_POS := Vector3(-1.0, 0.0, -2.0)
const WALL_LAMP_SCALE := 1.1
const WALL_LAMP_H := 1.9 # bracket height of the wall lanterns: flames just above head height


## Camera placement and scene dressing for each face of the street.
static func variant(name: String) -> Dictionary:
	if name == "hyde":
		return {
			"cam_pos": CAM_POS, "cam_target": CAM_TARGET,
			"cam_roll": 0.0, "fov": CAM_FOV,
			"lit_windows": 0.06, "glassware": true, "post_lean": 0.0,
			# He stands exactly where Jekyll stands: one man turns into the other on the spot.
			# His model is the taller of the two and he leans towards the camera, so he is
			# scaled down to look no bigger than Jekyll.
			"figure_offset": Vector3.ZERO, "figure_scale": 0.88,
		}
	return {
		"cam_pos": CAM_POS, "cam_target": CAM_TARGET,
		"cam_roll": 0.0, "fov": CAM_FOV,
		"lit_windows": 0.3, "glassware": false, "post_lean": 0.0,
		# Hyde leans in towards the camera and Jekyll's stick pushes his middle off his feet, so
		# Jekyll is stood a step aside and a touch smaller to put his head where Hyde's is.
		"figure_offset": Vector3(0.194, 0.0, 0.048), "figure_scale": 0.985,
	}


static func build(variant_name: String) -> Node3D:
	var v := variant(variant_name)
	var root := Node3D.new()
	root.name = "Street"
	var kit := _kit_meshes()

	var ground := _ground()
	ground.name = "Ground"
	root.add_child(ground)

	# Right-hand terrace: the wall the lanterns hang on. Runs away from the camera.
	var right := _terrace(kit, [2, 3, 2, 3, 2, 2], 11, v.lit_windows, true)
	right.name = "RightTerrace"
	right.rotation.y = -PI / 2.0
	right.position = Vector3(4.36, 0.0, -46.5) # nearest lantern sits behind the figure
	root.add_child(right)

	# The other side of the street and its far end are left open: only dark sky and mist there,
	# so the lit wall and the lamps carry the picture.

	# The key lamp: tall post on the far kerb.
	var key := _post_lamp("pass_key", KEY_LAMP_SCALE, 22.0, 1.5)
	key.name = "KeyLamp"
	key.position = KEY_LAMP_POS
	key.rotation = Vector3(0.0, deg_to_rad(45.0), v.post_lean) # lantern corner-on to the camera
	root.add_child(key)

	# One far post lamp on the left kerb belongs with the wall lanterns.
	var far := _post_lamp("pass_wall", 1.25, 14.0, 1.2)
	far.name = "FarLamp"
	far.position = Vector3(-1.0, 0.0, -15.7)
	root.add_child(far)

	var figure := FigureBuilder.build(variant_name)
	figure.position = FIGURE_POS + v.figure_offset
	# Jekyll stands side on, his stick on the near side, and looks back at the camera over his
	# shoulder; Hyde comes at it a little side on.
	figure.rotation.y = deg_to_rad(30.0 if variant_name == "jekyll" else 25.0)
	figure.scale = Vector3.ONE * v.figure_scale
	root.add_child(figure)
	# A lamp behind him lights the mist he stands against, so the silhouette reads.
	var back := OmniLight3D.new()
	back.name = "FigureBacklight"
	back.position = FIGURE_POS + Vector3(-0.3, 1.5, -1.4)
	back.omni_range = 4.5
	back.light_energy = 0.9
	back.light_volumetric_fog_energy = 0.6
	back.shadow_enabled = true
	back.add_to_group("pass_wall" if variant_name == "hyde" else "pass_key", true)
	root.add_child(back)
	if v.glassware:
		var glass := _glassware()
		glass.name = "Glassware"
		root.add_child(glass)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = v.fov
	cam.far = 200.0
	root.add_child(cam)
	cam.look_at_from_position(v.cam_pos, v.cam_target)
	cam.rotate_object_local(Vector3.FORWARD, v.cam_roll)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(140.0), 0.0)
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.add_to_group("pass_ambient", true)
	root.add_child(moon)
	_own(root, root)
	_lamp_layers(root, root)
	return root


## Facade pieces by name.
static func _kit_meshes() -> Dictionary:
	var scene: Node = (load(KIT) as PackedScene).instantiate()
	var out := {}
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		out[String(mi.name)] = mi.mesh
	scene.free()
	return out


## Makes every generated node part of the scene being saved. Nodes that came with an
## instanced model keep belonging to that model.
static func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = root
			_own(child, root)


static func _piece(kit: Dictionary, parent: Node3D, piece: String, pos: Vector3) -> void:
	if not kit.has(piece):
		push_warning("facade kit has no piece " + piece)
		return
	var mi := MeshInstance3D.new()
	# Each piece used is saved once as its own mesh file, so the street scenes reference it
	# instead of embedding the geometry.
	var path := KIT_DIR + piece + ".res"
	if not ResourceLoader.exists(path):
		DirAccess.make_dir_recursive_absolute(KIT_DIR)
		ResourceSaver.save(kit[piece], path)
	mi.mesh = load(path)
	# The kit's plaster becomes brick.
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i)
		if mat and mat.resource_name.ends_with("plaster"):
			mi.set_surface_override_material(i, _brick())
	mi.name = piece
	mi.position = pos
	parent.add_child(mi, true)


## One shared brick material (studio/brick.gdshader), saved as its own file so the street
## scenes reference it and it can be tuned in the editor.
static func _brick() -> ShaderMaterial:
	var path := KIT_DIR + "brick_material.tres"
	if not ResourceLoader.exists(path):
		var m := ShaderMaterial.new()
		m.shader = load("res://studio/brick.gdshader")
		DirAccess.make_dir_recursive_absolute(KIT_DIR)
		ResourceSaver.save(m, path)
	return load(path)


static func _flat(color: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func _glow() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.WHITE
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.name = "Box"
	parent.add_child(mi, true)
	return mi


## A row of townhouses, three modules wide each. Local space: runs along +X, faces +Z.
## `floors` holds the number of storeys of each house.
static func _terrace(kit: Dictionary, floors: Array, seed_value: int, lit: float,
		lanterns: bool) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var row := Node3D.new()
	var dark := _flat(Color(0.05, 0.05, 0.05))
	var slate := _flat(Color(0.16, 0.16, 0.17), 0.6)
	var brick := _flat(Color(0.3, 0.27, 0.25))
	var styles := ["centered_large", "centered_double", "centered_small"]
	for h in floors.size():
		var house := Node3D.new()
		house.name = "House%d" % h
		house.position.x = h * MODULE * 3.0
		row.add_child(house)
		var storeys: int = floors[h]
		var style: String = styles[rng.randi() % styles.size()]
		var door_col := rng.randi() % 3
		var top := BASE_H + MODULE + CORNICE_H + (storeys - 1) * MODULE
		for c in 3:
			var x := (c + 1) * MODULE
			_piece(kit, house, "base_standard_01", Vector3(x, 0.0, 0.0))
			var y := BASE_H
			if c == door_col:
				_piece(kit, house, "wall_door_centered_small_01", Vector3(x, y, 0.0))
				_piece(kit, house, "door_centered_small_01", Vector3(x, y, 0.0))
				_piece(kit, house, "dado_door_centered_small_01", Vector3(x, y, 0.0))
			else:
				_piece(kit, house, "wall_window_centered_large_02", Vector3(x, y, 0.0))
				_piece(kit, house, "window_centered_large_02", Vector3(x, y, 0.0))
				_piece(kit, house, "dado_standard_standard_01", Vector3(x, y, 0.0))
				_lit_window(house, rng, lit, Vector3(x - 1.5, y + 1.3, -0.26), Vector2(2.0, 1.9))
			y += MODULE
			_piece(kit, house, "cornice_standard_standard_01", Vector3(x, y, 0.0))
			y += CORNICE_H
			for f in range(1, storeys):
				var n := "03" if f == storeys - 1 else "02"
				_piece(kit, house, "wall_window_%s_%s" % [style, n], Vector3(x, y, 0.0))
				_piece(kit, house, "window_%s_%s" % [style, n], Vector3(x, y, 0.0))
				_lit_window(house, rng, lit, Vector3(x - 1.5, y + 1.3, -0.3), Vector2(1.5, 1.6))
				y += MODULE
			_piece(kit, house, "crown_standard_standard_01", Vector3(x, top, 0.0))
		# Pilasters where two houses meet.
		for x: float in [0.0, MODULE * 3.0]:
			_piece(kit, house, "dado_pier_pedestal_01", Vector3(x, BASE_H, 0.0))
			_piece(kit, house, "wall_pier_standard_01", Vector3(x, BASE_H, 0.0))
			_piece(kit, house, "cornice_pier_standard_01", Vector3(x, BASE_H + MODULE, 0.0))
			for f in range(1, storeys):
				_piece(kit, house, "wall_pier_standard_01",
						Vector3(x, BASE_H + MODULE + CORNICE_H + (f - 1) * MODULE, 0.0))
			_piece(kit, house, "crown_pier_pedestal_01", Vector3(x, top, 0.0))
		# Solid body behind the facade, then roof, dormers and chimneys for the skyline.
		var width := MODULE * 3.0
		_box(house, Vector3(width, top, 9.0), Vector3(width / 2.0, top / 2.0, -4.85), dark)
		var roof_h := 2.2 + rng.randf() * 0.8
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(9.4, roof_h, width + 0.3)
		roof.mesh = prism
		roof.material_override = slate
		roof.rotation.y = PI / 2.0
		roof.name = "Roof"
		roof.position = Vector3(width / 2.0, top + CROWN_H * 0.5 + roof_h / 2.0, -4.7)
		house.add_child(roof)
		for d in 2:
			var dx := width * (0.28 + 0.44 * d)
			_box(house, Vector3(1.3, 1.5, 2.4), Vector3(dx, top + CROWN_H + 0.75, -1.2), brick)
			var cap := MeshInstance3D.new()
			var cp := PrismMesh.new()
			cp.size = Vector3(1.6, 0.8, 2.6)
			cap.mesh = cp
			cap.material_override = slate
			cap.name = "DormerRoof"
			cap.position = Vector3(dx, top + CROWN_H + 1.9, -1.2)
			house.add_child(cap, true)
		var stack_x := 0.6 if rng.randf() < 0.5 else width - 0.6
		var stack_h := roof_h + 1.6 + rng.randf() * 1.2
		_box(house, Vector3(1.0, stack_h, 1.8),
				Vector3(stack_x, top + CROWN_H + stack_h / 2.0, -4.7), brick)
		for p in 3:
			_box(house, Vector3(0.3, 0.5, 0.3),
					Vector3(stack_x, top + CROWN_H + stack_h + 0.25, -5.3 + p * 0.6), dark)
		if lanterns and h >= floors.size() - 2: # only the two houses nearest the camera
			var lamp := _wall_lamp()
			lamp.name = "WallLamp"
			lamp.position = Vector3(0.0, WALL_LAMP_H, 0.08)
			house.add_child(lamp)
	return row


static func _lit_window(parent: Node3D, rng: RandomNumberGenerator, chance: float, pos: Vector3,
		size: Vector2) -> void:
	if rng.randf() >= chance:
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _glow()
	mi.position = pos
	mi.name = "LitWindow"
	mi.add_to_group("pass_windows", true)
	parent.add_child(mi, true)


static func _lamp_light(group: String, light_range: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.omni_range = light_range
	light.light_energy = energy
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	light.light_size = 0.12
	light.shadow_bias = 0.05
	light.shadow_caster_mask = 1 # the lamp's own cage (layer 2) must not box the light in
	light.add_to_group(group, true)
	return light


## Victorian post lamp: the model's post under a lantern built by `_lantern`.
static func _post_lamp(group: String, scale: float, light_range: float, energy: float) -> Node3D:
	var lamp: Node3D = (load(POST_LAMP) as PackedScene).instantiate()
	lamp.scale = Vector3.ONE * scale
	# Drop the model's own lantern, and the ladder bar, which is clutter from this close below.
	for mi: MeshInstance3D in lamp.find_children("*", "MeshInstance3D", true, false):
		mi.mesh = _trimmed(mi.mesh, "street_lamp_01_post", func(v: Vector3) -> bool:
			return v.y > 3.0 or (v.y > 2.3 and v.y < 2.9 and absf(v.x) > 0.085))
	var head := _lantern(group, light_range, energy)
	head.position = Vector3(0.0, 3.0, 0.0)
	lamp.add_child(head)
	return lamp


## Wall lantern on the model's bracket. Mounts at z = 0 and reaches out along +Z.
static func _wall_lamp() -> Node3D:
	var lamp: Node3D = (load(WALL_LAMP) as PackedScene).instantiate()
	lamp.scale = Vector3.ONE * WALL_LAMP_SCALE
	for mi: MeshInstance3D in lamp.find_children("*", "MeshInstance3D", true, false):
		mi.mesh = _trimmed(mi.mesh, "street_lamp_02_bracket", func(v: Vector3) -> bool:
			return v.y > 0.4)
	var head := _lantern("pass_wall", 13.0, 1.6)
	head.position = Vector3(0.0, 0.4, 0.61)
	head.rotation.y = PI / 4.0 # corner-on to the street
	lamp.add_child(head)
	return lamp


## A copy of `mesh` without the triangles that have a corner where `cut` is true.
## Saved once as its own mesh file, like the facade pieces.
static func _trimmed(mesh: Mesh, file: String, cut: Callable) -> Mesh:
	var path := KIT_DIR + file + ".res"
	if not ResourceLoader.exists(path):
		var out := ArrayMesh.new()
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var src: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept := PackedInt32Array()
			for i in range(0, src.size(), 3):
				if not (cut.call(verts[src[i]]) or cut.call(verts[src[i + 1]])
						or cut.call(verts[src[i + 2]])):
					kept.append_array([src[i], src[i + 1], src[i + 2]])
			if kept.is_empty():
				continue # nothing of this surface is left (the old lantern's glass, say)
			arrays[Mesh.ARRAY_INDEX] = kept
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1,
					mesh.surface_get_material(surface))
		DirAccess.make_dir_recursive_absolute(KIT_DIR)
		ResourceSaver.save(out, path)
	return load(path)


## Four-sided mesh between two square sections (half-widths), for lantern glass and caps.
static func _taper(parent: Node3D, bottom: float, top: float, height: float, y: float,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.radial_segments = 4
	c.rings = 1
	c.bottom_radius = bottom * sqrt(2.0)
	c.top_radius = top * sqrt(2.0)
	c.height = height
	mi.mesh = c
	mi.material_override = mat
	mi.position.y = y + height / 2.0
	mi.rotation.y = PI / 4.0 # panes square to the axes
	mi.layers = 2
	parent.add_child(mi, true)
	return mi


## The lantern itself: four glowing panes that widen towards a low dark cap, held in a thin
## frame. Nothing sits inside it, so the whole pane lights up. Origin at the bottom centre.
static func _lantern(group: String, light_range: float, energy: float) -> Node3D:
	const BOTTOM := 0.1 # half-widths of the glass
	const TOP := 0.18
	const HEIGHT := 0.42
	var head := Node3D.new()
	head.name = "Lantern"
	var iron := _flat(Color(0.05, 0.05, 0.06), 0.6)

	var panes := ShaderMaterial.new()
	panes.shader = load("res://studio/lantern_glass.gdshader")
	var glass := _taper(head, BOTTOM, TOP, HEIGHT, 0.04, panes)
	(glass.mesh as CylinderMesh).cap_top = false
	(glass.mesh as CylinderMesh).cap_bottom = false
	glass.name = "Glass"
	glass.layers = 1
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.add_to_group(group, true)

	_taper(head, BOTTOM * 0.6, BOTTOM + 0.015, 0.05, 0.0, iron).name = "Base"
	_taper(head, TOP + 0.04, TOP + 0.04, 0.025, HEIGHT + 0.04, iron).name = "Eaves"
	_taper(head, TOP + 0.03, 0.03, 0.13, HEIGHT + 0.065, iron).name = "Cap"
	_taper(head, 0.03, 0.012, 0.07, HEIGHT + 0.195, iron).name = "Finial"
	# Glazing bars up the four corners.
	for i in 4:
		var side := Vector3(1.0 if i < 2 else -1.0, 0.0, 1.0 if i % 2 == 0 else -1.0)
		var foot := side * BOTTOM + Vector3(0.0, 0.04, 0.0)
		var tip := side * TOP + Vector3(0.0, 0.04 + HEIGHT, 0.0)
		var bar := _box(head, Vector3(0.022, foot.distance_to(tip), 0.022), (foot + tip) / 2.0, iron)
		bar.quaternion = Quaternion(Vector3.UP, (tip - foot).normalized())
		bar.name = "Bar"
		bar.layers = 2

	var light := _lamp_light(group, light_range, energy)
	light.position = Vector3(0.0, 0.04 + HEIGHT / 2.0, 0.0)
	light.name = "Light"
	head.add_child(light)
	return head


## Lamp models go on render layer 2 so their own light ignores them when casting shadows.
## The change is stored on the instanced model, so it is marked as having editable children.
static func _lamp_layers(node: Node, root: Node) -> void:
	for child in node.get_children():
		if child.scene_file_path in [POST_LAMP, WALL_LAMP]:
			root.set_editable_instance(child, true)
			for mi: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				if mi.owner != root:
					mi.layers = 2
		else:
			_lamp_layers(child, root)


static func _ground() -> Node3D:
	var g := Node3D.new()
	var cobbles := StandardMaterial3D.new()
	cobbles.albedo_texture = load(COBBLES + "diff_1k.jpg")
	cobbles.normal_enabled = true
	cobbles.normal_texture = load(COBBLES + "nor_gl_1k.jpg")
	cobbles.roughness_texture = load(COBBLES + "rough_1k.jpg")
	cobbles.roughness = 0.55 # damp stones: lets the lamps streak across them
	cobbles.uv1_scale = Vector3(40.0, 40.0, 1.0)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	mi.mesh = plane
	mi.name = "Cobbles"
	mi.material_override = cobbles
	mi.position = Vector3(0.0, 0.0, -30.0)
	g.add_child(mi)
	var stone := _flat(Color(0.32, 0.32, 0.33), 0.7)
	_box(g, Vector3(2.4, 0.16, 110.0), Vector3(3.5, 0.08, -30.0), stone)
	_box(g, Vector3(2.4, 0.16, 110.0), Vector3(-6.9, 0.08, -30.0), stone)
	return g


## Laboratory glassware on a crate in the near right corner.
static func _glassware() -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(3.5, 0.0, 0.2)
	g.rotation.y = deg_to_rad(-35.0)
	_box(g, Vector3(1.5, 0.5, 0.9), Vector3(0.0, 0.25, 0.0), _flat(Color(0.22, 0.2, 0.18)))
	var chem: Node3D = (load(CHEMISTRY) as PackedScene).instantiate()
	chem.scale = Vector3.ONE * 1.5
	chem.position = Vector3(0.0, 0.5, 0.1)
	g.add_child(chem)
	return g
