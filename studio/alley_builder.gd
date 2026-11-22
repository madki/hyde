class_name AlleyBuilder
## Generates the 3D scene the back-alley picture is baked from: studio/alley.tscn, Hyde letting
## himself in by the door in the blind wall. Like the streets (studio/street_builder.gd, whose
## kit, lamps and materials it uses), that scene is the source of truth and is meant to be
## edited in the 3D editor; this script only makes a fresh starting point
## (`tools/bake_alley.sh --rebuild` OVERWRITES it).
## Desktop-only authoring code: nothing in studio/ is exported with the game.
##
## The alley runs away from the camera along -Z. The door is in the right-hand wall, close to
## the camera, so the man at it stands in the bottom right corner of the picture and the rest
## is left to the fog. Lights belong to the same pass groups as the streets':
## "pass_key" is the light from a window across the alley (out of the picture: it throws the
## man's shadow on the door) and the lamp at the alley's mouth, "pass_wall" the lanterns on
## the wall and the lights that spread them along it, "pass_windows" the lit windows over the
## yard wall and the dim light by the gate.

const WALL_X := 1.5 # face of the wall the door is in
const LEFT_X := -5.0 # face of the wall across the alley
const DOOR_Z := 0.0
const DOOR_SCALE := 0.82 # the kit's front door, cut down to a back door
const DOOR_HALF_W := 0.58
const DOOR_H := 2.26
const MOUTH_Z := -24.0 # where the alley opens onto a street

# From just above head height, looking down the alley and a little down at the stones: the
# door wall fills the right of the picture and runs away to a vanishing point near the middle.
const CAM_POS := Vector3(-0.6, 1.9, 3.9)
const CAM_TARGET := Vector3(-1.3, 1.11, -6.05)
const CAM_FOV := 50.0
const KNOB := Vector3(WALL_X + 0.07, 1.09, DOOR_Z + 0.36) # on the door's edge nearer the camera
const FIGURE_POS := Vector3(0.92, 0.0, 0.15) # as close to the door as his stoop allows
const FIGURE_SCALE := 0.88 # as in the street
const FIGURE_YAW := 85.0 # facing the door, seen from behind his left shoulder
const THROW_OUT := 0.9 # metres out from a wall lantern to the light that spreads it along the wall


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Alley"
	var kit := StreetBuilder._kit_meshes()
	root.add_child(_ground())
	root.add_child(_door_side(kit))
	root.add_child(_far_side())
	root.add_child(_mouth(kit))

	var figure := FigureBuilder.build("hyde")
	figure.position = FIGURE_POS
	figure.rotation.y = deg_to_rad(FIGURE_YAW)
	figure.scale = Vector3.ONE * FIGURE_SCALE
	# He is drawn as a layer of his own, but his shadow belongs to the alley (see studio/bake.gd).
	figure.get_node("Body").add_to_group("casts_shadow", true)
	root.add_child(figure)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = CAM_FOV
	cam.far = 200.0
	root.add_child(cam)
	cam.look_at_from_position(CAM_POS, CAM_TARGET)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(140.0), 0.0)
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.add_to_group("pass_ambient", true)
	root.add_child(moon)
	StreetBuilder._own(root, root)
	StreetBuilder._lamp_layers(root, root)
	return root


## A box given by two opposite corners.
static func _slab(parent: Node3D, a: Vector3, b: Vector3, mat: Material,
		slab_name := "Box") -> MeshInstance3D:
	var mi := StreetBuilder._box(parent, (b - a).abs(), (a + b) / 2.0, mat)
	mi.name = slab_name
	return mi


static func _ground() -> Node3D:
	var g := Node3D.new()
	g.name = "Ground"
	var cobbles := StandardMaterial3D.new()
	cobbles.albedo_texture = load(StreetBuilder.COBBLES + "diff_1k.jpg")
	cobbles.normal_enabled = true
	cobbles.normal_texture = load(StreetBuilder.COBBLES + "nor_gl_1k.jpg")
	cobbles.roughness_texture = load(StreetBuilder.COBBLES + "rough_1k.jpg")
	# It has rained: smooth enough for the lanterns to streak across the stones and, with
	# studio/bake.gd's reflections, for the lit wall to show in them.
	cobbles.roughness = 0.36
	cobbles.uv1_scale = Vector3(30.0, 30.0, 1.0)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	mi.mesh = plane
	mi.name = "Cobbles"
	mi.material_override = cobbles
	mi.position = Vector3(0.0, 0.0, -20.0)
	g.add_child(mi)
	return g


## The right-hand side: the blind wall with the door, the upper storey that juts out over it,
## and the taller house further on.
static func _door_side(kit: Dictionary) -> Node3D:
	var side := Node3D.new()
	side.name = "DoorSide"
	var brick := StreetBuilder._brick()
	var stone := StreetBuilder._flat(Color(0.34, 0.34, 0.35), 0.7)
	var dark := StreetBuilder._flat(Color(0.04, 0.04, 0.045))
	var timber := StreetBuilder._flat(Color(0.13, 0.12, 0.11), 0.8)
	var top := 7.5
	var back := WALL_X + 0.6

	# The wall, in three boxes round the doorway.
	_slab(side, Vector3(WALL_X, 0.0, DOOR_Z + DOOR_HALF_W), Vector3(back, top, 9.0), brick, "Wall")
	_slab(side, Vector3(WALL_X, 0.0, -9.0), Vector3(back, top, DOOR_Z - DOOR_HALF_W), brick, "Wall")
	_slab(side, Vector3(WALL_X, DOOR_H, DOOR_Z - DOOR_HALF_W),
			Vector3(back, top, DOOR_Z + DOOR_HALF_W), brick, "Wall")
	_slab(side, Vector3(WALL_X + 0.4, 0.0, DOOR_Z - DOOR_HALF_W),
			Vector3(back, DOOR_H, DOOR_Z + DOOR_HALF_W), dark, "Behind")
	for z: float in [-6.2, -3.6, 2.7, 6.0]:
		_slab(side, Vector3(WALL_X - 0.12, 0.0, z - 0.26), Vector3(WALL_X, top, z + 0.26), brick, "Pier")
	_slab(side, Vector3(WALL_X - 0.06, 0.0, -9.0), Vector3(WALL_X, 0.5, DOOR_Z - 0.62), stone, "Plinth")
	_slab(side, Vector3(WALL_X - 0.06, 0.0, DOOR_Z + 0.62), Vector3(WALL_X, 0.5, 9.0), stone, "Plinth")

	# The door: neither bell nor knocker, one worn step.
	var door := Node3D.new()
	door.name = "Door"
	door.rotation.y = -PI / 2.0 # the kit faces +Z; this door faces the alley
	door.scale = Vector3.ONE * DOOR_SCALE
	door.position = Vector3(WALL_X, 0.0, DOOR_Z + 1.5 * DOOR_SCALE)
	side.add_child(door)
	StreetBuilder._piece(kit, door, "door_centered_small_01", Vector3.ZERO)
	# Pale, weathered paint instead of the kit's dark wood, so a shadow shows on it.
	(door.get_child(0) as MeshInstance3D).material_override = StreetBuilder._flat(Color(0.72, 0.7, 0.66), 0.8)
	_slab(side, Vector3(WALL_X - 0.1, DOOR_H + 0.04, DOOR_Z - 0.8),
			Vector3(WALL_X + 0.05, DOOR_H + 0.3, DOOR_Z + 0.8), stone, "Lintel")
	_slab(side, Vector3(WALL_X - 0.22, 0.0, DOOR_Z - 0.8), Vector3(WALL_X + 0.2, 0.1, DOOR_Z + 0.8), stone, "Step")
	var knob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.04
	ball.height = 0.08
	knob.mesh = ball
	knob.material_override = dark
	knob.position = KNOB
	knob.name = "Knob"
	side.add_child(knob)

	# The storey above juts out on joists: boards with battens over the joins.
	var jetty_z := Vector2(-3.3, 2.4)
	var jetty_x := WALL_X - 0.95
	_slab(side, Vector3(jetty_x, 3.3, jetty_z.x), Vector3(WALL_X, 6.4, jetty_z.y), timber, "Jetty")
	_slab(side, Vector3(jetty_x - 0.06, 3.22, jetty_z.x - 0.06),
			Vector3(WALL_X, 3.34, jetty_z.y + 0.06), timber, "JettySill")
	var z := jetty_z.x + 0.2
	while z < jetty_z.y:
		_slab(side, Vector3(jetty_x - 0.12, 3.04, z - 0.07), Vector3(WALL_X, 3.22, z + 0.07), timber, "Joist")
		z += 0.75
	z = jetty_z.x + 0.4
	while z < jetty_z.y:
		_slab(side, Vector3(jetty_x - 0.03, 3.34, z - 0.03), Vector3(jetty_x, 6.4, z + 0.03), timber, "Batten")
		z += 0.4
	_slab(side, Vector3(jetty_x - 0.25, 6.4, jetty_z.x - 0.2), Vector3(back, 6.55, jetty_z.y + 0.2),
			StreetBuilder._flat(Color(0.16, 0.16, 0.17), 0.6), "JettyRoof")

	# The lantern by the door, on the far side of it from the camera.
	var lamp := StreetBuilder._wall_lamp()
	lamp.name = "DoorLamp"
	lamp.rotation.y = -PI / 2.0
	lamp.position = Vector3(WALL_X, 1.95, -3.05)
	_dim(lamp, 8.0, 1.3)
	side.add_child(lamp)
	side.add_child(StreetBuilder._even_out(lamp, Vector3.LEFT * THROW_OUT, 0.55, 11.0))

	# A taller house further on, standing a little proud of the wall.
	var proud := WALL_X - 0.35
	_slab(side, Vector3(proud, 0.0, MOUTH_Z), Vector3(back + 6.0, 9.5, -9.0), brick, "FarHouse")
	_slab(side, Vector3(proud - 0.07, 3.6, MOUTH_Z), Vector3(proud, 3.8, -9.0), stone, "Course")
	for wz: float in [-11.5, -18.5, -21.5]:
		# Bricked-up windows.
		_slab(side, Vector3(proud - 0.01, 4.6, wz - 0.55), Vector3(proud + 0.1, 6.5, wz + 0.55), dark, "BlindWindow")
		_slab(side, Vector3(proud - 0.08, 4.45, wz - 0.7), Vector3(proud + 0.02, 4.6, wz + 0.7), stone, "Sill")
	var far_lamp := StreetBuilder._wall_lamp()
	far_lamp.name = "FarLamp"
	far_lamp.rotation.y = -PI / 2.0
	far_lamp.position = Vector3(proud, 1.9, -11.0)
	_dim(far_lamp, 7.0, 1.0)
	side.add_child(far_lamp)
	side.add_child(StreetBuilder._even_out(far_lamp, Vector3.LEFT * THROW_OUT, 0.45, 10.0))
	return side


## The left-hand side: a house whose lit window is out of the picture (its light crosses the
## alley and throws the man's shadow on the door), then a long yard wall with the backs of
## other houses over it, against the sky.
static func _far_side() -> Node3D:
	var side := Node3D.new()
	side.name = "FarSide"
	var brick := StreetBuilder._brick()
	var stone := StreetBuilder._flat(Color(0.34, 0.34, 0.35), 0.7)
	var dark := StreetBuilder._flat(Color(0.04, 0.04, 0.045))
	var timber := StreetBuilder._flat(Color(0.13, 0.12, 0.11), 0.8)
	var slate := StreetBuilder._flat(Color(0.16, 0.16, 0.17), 0.6)

	# Near house.
	_slab(side, Vector3(LEFT_X - 6.0, 0.0, 0.5), Vector3(LEFT_X, 8.0, 9.0), brick, "NearHouse")
	var window_at := Vector3(LEFT_X + 0.02, 1.3, 2.4)
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 1.1)
	pane.mesh = quad
	pane.material_override = StreetBuilder._glow()
	pane.rotation.y = PI / 2.0 # faces the alley
	pane.position = window_at
	pane.name = "LitWindow"
	pane.add_to_group("pass_key", true)
	side.add_child(pane)
	# Its light is a beam aimed at the door, so the wall it comes from stays dark.
	var spill := SpotLight3D.new()
	spill.name = "WindowLight"
	spill.spot_range = 13.0
	spill.spot_angle = 30.0
	spill.spot_angle_attenuation = 0.6
	spill.spot_attenuation = 0.8
	spill.light_energy = 2.6
	spill.shadow_enabled = true
	spill.light_size = 0.2
	spill.shadow_bias = 0.05
	spill.add_to_group("pass_key", true)
	side.add_child(spill)
	spill.look_at_from_position(window_at + Vector3(0.6, 0.0, 0.0), Vector3(WALL_X, 1.0, DOOR_Z - 0.3))

	# Yard wall with a gate, and the backs of the houses beyond it against the sky.
	_slab(side, Vector3(LEFT_X - 0.4, 0.0, MOUTH_Z), Vector3(LEFT_X, 2.5, 0.5), brick, "YardWall")
	_slab(side, Vector3(LEFT_X - 0.47, 2.5, MOUTH_Z), Vector3(LEFT_X + 0.07, 2.62, 0.5), stone, "Coping")
	for pz: float in [-4.2, -6.4, -12.0, -18.0, MOUTH_Z + 0.25]:
		_slab(side, Vector3(LEFT_X - 0.47, 0.0, pz - 0.25), Vector3(LEFT_X + 0.08, 2.85, pz + 0.25), brick, "GatePier")
	_slab(side, Vector3(LEFT_X - 0.1, 0.0, -6.15), Vector3(LEFT_X + 0.02, 2.1, -4.45), timber, "Gate")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bz := 0.5
	while bz > MOUTH_Z:
		var width := 3.2 + rng.randf() * 1.6
		var height := 5.5 + rng.randf() * 2.5
		var bx := LEFT_X - 9.0 - rng.randf() * 2.0
		_slab(side, Vector3(bx - 8.0, 0.0, bz - width), Vector3(bx, height, bz), dark, "Back")
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(width, 1.6 + rng.randf(), 8.4)
		roof.mesh = prism
		roof.material_override = slate
		roof.name = "Roof"
		roof.position = Vector3(bx - 4.0, height + prism.size.y / 2.0, bz - width / 2.0)
		side.add_child(roof, true)
		var stack := 1.6 + rng.randf() * 1.4
		_slab(side, Vector3(bx - 1.6, height, bz - 0.9), Vector3(bx - 0.8, height + stack, bz - 0.3), dark, "Stack")
		if bz < -9.0 and rng.randf() < 0.45:
			var lit := MeshInstance3D.new()
			var lq := QuadMesh.new()
			lq.size = Vector2(0.8, 1.2)
			lit.mesh = lq
			lit.material_override = StreetBuilder._glow()
			lit.rotation.y = PI / 2.0
			lit.position = Vector3(bx + 0.02, 3.4 + rng.randf() * 1.6, bz - width * (0.3 + rng.randf() * 0.4))
			lit.name = "LitWindow"
			lit.add_to_group("pass_windows", true)
			side.add_child(lit, true)
		bz -= width

	# A dim light in a third colour, the one the lit windows have, low by the gate: without it
	# the alley is all pinks and violets. Baked with the lit windows, so the game colours it as
	# it does those.
	var accent := OmniLight3D.new()
	accent.name = "Accent"
	accent.position = Vector3(LEFT_X + 0.6, 1.0, -5.3)
	accent.omni_range = 4.0
	accent.light_energy = 0.6
	accent.shadow_enabled = true
	accent.add_to_group("pass_windows", true)
	side.add_child(accent)

	# Something to give the near stones scale: a barrel and a crate by the yard wall.
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.28
	cyl.height = 0.95
	barrel.mesh = cyl
	barrel.material_override = timber
	barrel.position = Vector3(LEFT_X + 0.42, 0.475, -2.3)
	barrel.name = "Barrel"
	side.add_child(barrel)
	_slab(side, Vector3(LEFT_X + 0.08, 0.0, -3.6), Vector3(LEFT_X + 0.78, 0.6, -2.85), timber, "Crate")
	return side


## The street the alley opens onto: a lamp on its kerb, deep in the fog, and the houses across it.
static func _mouth(kit: Dictionary) -> Node3D:
	var mouth := Node3D.new()
	mouth.name = "Mouth"
	var lamp := StreetBuilder._post_lamp("pass_key", 1.25, 22.0, 1.5)
	lamp.name = "MouthLamp"
	lamp.position = Vector3(-0.9, 0.0, MOUTH_Z - 3.5)
	lamp.rotation.y = deg_to_rad(45.0)
	mouth.add_child(lamp)
	var houses := StreetBuilder._terrace(kit, [3, 2, 3], 5, 0.3, false)
	houses.name = "Houses"
	houses.position = Vector3(-13.5, 0.0, MOUTH_Z - 10.0)
	mouth.add_child(houses)
	return mouth


## Turns a lantern down: the alley is narrower and darker than the street.
static func _dim(lamp: Node3D, light_range: float, energy: float) -> void:
	var light := lamp.get_node("Lantern/Light") as OmniLight3D
	light.omni_range = light_range
	light.light_energy = energy
