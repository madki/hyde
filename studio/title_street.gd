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
