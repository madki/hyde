class_name LabBuilder
## Generates the 3D scene the laboratory picture is baked from: studio/lab.tscn, Dr Jekyll's
## laboratory at night, with his table of glassware, the window and the chair beside it. Like
## the streets and the back alley (studio/street_builder.gd, studio/alley_builder.gd, whose
## lamps and materials it uses), that scene is the source of truth and is meant to be edited in
## the 3D editor; this script only makes a fresh starting point (`tools/bake_lab.sh --rebuild`
## OVERWRITES it).
## Desktop-only authoring code: nothing in studio/ is exported with the game.
##
## One corner of the room, seen square on to its end wall. Everything stands against the
## left-hand wall, so it fills the left of the picture (the back alley's man
## is in the bottom right) and the rest of the room is left to the dark. Jekyll sits in the
## chair, sat back in it, his head turned to look out of the window. He sits still, so unlike
## the men in the street and the alley he is baked into the picture like the furniture.
## Lights belong to the same pass groups as the streets': "pass_key" is the light that comes
## in by the window and the burner's flame on the table (both blue in the game, so blue rules
## the corner Jekyll works in), "pass_wall" the gas lamp deep in the room, "pass_windows" what glows by itself (the liquids in the glass, windows outside).

const WALL_X := -1.5 # face of the wall the window is in
const RIGHT_X := 8.0 # face of the wall across the room, out of the picture
const WALL_T := 0.45 # how thick the window's wall is
const FAR_Z := -3.6 # the end wall the window's light falls on, close behind the chair
const NEAR_Z := 6.0 # the wall behind the camera
const CEILING := 5.6 # above the top of the picture

const WINDOW_Z := -1.75 # middle of the window
const WINDOW_HALF_W := 0.72
const SILL := 0.95
const HEAD := 2.8

const TABLE_POS := Vector3(-0.32, 0.0, 1.15) # middle of the table, on the floor
const TABLE_SIZE := Vector3(1.65, 0.76, 1.3) # across, top's height, along the wall
const TABLE_YAW := 0.0
const GLASS_SCALE := 1.6 # the glassware is a little larger than life, to read from here
const CHAIR_POS := Vector3(-0.2, 0.0, -3.0) # against the end wall, in front of the patch of light the
# window throws on it, so the man in it is seen dark against the light
const CHAIR_FIT := Vector3(1.0, 0.9, 0.8) # lower and shallower, so Jekyll sits right back in it
const CHAIR_YAW := -45.0 # turned towards the window: we see him half side on
const FIGURE_CLOTH := Color(0.43, 0.43, 0.46) # how much light comes off him: low, so he is a dark
# shape against the lit wall, but not so low that his own colours are lost
const FIGURE_SEAT := 0.12 # how far in front of the middle of the seat Jekyll's own middle is

# From standing height, looking square at the end wall and a little down: the window's wall
# closes the left of the picture, seen edge-on, and its light lies across the end wall.
const CAM_POS := Vector3(0.9, 1.5, 3.6)
const CAM_TARGET := Vector3(0.95, 1.2, -6.0)
const CAM_FOV := 50.0
## The way the light comes in by the window: low, into the room and away from the camera, so
## the panes land on the end wall and the chair sits in them.
const WINDOW_LIGHT_DIR := Vector3(1.0, -0.62, -1.15)

const KIT_DIR := "res://studio/kit/"


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Lab"
	root.add_child(_room())
	root.add_child(_window_wall())
	root.add_child(_outside())
	root.add_child(_table())
	root.add_child(_chair())
	root.add_child(_figure())
	root.add_child(_far_end())

	# A soft light from the camera's side of the room, in the gas lamp's colour: the window lights
	# Jekyll from the far side, so this gives the side of him that faces us a colour of its own.
	var fill := OmniLight3D.new()
	fill.name = "RoomFill"
	fill.position = Vector3(1.0, 1.5, -1.2)
	fill.omni_range = 4.0
	fill.omni_attenuation = 1.0
	fill.light_energy = 0.55
	fill.light_volumetric_fog_energy = 0.0
	fill.light_size = 0.5
	fill.shadow_enabled = true
	fill.shadow_bias = 0.05
	fill.add_to_group("pass_wall", true)
	root.add_child(fill)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = CAM_FOV
	cam.far = 200.0
	root.add_child(cam)
	cam.look_at_from_position(CAM_POS, CAM_TARGET)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_energy = 1.2
	moon.shadow_enabled = true
	moon.add_to_group("pass_ambient", true)
	root.add_child(moon)
	moon.look_at_from_position(Vector3.ZERO, WINDOW_LIGHT_DIR)
	StreetBuilder._own(root, root)
	StreetBuilder._lamp_layers(root, root)
	return root


## A box given by two opposite corners.
static func _slab(parent: Node3D, a: Vector3, b: Vector3, mat: Material,
		slab_name := "Box") -> MeshInstance3D:
	var mi := StreetBuilder._box(parent, (b - a).abs(), (a + b) / 2.0, mat)
	mi.name = slab_name
	return mi


static func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material,
		cyl_name := "Cylinder", top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = radius
	c.top_radius = radius if top_radius < 0.0 else top_radius
	c.height = height
	c.radial_segments = 16
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos + Vector3(0.0, height / 2.0, 0.0)
	mi.name = cyl_name
	parent.add_child(mi, true)
	return mi


static func _timber() -> StandardMaterial3D:
	return StreetBuilder._flat(Color(0.2, 0.185, 0.17), 0.7)


## Floor, ceiling and the walls the window is not in.
static func _room() -> Node3D:
	var room := Node3D.new()
	room.name = "Room"
	var brick := StreetBuilder._brick()
	var dark := StreetBuilder._flat(Color(0.07, 0.07, 0.075))
	var timber := StreetBuilder._flat(Color(0.11, 0.1, 0.095), 0.8)

	var boards := ShaderMaterial.new()
	boards.shader = load("res://studio/planks.gdshader")
	_slab(room, Vector3(WALL_X - WALL_T, -0.2, FAR_Z), Vector3(RIGHT_X, 0.0, NEAR_Z), boards, "Floor")
	_slab(room, Vector3(WALL_X - WALL_T, CEILING, FAR_Z - 0.4), Vector3(RIGHT_X + 0.4, CEILING + 0.3, NEAR_Z + 0.4),
			dark, "Ceiling")
	var z := 2.4
	while z > FAR_Z:
		_slab(room, Vector3(WALL_X, CEILING - 0.26, z - 0.11), Vector3(RIGHT_X, CEILING, z + 0.11), timber, "Beam")
		z -= 1.9
	_slab(room, Vector3(WALL_X - WALL_T, 0.0, FAR_Z - 0.4), Vector3(RIGHT_X + 0.4, CEILING, FAR_Z), brick, "FarWall")
	_slab(room, Vector3(RIGHT_X, 0.0, FAR_Z), Vector3(RIGHT_X + 0.4, CEILING, NEAR_Z), brick, "RightWall")
	_slab(room, Vector3(WALL_X - WALL_T, 0.0, NEAR_Z), Vector3(RIGHT_X + 0.4, CEILING, NEAR_Z + 0.4), brick, "NearWall")
	return room


## The left-hand wall and its window.
static func _window_wall() -> Node3D:
	var side := Node3D.new()
	side.name = "WindowWall"
	var brick := StreetBuilder._brick()
	var stone := StreetBuilder._flat(Color(0.4, 0.4, 0.41), 0.7)
	var timber := _timber()
	var dark := StreetBuilder._flat(Color(0.05, 0.05, 0.055))
	var out := WALL_X - WALL_T
	var z0 := WINDOW_Z - WINDOW_HALF_W
	var z1 := WINDOW_Z + WINDOW_HALF_W

	# The wall, in four boxes round the window.
	_slab(side, Vector3(out, 0.0, z1), Vector3(WALL_X, CEILING, NEAR_Z), brick, "Wall")
	_slab(side, Vector3(out, 0.0, FAR_Z), Vector3(WALL_X, CEILING, z0), brick, "Wall")
	_slab(side, Vector3(out, 0.0, z0), Vector3(WALL_X, SILL, z1), brick, "Wall")
	_slab(side, Vector3(out, HEAD, z0), Vector3(WALL_X, CEILING, z1), brick, "Wall")
	_slab(side, Vector3(out, 0.0, FAR_Z), Vector3(WALL_X + 0.03, 0.22, NEAR_Z), timber, "Skirting")

	# The window: a tall sash in a timber frame, with a stone sill deep enough to sit a bottle on.
	var win := Node3D.new()
	win.name = "Window"
	side.add_child(win)
	var mid := WALL_X - WALL_T * 0.55 # the glazing sits back from the room
	_slab(win, Vector3(WALL_X - WALL_T, SILL - 0.07, z0 - 0.1), Vector3(WALL_X + 0.16, SILL, z1 + 0.1), stone, "Sill")
	_slab(win, Vector3(WALL_X - 0.02, HEAD, z0 - 0.12), Vector3(WALL_X + 0.05, HEAD + 0.2, z1 + 0.12), stone, "Lintel")
	for jz: float in [z0, z1]:
		_slab(win, Vector3(mid - 0.05, SILL, jz - 0.05), Vector3(mid + 0.05, HEAD, jz + 0.05), timber, "Jamb")
	_slab(win, Vector3(mid - 0.05, HEAD - 0.07, z0), Vector3(mid + 0.05, HEAD, z1), timber, "FrameHead")
	_slab(win, Vector3(mid - 0.05, SILL, z0), Vector3(mid + 0.05, SILL + 0.07, z1), timber, "FrameSill")
	var rail := (SILL + HEAD) / 2.0
	_slab(win, Vector3(mid - 0.04, rail - 0.04, z0), Vector3(mid + 0.04, rail + 0.04, z1), timber, "MeetingRail")
	for bar_y: float in [lerpf(SILL, rail, 0.5), lerpf(rail, HEAD, 0.5)]:
		_slab(win, Vector3(mid - 0.02, bar_y - 0.018, z0), Vector3(mid + 0.02, bar_y + 0.018, z1), timber, "Bar")
	for bar_z: float in [lerpf(z0, z1, 1.0 / 3.0), lerpf(z0, z1, 2.0 / 3.0)]:
		_slab(win, Vector3(mid - 0.02, SILL, bar_z - 0.018), Vector3(mid + 0.02, HEAD, bar_z + 0.018), timber, "Bar")

	# What comes in by it: a narrow beam from high outside, so only the panes' shapes land in
	# the room. Kept low, or it burns out the man who sits in it.
	var beam := SpotLight3D.new()
	beam.name = "WindowLight"
	beam.spot_range = 22.0
	beam.spot_angle = 16.0
	beam.spot_angle_attenuation = 0.5
	beam.spot_attenuation = 0.3
	beam.light_energy = 5.0
	beam.shadow_enabled = true
	beam.light_size = 0.1
	beam.shadow_bias = 0.05
	beam.add_to_group("pass_key", true)
	side.add_child(beam)
	var through := Vector3(WALL_X - WALL_T * 0.5, (SILL + HEAD) / 2.0, WINDOW_Z)
	var dir := WINDOW_LIGHT_DIR.normalized()
	beam.look_at_from_position(through - dir * 9.0, through + dir)

	# The night sky's own glow through the glass: lights the window's end of the room softly.
	var fill := OmniLight3D.new()
	fill.name = "WindowFill"
	fill.position = Vector3(WALL_X + 0.5, 2.0, WINDOW_Z)
	fill.omni_range = 6.0
	fill.omni_attenuation = 1.2
	fill.light_energy = 0.75
	fill.shadow_enabled = true
	fill.light_size = 0.3
	fill.shadow_bias = 0.05
	fill.add_to_group("pass_key", true)
	side.add_child(fill)

	return side


## What the window looks out on: the backs of houses across the court, against the sky.
static func _outside() -> Node3D:
	var outside := Node3D.new()
	outside.name = "Outside"
	var dark := StreetBuilder._flat(Color(0.04, 0.04, 0.045))
	var slate := StreetBuilder._flat(Color(0.16, 0.16, 0.17), 0.6)
	_slab(outside, Vector3(-60.0, -0.2, -60.0), Vector3(WALL_X - WALL_T, 0.0, 20.0), dark, "Court")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var bz := -2.0
	while bz > -40.0:
		var width := 3.4 + rng.randf() * 1.8
		var height := 4.2 + rng.randf() * 2.6
		var bx := -15.0 - rng.randf() * 3.0
		_slab(outside, Vector3(bx - 8.0, 0.0, bz - width), Vector3(bx, height, bz), dark, "Back")
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(width, 1.5 + rng.randf(), 8.4)
		roof.mesh = prism
		roof.material_override = slate
		roof.name = "Roof"
		roof.position = Vector3(bx - 4.0, height + prism.size.y / 2.0, bz - width / 2.0)
		outside.add_child(roof, true)
		var stack := 1.4 + rng.randf() * 1.2
		_slab(outside, Vector3(bx - 1.6, height, bz - 0.9), Vector3(bx - 0.8, height + stack, bz - 0.3), dark, "Stack")
		if rng.randf() < 0.5:
			var lit := MeshInstance3D.new()
			var lq := QuadMesh.new()
			lq.size = Vector2(0.8, 1.2)
			lit.mesh = lq
			lit.material_override = StreetBuilder._glow()
			lit.rotation.y = PI / 2.0 # faces the laboratory
			lit.position = Vector3(bx + 0.02, 2.2 + rng.randf() * 1.6, bz - width * (0.3 + rng.randf() * 0.4))
			lit.name = "LitWindow"
			lit.add_to_group("pass_windows", true)
			outside.add_child(lit, true)
		bz -= width
	return outside


## The table in the near corner, and the apparatus on it.
static func _table() -> Node3D:
	var table := Node3D.new()
	table.name = "Table"
	table.position = TABLE_POS
	table.rotation.y = deg_to_rad(TABLE_YAW)
	var timber := _timber()
	var half := Vector2(TABLE_SIZE.x, TABLE_SIZE.z) / 2.0
	var top := TABLE_SIZE.y
	_slab(table, Vector3(-half.x, top - 0.06, -half.y), Vector3(half.x, top, half.y), timber, "Top")
	_slab(table, Vector3(-half.x + 0.06, top - 0.2, -half.y + 0.06),
			Vector3(half.x - 0.06, top - 0.06, half.y - 0.06), timber, "Apron")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var leg := Vector3(sx * (half.x - 0.1), 0.0, sz * (half.y - 0.1))
			_slab(table, leg - Vector3(0.045, 0.0, 0.045), leg + Vector3(0.045, top - 0.06, 0.045), timber, "Leg")
	var glass := _glassware()
	glass.position = Vector3(0.0, top, 0.0)
	table.add_child(glass)
	return table


## One piece of the chemistry set, saved once as its own mesh file like the facade pieces.
## `pos` is in the set's own metres.
static func _chem(chem: Dictionary, parent: Node3D, piece: String, pos: Vector3, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var path := KIT_DIR + "chemistry_" + piece + ".res"
	if not ResourceLoader.exists(path):
		DirAccess.make_dir_recursive_absolute(KIT_DIR)
		ResourceSaver.save(chem["chemistry_set_" + piece], path)
	mi.mesh = load(path)
	# The set's glass is redrawn as outlines (studio/glass.gdshader); brown bottles stay dark.
	for i in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i)
		if mat and mat.resource_name.ends_with("glass"):
			mi.set_surface_override_material(i, _glass(piece.begins_with("bottle_dark")))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = piece.to_pascal_case()
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	parent.add_child(mi, true)
	return mi


## One shared material for clear glass and one for brown, saved as their own files like the
## brickwork so the scene references them and they can be tuned in the editor.
static func _glass(brown := false) -> ShaderMaterial:
	var path := KIT_DIR + ("glass_brown_material.tres" if brown else "glass_material.tres")
	if not ResourceLoader.exists(path):
		var m := ShaderMaterial.new()
		m.shader = load("res://studio/glass.gdshader")
		if brown:
			m.set_shader_parameter("body", 0.8)
			m.set_shader_parameter("tone", 0.12)
		DirAccess.make_dir_recursive_absolute(KIT_DIR)
		ResourceSaver.save(m, path)
	return load(path)


## A liquid that glows by itself: drawn in the windows' colour.
static func _glowing(mi: MeshInstance3D) -> void:
	mi.material_override = StreetBuilder._glow()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group("pass_windows", true)


## Test tubes in their rack, flasks, beakers, stoppered bottles, a retort stand and a lit
## burner: Poly Haven's chemistry set, laid out as a working bench. Origin on the table top.
static func _glassware() -> Node3D:
	var g := Node3D.new()
	g.name = "Glassware"
	g.scale = Vector3.ONE * GLASS_SCALE
	var scene: Node = (load(StreetBuilder.CHEMISTRY) as PackedScene).instantiate()
	var chem := {}
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		chem[String(mi.name)] = mi.mesh
	scene.free()

	# The rack of test tubes, nearest the camera and square to it.
	var rack := Node3D.new()
	rack.name = "Rack"
	rack.position = Vector3(0.12, 0.0, 0.2)
	rack.rotation.y = deg_to_rad(12.0)
	g.add_child(rack)
	_chem(chem, rack, "test_tube_stand_a", Vector3.ZERO)
	var fills := ["d", "a", "", "e", "b", "f", ""]
	for i in fills.size():
		var hole := Vector3(-0.108 + i * 0.036, 0.022, 0.0)
		_chem(chem, rack, "test_tube_a", hole)
		if fills[i] != "":
			_glowing(_chem(chem, rack, "test_tube_content_" + fills[i], hole))

	# Behind it the measuring cylinder and the second stand.
	_chem(chem, g, "beaker_large", Vector3(-0.12, 0.0, -0.2))
	_glowing(_cylinder(g, 0.017, 0.16, Vector3(-0.12, 0.035, -0.2), null, "CylinderLiquid"))
	_chem(chem, g, "test_tube_stand_b", Vector3(-0.32, 0.0, -0.12), 20.0)

	# Beakers.
	_chem(chem, g, "beaker_med", Vector3(-0.18, 0.0, 0.12), 30.0)
	_glowing(_cylinder(g, 0.04, 0.05, Vector3(-0.18, 0.006, 0.12), null, "BeakerLiquid"))
	_chem(chem, g, "beaker_small", Vector3(-0.05, 0.0, 0.27), -60.0)

	# The burner, alight under a round flask held in the retort stand's clamp.
	var burner := Vector3(0.3, 0.0, -0.08)
	_chem(chem, g, "bunsen_burner", burner, 200.0)
	_chem(chem, g, "clamp_stand", burner + Vector3(-0.07, 0.0, -0.13), 0.0)
	var flask := Node3D.new()
	flask.name = "Flask"
	flask.position = burner + Vector3(0.0, 0.3, 0.0)
	g.add_child(flask)
	var bulb := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.062
	ball.height = 0.124
	bulb.mesh = ball
	bulb.material_override = _glass()
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.name = "Bulb"
	flask.add_child(bulb)
	var neck := _cylinder(flask, 0.019, 0.15, Vector3(0.0, 0.05, 0.0), _glass(), "Neck")
	(neck.mesh as CylinderMesh).cap_top = false
	(neck.mesh as CylinderMesh).cap_bottom = false
	neck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var potion := MeshInstance3D.new()
	var half := SphereMesh.new()
	half.radius = 0.054
	half.height = 0.054
	half.is_hemisphere = true
	potion.mesh = half
	potion.rotation.x = PI # the round side down
	potion.position.y = 0.004
	potion.name = "Potion"
	flask.add_child(potion)
	_glowing(potion)
	var flame := _cylinder(g, 0.011, 0.07, burner + Vector3(0.0, 0.153, 0.0), StreetBuilder._glow(), "Flame", 0.0)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_to_group("pass_key", true)
	var light := StreetBuilder._lamp_light("pass_key", 2.2, 1.1)
	light.name = "FlameLight"
	light.position = burner + Vector3(0.0, 0.2, 0.0)
	light.light_size = 0.02
	g.add_child(light)

	# Stoppered bottles along the table's wall side and its near edge.
	var bottles := [
		["dark_c", "lid", Vector3(-0.32, 0.0, 0.22), ""],
		["clear_d", "cork", Vector3(-0.3, 0.0, 0.33), "e"],
		["dark_a", "lid", Vector3(-0.22, 0.0, 0.3), ""],
		["clear_c", "lid", Vector3(0.3, 0.0, 0.3), "f"],
		["dark_e", "dropper", Vector3(0.24, 0.0, 0.36), ""],
		["clear_b", "cork", Vector3(0.02, 0.0, -0.3), "b"],
		["dark_d", "cork", Vector3(0.3, 0.0, -0.3), ""],
	]
	for b: Array in bottles:
		_chem(chem, g, "bottle_" + b[0], b[2])
		_chem(chem, g, "bottle_%s_%s" % [b[0], b[1]], b[2])
		if b[3] != "":
			_glowing(_chem(chem, g, "bottle_content_" + b[3], b[2]))
	return g


## A low upholstered armchair. Origin on the floor under the middle of the seat; it faces +Z
## before it is turned.
static func _chair() -> Node3D:
	var chair := Node3D.new()
	chair.name = "Chair"
	chair.position = CHAIR_POS
	chair.rotation.y = deg_to_rad(CHAIR_YAW)
	chair.scale = CHAIR_FIT
	var cloth := StreetBuilder._flat(Color(0.2, 0.19, 0.18), 0.9) # dark leather, so the man in it stands out
	var wood := _timber()
	var w := 0.3 # half the seat's width
	var d := 0.3 # half its depth
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var leg := Vector3(sx * (w + 0.05), 0.0, sz * (d - 0.02))
			_slab(chair, leg - Vector3(0.025, 0.0, 0.025), leg + Vector3(0.025, 0.2, 0.025), wood, "Leg")
	_slab(chair, Vector3(-w - 0.12, 0.2, -d - 0.1), Vector3(w + 0.12, 0.34, d + 0.04), cloth, "Base")
	_slab(chair, Vector3(-w, 0.34, -d + 0.04), Vector3(w, 0.47, d + 0.06), cloth, "Cushion")
	var back := _slab(chair, Vector3(-w - 0.12, 0.3, -d - 0.14), Vector3(w + 0.12, 1.02, -d + 0.04), cloth, "Back")
	back.rotation.x = deg_to_rad(-9.0) # it leans
	back.position.z -= 0.05
	var roll := _cylinder(chair, 0.09, (w + 0.12) * 2.0, Vector3.ZERO, cloth, "BackRoll")
	roll.rotation.z = PI / 2.0
	roll.position = Vector3(0.0, 1.02, -d - 0.16)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (w + 0.06)
		_slab(chair, Vector3(x - 0.06, 0.3, -d - 0.08), Vector3(x + 0.06, 0.64, d + 0.04), cloth, "Arm")
		var pad := _cylinder(chair, 0.075, d * 2.0 + 0.12, Vector3.ZERO, cloth, "ArmRoll")
		pad.rotation.x = PI / 2.0
		pad.position = Vector3(x, 0.64, -0.02)
	return chair


## Jekyll, seated in the chair.
static func _figure() -> Node3D:
	var figure := FigureBuilder.build("jekyll", "seated")
	var yaw := deg_to_rad(CHAIR_YAW)
	figure.position = CHAIR_POS + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, FIGURE_SEAT)
	figure.rotation.y = yaw
	# Part of the picture, not a layer of his own: studio/bake.gd hides whatever is a "figure".
	var body := figure.get_node("Body") as MeshInstance3D
	body.remove_from_group("figure")
	body.add_to_group("own_colour", true) # and in his own colours: his mesh carries them
	(body.material_override as ShaderMaterial).set_shader_parameter("cloth", FIGURE_CLOTH)
	return figure


## The end wall: shelves of stock bottles where the window's light falls, and a gas lamp away
## to the right, the one warm light in the room.
static func _far_end() -> Node3D:
	var far := Node3D.new()
	far.name = "FarEnd"
	var timber := _timber()
	var dark := StreetBuilder._flat(Color(0.05, 0.05, 0.055))
	var shelves := Node3D.new()
	shelves.name = "Shelves"
	far.add_child(shelves)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var x0 := 0.15
	var x1 := 1.75
	for shelf_y: float in [1.75, 2.25]:
		_slab(shelves, Vector3(x0, shelf_y - 0.04, FAR_Z), Vector3(x1, shelf_y, FAR_Z + 0.26), timber, "Shelf")
		var bx := x0 + 0.1
		while bx < x1 - 0.12:
			var r := 0.05 + rng.randf() * 0.04
			var h := 0.16 + rng.randf() * 0.2
			if rng.randf() < 0.8:
				var at := Vector3(bx + r, shelf_y, FAR_Z + 0.13)
				_cylinder(shelves, r, h, at, dark, "Bottle")
				_cylinder(shelves, r * 0.4, 0.07, at + Vector3(0.0, h, 0.0), dark, "Neck")
			bx += r * 2.0 + 0.03 + rng.randf() * 0.08
	for bracket_x: float in [x0 + 0.06, x1 - 0.06]:
		_slab(shelves, Vector3(bracket_x - 0.025, 1.5, FAR_Z), Vector3(bracket_x + 0.025, 2.25, FAR_Z + 0.04), timber, "Upright")
	_slab(far, Vector3(WALL_X, 0.0, FAR_Z), Vector3(RIGHT_X, 0.22, FAR_Z + 0.03), timber, "Skirting")

	var lamp := StreetBuilder._wall_lamp()
	lamp.name = "GasLamp"
	lamp.position = Vector3(3.7, 2.15, FAR_Z) # reaches out towards the camera
	var light := lamp.get_node("Lantern/Light") as OmniLight3D
	light.omni_range = 3.5
	light.light_energy = 0.45
	lamp.scale *= 0.75
	far.add_child(lamp)
	# Most of its light on the wall comes from out in the room, so the bricks behind it keep
	# their drawing and the light reaches further along the wall.
	far.add_child(StreetBuilder._even_out(lamp, Vector3.BACK * 0.8, 0.22, 6.0))
	return far
