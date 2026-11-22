extends Object
## What the bakes of the figure layers share (studio/title_figure_bake.gd for the title's two
## men, studio/alley_figure_bake.gd for the man in the alley). A figure layer is drawn over the
## baked picture by shaders/background.gdshader; its sheet holds drawing data in RGB (see
## studio/figure_data.gdshaderinc) and how much of the pixel the figure covers in A. Desktop only.

const MAX_LAMPS := 8 # as in studio/figure_data.gdshaderinc


## The lamps of `street` in `group` nearest to `near`: [places and reaches, brightnesses],
## padded to MAX_LAMPS.
static func _lamps(street: Node3D, group: String, near: Vector3) -> Array:
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


## Whether the figure runs off the left, top or right of the frame (the bottom always does).
static func _touches_edge(img: Image) -> bool:
	var last := img.get_width() - 1
	for i in img.get_width():
		if img.get_pixel(i, 0).a > 0.05 or img.get_pixel(0, i).a > 0.05 or img.get_pixel(last, i).a > 0.05:
			return true
	return false


static func _in_scene(node: Node3D, scene: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != scene and cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
