class_name TitleStreet
## Where the two men stand on the title screen: out in the road, towards the lamp post, further
## from the camera than in the game, so that they are seen down to their feet.
##
## The men themselves are a figure layer, as in the game (studio/title_figure_bake.gd). The
## streets are baked again for the title with each man standing in his place unseen
## (studio/bake.gd, `--variant=title_jekyll` / `title_hyde`), so that the picture has the
## shadow he throws under the street's lamps and he does not seem to float. tools/bake_title.sh
## does all of it. The game's own street scenes are not changed: the man is moved after they
## are loaded.

## Where both men stand: on the cobbles, seven metres or so from the camera.
const STAND := Vector3(1.2, 0.0, -1.6)
## Each man's mesh (studio/figures/<man>_<pose>.res), the way he is turned, in degrees, and his
## size. Jekyll faces the camera, head bowed, both hands on his stick; Hyde is as he is in the
## game.
const MEN := {
	"jekyll": {"pose": "title", "yaw": 0.0, "scale": 1.0},
	"hyde": {"pose": "", "yaw": 25.0, "scale": 0.88},
}

## One more lamp on the lit wall, nearer the camera than the picture's right edge, so it is
## never seen itself. It is shaded so that it shines down: it lights the foot of the near wall
## and the pavement in the bottom right corner, which the street's own lamps leave dark, and
## not the brickwork above. It burns with the wall lanterns.
const SIDE_LAMP := Vector3(3.5, 2.3, 4.0)
const SIDE_LAMP_AIM := Vector3(3.9, 0.0, 1.6) # the point on the pavement it shines at
const SIDE_LAMP_ANGLE := 38.0
const SIDE_LAMP_RANGE := 8.0
const SIDE_LAMP_ENERGY := 2.5

# A wall lantern hangs so close to the wall that its light burns the bricks behind it and only
# grazes the wall further along. For the title each lantern's own light is turned down, and
# keeps only its glow in the air; the wall is lit by a second light out over the pavement,
# which meets it at a better angle and reaches further.
const LANTERN_DIMMED := 0.35 # what is left of a wall lantern's own light
const THROW_OUT := 0.9 # metres from the lantern, away from the wall, to the light that takes over
const THROW_ENERGY := 0.7
const THROW_RANGE := 16.0
const THROW_ATTENUATION := 1.0 # the street's lamps use 1.4: lower fades more slowly

# A pool of light on the cobbles where the men stand, from above and behind them on the lamp
# post's side, in the colour of the post's lamp. It sets them apart from the street and gives
# their shadows light to fall across; the men themselves are a layer of their own and are not
# lit by it.
const POOL_FROM := Vector3(-0.7, 3.4, -1.9) # where it shines from, from where they stand
const POOL_AIM := Vector3(0.0, 0.0, 0.6) # the point on the ground it shines at, likewise
# How wide the pool is, in degrees, and how bright, for each street. Jekyll's lamp colour is
# far brighter to the eye than Hyde's, so his pool is dimmer; Hyde's is narrower and stronger,
# so that it holds together as one pool.
const POOL := {
	"jekyll": {"angle": 24.0, "energy": 4.5},
	"hyde": {"angle": 18.0, "energy": 12.0},
}

# A few dim lights in a third colour, the one the lit windows have, where a street would
# otherwise be all one hue: each is [place, reach in metres, brightness]. Hyde's street is
# all pinks and violets, and its windows are green.
const ACCENTS := {
	"hyde": [
		[Vector3(3.9, 1.0, 2.6), 4.0, 0.6], # low by the near door
		[Vector3(3.8, 0.8, -6.0), 5.0, 0.5], # along the foot of the wall
		[Vector3(-0.5, 0.5, -8.0), 6.0, 0.4], # far kerb, across the road
	],
}

# It has rained: the cobbles are smoother than the game's, so the lamps streak across them and (with studio/bake.gd's reflections) the lit wall shows in them.
const WET_ROUGHNESS := 0.65 # of how rough the ground is in the game


## `man` ("jekyll" / "hyde") standing in his place.
static func figure(man: String) -> Node3D:
	var fig := FigureBuilder.build(man, MEN[man].pose)
	fig.position = STAND
	fig.rotation.y = deg_to_rad(MEN[man].yaw)
	fig.scale = Vector3.ONE * MEN[man].scale
	return fig


## Puts `man` in his place in `street`, a street scene just loaded, instead of the game's
## figure. He is not drawn into the picture, only his shadow is.
static func stage(street: Node3D, man: String) -> void:
	for old: String in ["Jekyll", "Hyde"]:
		var node := street.get_node_or_null(old)
		if node:
			node.free()
	var fig := figure(man)
	fig.get_node("Body").add_to_group("casts_shadow", true)
	street.add_child(fig)
	_even_out(street)
	_pool(street, man)
	_accents(street, man)
	_wet(street)
	var side := SpotLight3D.new()
	side.name = "SideLamp"
	street.add_child(side)
	side.look_at_from_position(SIDE_LAMP, SIDE_LAMP_AIM)
	side.spot_range = SIDE_LAMP_RANGE
	side.spot_angle = SIDE_LAMP_ANGLE
	side.spot_angle_attenuation = 0.5 # a soft edge to its pool of light
	side.light_energy = SIDE_LAMP_ENERGY
	side.light_volumetric_fog_energy = 0.0 # its beam must not show in the air
	side.shadow_enabled = true
	side.add_to_group("pass_wall", true)


## Spreads the wall lanterns' light more evenly along the wall: see `LANTERN_DIMMED`.
static func _even_out(street: Node3D) -> void:
	for light: OmniLight3D in street.find_children("*", "OmniLight3D", true, false):
		var lamp := light.get_parent().get_parent() # the lantern's own light is two levels in
		if lamp == null or not String(lamp.name).begins_with("WallLamp"):
			continue
		var thrown := OmniLight3D.new()
		thrown.name = "Throw"
		thrown.omni_range = THROW_RANGE
		thrown.omni_attenuation = THROW_ATTENUATION
		thrown.light_energy = THROW_ENERGY
		thrown.light_volumetric_fog_energy = 0.0 # the glow in the air stays round the lantern
		thrown.shadow_enabled = true
		thrown.shadow_bias = light.shadow_bias
		thrown.shadow_caster_mask = light.shadow_caster_mask
		thrown.add_to_group("pass_wall", true)
		street.add_child(thrown)
		thrown.global_position = light.global_position + Vector3.LEFT * THROW_OUT
		light.light_volumetric_fog_energy = light.light_volumetric_fog_energy / LANTERN_DIMMED
		light.light_energy *= LANTERN_DIMMED


## Wets the ground: see `WET_ROUGHNESS`.
static func _wet(street: Node3D) -> void:
	var ground := street.get_node_or_null("Ground")
	if ground == null:
		return
	for part: MeshInstance3D in ground.find_children("*", "MeshInstance3D", true, false):
		var mat := part.material_override as StandardMaterial3D
		# Only the cobbles: the pavement is flat, and wet it shows the lanterns like a mirror.
		if mat and part.name == &"Cobbles":
			mat = mat.duplicate() as StandardMaterial3D # the game's street keeps its own
			mat.roughness *= WET_ROUGHNESS
			part.material_override = mat


## The pool of light the men stand in: see `POOL_FROM`.
static func _pool(street: Node3D, man: String) -> void:
	var pool := SpotLight3D.new()
	pool.name = "FigurePool"
	street.add_child(pool)
	pool.look_at_from_position(STAND + POOL_FROM, STAND + POOL_AIM)
	pool.spot_range = 10.0
	pool.spot_angle = POOL[man].angle
	pool.spot_angle_attenuation = 0.5 # a soft edge
	pool.light_energy = POOL[man].energy
	pool.light_volumetric_fog_energy = 0.0 # no beam in the air
	pool.shadow_enabled = true
	pool.add_to_group("pass_key", true)


## The street's lights in a third colour: see `ACCENTS`. They are baked with the lit windows,
## so the game colours them as it does those.
static func _accents(street: Node3D, man: String) -> void:
	for accent: Array in ACCENTS.get(man, []):
		var light := OmniLight3D.new()
		light.name = "Accent"
		light.position = accent[0]
		light.omni_range = accent[1]
		light.light_energy = accent[2]
		light.shadow_enabled = true
		light.add_to_group("pass_windows", true)
		street.add_child(light, true)
