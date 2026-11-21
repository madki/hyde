extends SceneTree
## Turns a downloaded character model (.glb / .gltf / .fbx, anywhere on disk) into the plain
## static mesh the street scenes use for a figure: studio/figures/<name>.res. Desktop only.
##
##   godot --headless --path . -s res://studio/import_figure.gd -- --src=/abs/model.glb \
##       --name=jekyll [--height=1.85 | --scale=1.03] [--tris=100000] [--pose=0.6] [--skip=Stand,Base] [--yaw=0] [--lean=0]
##       [--smooth=8 [--smooth-below=1.5]] [--cut=x0,y0,z0,x1,y1,z1[;...]]
##       [--bones="UpperArm>0,-0.5,1;Head:0,20,0"] [--attach="Hat:Head;Stick:Hand>0,-1,0.1"]
##       [--move="Stick@0,0.8,0.2:0,90,0*1.1"]
##       [--colours[=/abs/colour_map.jpg]]
##
## Only the shape is kept (positions, normals, triangles): the figures are drawn as inked
## silhouettes by studio/figure.gdshader, so textures and materials are not needed.
## `--colours` also keeps the model's colours, one for each corner of the mesh, read from its
## colour textures (or from the one image given, for a model that comes with several colour
## maps), for a figure that is baked into a picture in his own colours (see studio/bake.gd).
## The mesh is cut much finer for it, so give `--tris` room (400000) or it is thinned again.
## `--pose` freezes a rigged model part-way (0..1) through its first animation; without it the
## rest pose is used. `--bones` then moves single bones of that pose, for a pose the model has
## no animation for: `Bone>x,y,z` swings the bone to point along that direction, `Bone:x,y,z`
## turns it by that many degrees about each axis. Both are in the model's own space (y up) and
## are applied in the order given, so list a limb from the shoulder down; `--bones=?` lists the
## bone names. `--attach` makes a loose part of the model (a hat, a stick: a mesh of its own, by
## node name) follow a bone that `--bones` moves, as if held by it; `Node:Bone>x,y,z` also swings
## the part so that its length points along that direction, its origin (a stick's handle) in the
## grip: the place on the bone it was nearest to.
## `--move` puts a loose part where it is wanted, whatever holds it: `Node@x,y,z:rx,ry,rz` sets
## its origin at that place in the model's space, turned by those degrees about each axis from
## the way its mesh was made (for a stick stood on the ground under a man's hands); `*k` after
## the degrees also makes it that many times its size.
## `--skip` leaves out meshes by node name. The result stands on the ground
## at the origin, `--height` metres tall, facing +Z after `--yaw` degrees. `--lean` tips the whole
## figure back by that many degrees before it is stood on the ground, for a man sat back in an
## armchair. `--scale` sizes it by
## a factor instead, for a second pose of a model (seated, say) that has to match the first: the
## factor used is printed on every run.
## `--cut` removes loose pieces of the model (a beard, a prop: any part not joined to the rest)
## that lie wholly inside one of the given boxes, measured in metres on the finished figure.
## Record the model's author, source and licence in CREDITS.md.

const OUT_DIR := "res://studio/figures/"
const COLOUR_GRAIN := 0.013 # with `--colours`, the mesh is cut this fine, in the model's own units


func _initialize() -> void:
	_run()


func _run() -> void:
	var src := Shot.arg("src")
	var fig_name := Shot.arg("name")
	if src == "" or fig_name == "":
		push_error("usage: -- --src=/abs/model.glb --name=jekyll")
		quit(1)
		return
	var doc: GLTFDocument = FBXDocument.new() if src.get_extension().to_lower() == "fbx" \
			else GLTFDocument.new()
	var state: GLTFState = FBXState.new() if doc is FBXDocument else GLTFState.new()
	if doc.append_from_file(src, state) != OK:
		push_error("could not read " + src)
		quit(1)
		return
	var scene: Node3D = doc.generate_scene(state)
	root.add_child(scene)
	if Shot.has_arg("pose"):
		var players := scene.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty() or (players[0] as AnimationPlayer).get_animation_list().is_empty():
			push_warning("--pose given but the model has no animation")
		else:
			var player: AnimationPlayer = players[0]
			var anim := player.get_animation_list()[0]
			player.play(anim)
			player.seek(player.get_animation(anim).length * float(Shot.arg("pose")), true)
			await process_frame
			player.pause() # so the bones moved below stay moved
	var held := hold(scene, Shot.arg("attach"))
	if Shot.has_arg("bones"):
		move_bones(scene, Shot.arg("bones"))
	carry(scene, held)
	place(scene, Shot.arg("move"))
	var colour_map: Image = null
	if Shot.arg("colours") != "":
		colour_map = Image.load_from_file(Shot.arg("colours"))
	var data := flatten(scene, Array(Shot.arg("skip").split(",", false)), Shot.has_arg("colours"),
			colour_map)
	scene.queue_free()
	data = simplify(data, int(Shot.arg("tris")) if Shot.has_arg("tris") else 100000)
	data = stand(data, float(Shot.arg("height")) if Shot.has_arg("height") else 1.85,
			deg_to_rad(float(Shot.arg("yaw"))), float(Shot.arg("scale")),
			deg_to_rad(float(Shot.arg("lean"))))
	for box: String in Shot.arg("cut").split(";", false):
		var c := box.split_floats(",")
		if c.size() == 6:
			data = cut(data, AABB(Vector3(c[0], c[1], c[2]), Vector3(c[3] - c[0], c[4] - c[1], c[5] - c[2])))
	if Shot.has_arg("smooth"):
		data = smooth(data, int(Shot.arg("smooth")),
				float(Shot.arg("smooth-below")) if Shot.has_arg("smooth-below") else INF)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path := OUT_DIR + fig_name + ".res"
	ResourceSaver.save(to_mesh(data), path, ResourceSaver.FLAG_COMPRESS)
	print("wrote ", path, ": ", data[2].size() / 3, " triangles")
	quit()


## Moves bones of the current pose: see `--bones` at the top.
func move_bones(scene: Node3D, moves: String) -> void:
	for skel: Skeleton3D in scene.find_children("*", "Skeleton3D", true, false):
		if moves == "?":
			for b in skel.get_bone_count():
				print(skel.get_bone_name(b))
			continue
		# Directions and turns are given in the model's space; bones live in the skeleton's.
		var to_skel := _to_root(skel, scene).basis.orthonormalized().inverse()
		for move: String in moves.split(";", false):
			var swing := move.contains(">")
			var part := move.split(">" if swing else ":")
			var bone := skel.find_bone(part[0].strip_edges())
			var n := part[1].split_floats(",") if part.size() == 2 else PackedFloat64Array()
			if bone < 0 or n.size() != 3:
				push_warning("--bones: cannot read '%s'" % move)
				continue
			var pose := skel.get_bone_global_pose(bone)
			var turn: Basis
			if swing:
				var kids := skel.get_bone_children(bone)
				if kids.is_empty():
					push_warning("--bones: %s has no end to point with" % part[0])
					continue
				var now := (skel.get_bone_global_pose(kids[0]).origin - pose.origin).normalized()
				turn = Basis(Quaternion(now, (to_skel * Vector3(n[0], n[1], n[2])).normalized()))
			else:
				var model_turn := Basis.from_euler(Vector3(deg_to_rad(n[0]), deg_to_rad(n[1]), deg_to_rad(n[2])))
				turn = to_skel * model_turn * to_skel.inverse()
			pose.basis = turn * pose.basis
			skel.set_bone_global_pose(bone, pose)


## Notes where each part named by `--attach` is, seen from the bone it is to follow.
func hold(scene: Node3D, attach: String) -> Array:
	var held := []
	for item: String in attach.split(";", false):
		var aim := item.split(">")
		var names := aim[0].split(":")
		var node := scene.find_child(names[0].strip_edges(), true, false) as Node3D
		var found := false
		for skel: Skeleton3D in scene.find_children("*", "Skeleton3D", true, false):
			var bone := skel.find_bone(names[1].strip_edges()) if names.size() == 2 else -1
			if node and bone >= 0:
				var bone_xf := _to_root(skel, scene) * skel.get_bone_global_pose(bone)
				var rel := bone_xf.affine_inverse() * _to_root(node, scene)
				held.append({"node": node, "skel": skel, "bone": bone, "rel": rel,
						"grip": _grip(node, rel),
						"aim": aim[1].split_floats(",") if aim.size() == 2 else PackedFloat64Array()})
				found = true
				break
		if not found:
			push_warning("--attach: cannot read '%s'" % item)
	return held


## The way a part's length runs: the longest side of its box, from its origin to the far end.
func _length_of(node: Node3D) -> Vector3:
	if not node is MeshInstance3D:
		return Vector3.UP
	var box := (node as MeshInstance3D).mesh.get_aabb()
	var axis := box.get_longest_axis()
	return -axis if box.get_center().dot(axis) < 0.0 else axis


## Where a bone holds a part, in the bone's space: the point along the bone (bones run along
## their own Y) nearest to the line of the part's length. `rel` is the part seen from the bone.
func _grip(node: Node3D, rel: Transform3D) -> Vector3:
	var a := (rel.basis * _length_of(node)).normalized()
	var b := Vector3.UP
	var w := -rel.origin # from the part's origin to the bone's
	var d := 1.0 - a.dot(b) * a.dot(b)
	if d < 1e-6:
		return Vector3.ZERO
	return b * ((a.dot(b) * a.dot(w) - b.dot(w)) / d)


## Puts the parts noted by `hold` back where their bones now are.
func carry(scene: Node3D, held: Array) -> void:
	for h: Dictionary in held:
		var node: Node3D = h.node
		var skel: Skeleton3D = h.skel
		var xf: Transform3D = _to_root(skel, scene) * skel.get_bone_global_pose(h.bone) * h.rel
		var aim: PackedFloat64Array = h.aim
		if aim.size() == 3 and node is MeshInstance3D:
			# Its length: the longest side of its box, from its origin towards the far end.
			var now := (xf.basis * _length_of(node)).normalized()
			xf.basis = Basis(Quaternion(now, Vector3(aim[0], aim[1], aim[2]).normalized())) * xf.basis
			xf.origin = _to_root(skel, scene) * skel.get_bone_global_pose(h.bone) * (h.grip as Vector3)
		var parent := node.get_parent() as Node3D
		node.transform = (_to_root(parent, scene).affine_inverse() if parent != scene else Transform3D.IDENTITY) * xf


## Puts the parts named by `--move` where it says, keeping their size.
func place(scene: Node3D, moves: String) -> void:
	for item: String in moves.split(";", false):
		var part := item.split("@")
		var sized := part[1].split("*") if part.size() == 2 else PackedStringArray()
		var to := sized[0].split(":") if sized.size() > 0 else PackedStringArray()
		var size := float(sized[1]) if sized.size() == 2 else 1.0
		var node := scene.find_child(part[0].strip_edges(), true, false) as Node3D
		if node == null or to.size() != 2 or to[0].split_floats(",").size() != 3 \
				or to[1].split_floats(",").size() != 3:
			push_warning("--move: cannot read '%s'" % item)
			continue
		var at := to[0].split_floats(",")
		var turn := to[1].split_floats(",")
		var basis := Basis.from_euler(Vector3(deg_to_rad(turn[0]), deg_to_rad(turn[1]), deg_to_rad(turn[2]))) \
				* Basis.from_scale(_to_root(node, scene).basis.get_scale() * size)
		var parent := node.get_parent() as Node3D
		node.transform = (_to_root(parent, scene).affine_inverse() if parent != scene else Transform3D.IDENTITY) \
				* Transform3D(basis, Vector3(at[0], at[1], at[2]))


## All meshes under `scene` flattened into one (positions + normals + indices, in `scene` space),
## skinned to the skeleton's current pose where there is one. `skip` = node names to leave out.
## With `colours` a fourth array holds each vertex's colour, read from its surface's colour
## texture, or from `colour_map` if one is given.
func flatten(scene: Node3D, skip: Array, colours := false, colour_map: Image = null) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var cols := PackedColorArray()
	var images := {} # texture -> its image, read once
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) in skip:
			continue
		var xf := _to_root(mi, scene)
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var mats: Array[Transform3D] = []
		if skel and mi.skin:
			var skel_xf := _to_root(skel, scene)
			for b in mi.skin.get_bind_count():
				var bone := mi.skin.get_bind_bone(b)
				if bone < 0:
					bone = skel.find_bone(mi.skin.get_bind_name(b))
				mats.append(skel_xf * skel.get_bone_global_pose(bone) * mi.skin.get_bind_pose(b))
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var base := verts.size()
			var img := colour_map
			var flat := Color.WHITE
			var uv: Variant = a[Mesh.ARRAY_TEX_UV]
			if colours:
				var mat := mi.get_active_material(s) as BaseMaterial3D
				if mat:
					if img == null and mat.albedo_texture:
						if not images.has(mat.albedo_texture):
							var read := mat.albedo_texture.get_image()
							if read.is_compressed():
								read.decompress()
							images[mat.albedo_texture] = read
						img = images[mat.albedo_texture]
					if colour_map == null:
						flat = mat.albedo_color
				for i in v.size():
					var c := flat
					if img and uv is PackedVector2Array:
						var at: Vector2 = (uv as PackedVector2Array)[i].posmod(1.0) * Vector2(img.get_size() - Vector2i.ONE)
						c = flat * img.get_pixelv(Vector2i(at))
					cols.append(c.srgb_to_linear())
			if mats.is_empty():
				for i in v.size():
					verts.append(xf * v[i])
					norms.append((xf.basis * n[i]).normalized())
			else:
				var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
				var per := bones.size() / v.size()
				for i in v.size():
					var p := Vector3.ZERO
					var q := Vector3.ZERO
					for k in per:
						var w := weights[i * per + k]
						if w > 0.0:
							var m := mats[bones[i * per + k]]
							p += (m * v[i]) * w
							q += (m.basis * n[i]) * w
					verts.append(p)
					norms.append(q.normalized())
			var si: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			if colours and img and uv is PackedVector2Array:
				_fine(verts, norms, cols, idx, base, si, uv, img, flat)
				continue
			for i in si:
				idx.append(base + i)
	return [verts, norms, idx, cols]


## Adds the triangles `si` (corners at `base` + index in `verts`) cut up into pieces no more
## than COLOUR_GRAIN across, each new corner coloured from `img` at its own place on the
## texture: colours are kept at the mesh's corners, so this is what lets them show the
## texture's drawing (a face, buttons) on a model with few, large triangles.
func _fine(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		idx: PackedInt32Array, base: int, si: PackedInt32Array, uv: PackedVector2Array,
		img: Image, flat: Color) -> void:
	var last := Vector2(img.get_size() - Vector2i.ONE)
	for t in range(0, si.size(), 3):
		var ia := si[t]
		var ib := si[t + 1]
		var ic := si[t + 2]
		var pa := verts[base + ia]
		var pb := verts[base + ib]
		var pc := verts[base + ic]
		var longest := maxf(pa.distance_to(pb), maxf(pb.distance_to(pc), pc.distance_to(pa)))
		var n := clampi(ceili(longest / COLOUR_GRAIN), 1, 64)
		var first := verts.size()
		# Rows run from corner a towards corner b, each a corner shorter than the one before.
		for r in n + 1:
			for c in n + 1 - r:
				var wb := float(r) / n
				var wc := float(c) / n
				var wa := 1.0 - wb - wc
				verts.append(pa * wa + pb * wb + pc * wc)
				norms.append((norms[base + ia] * wa + norms[base + ib] * wb
						+ norms[base + ic] * wc).normalized())
				var at := (uv[ia] * wa + uv[ib] * wb + uv[ic] * wc).posmod(1.0) * last
				cols.append((flat * img.get_pixelv(Vector2i(at))).srgb_to_linear())
		for r in n:
			var row := first + r * (n + 1) - r * (r - 1) / 2
			var next := row + n + 1 - r
			for c in n - r:
				idx.append_array([row + c, next + c, row + c + 1])
				if c < n - r - 1:
					idx.append_array([next + c, next + c + 1, row + c + 1])


func _to_root(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Reduces to roughly `target_tris` triangles and drops unused vertices.
func simplify(data: Array, target_tris: int) -> Array:
	var idx: PackedInt32Array = data[2]
	if idx.size() / 3 > target_tris:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data[0]
		arrays[Mesh.ARRAY_NORMAL] = data[1]
		arrays[Mesh.ARRAY_INDEX] = idx
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		im.generate_lods(25.0, 60.0, [])
		for l in im.get_surface_lod_count(0):
			var li := im.get_surface_lod_indices(0, l)
			if li.size() < idx.size():
				idx = li
			if li.size() / 3 <= target_tris:
				break
	var remap := {}
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var out := PackedInt32Array()
	var cols := _colours(data)
	var c := PackedColorArray()
	for i in idx:
		if not remap.has(i):
			remap[i] = v.size()
			v.append(data[0][i])
			n.append(data[1][i])
			if not cols.is_empty():
				c.append(cols[i])
		out.append(remap[i])
	return [v, n, out, c]


## The vertex colours that go with `data`, empty if it has none.
func _colours(data: Array) -> PackedColorArray:
	return data[3] if data.size() > 3 else PackedColorArray()


## Stands the figure on the ground at the origin, `height` metres tall, turned by `yaw`.
## A `scale` above 0 is used instead of `height`.
func stand(data: Array, height: float, yaw: float, scale := 0.0, lean := 0.0) -> Array:
	var v: PackedVector3Array = data[0]
	var n: PackedVector3Array = data[1]
	var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -lean)
	var box := AABB(rot * v[0], Vector3.ZERO)
	for i in v.size():
		v[i] = rot * v[i]
		n[i] = rot * n[i]
		box = box.expand(v[i])
	var k := scale if scale > 0.0 else height / box.size.y
	print("scaled by ", k)
	var off := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	for i in v.size():
		v[i] = (v[i] - off) * k
	return [v, n, data[2], _colours(data)]


## Evens out the normals over `passes` rounds of averaging each with its neighbours', leaving
## the shape alone. Sculpted detail (creases, buttons, chains) otherwise shows up as speckle in
## the inked shading, which is drawn from the normals.
## Above `below` metres the model's own normals are kept (fading in over 8 cm), so a face can
## stay sharp over smoothed clothes.
func smooth(data: Array, passes: int, below: float = INF) -> Array:
	var v: PackedVector3Array = data[0]
	var idx: PackedInt32Array = data[2]
	# Vertices at the same place share one normal.
	var spot := {}
	var of := PackedInt32Array()
	of.resize(v.size())
	for i in v.size():
		var key := Vector3i(v[i] * 20000.0)
		if not spot.has(key):
			spot[key] = spot.size()
		of[i] = spot[key]
	var cur := PackedVector3Array()
	cur.resize(spot.size())
	for t in range(0, idx.size(), 3):
		var face := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		for k in 3:
			cur[of[idx[t + k]]] -= face # area-weighted; Godot winds triangles clockwise
	var agree := 0.0
	for i in v.size():
		agree += cur[of[i]].normalized().dot(data[1][i])
	for i in cur.size():
		cur[i] = cur[i].normalized() * signf(agree) # keep the side the model's own normals face
	for p in passes:
		var next := cur.duplicate()
		for t in range(0, idx.size(), 3):
			var a := of[idx[t]]
			var b := of[idx[t + 1]]
			var c := of[idx[t + 2]]
			next[a] += cur[b] + cur[c]
			next[b] += cur[a] + cur[c]
			next[c] += cur[a] + cur[b]
		for i in next.size():
			next[i] = next[i].normalized()
		cur = next
	var n := PackedVector3Array()
	n.resize(v.size())
	for i in v.size():
		var keep := smoothstep(below, below + 0.08, v[i].y)
		n[i] = cur[of[i]].lerp(data[1][i], keep).normalized()
	return [v, n, idx, _colours(data)]


func to_mesh(data: Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data[0]
	arrays[Mesh.ARRAY_NORMAL] = data[1]
	arrays[Mesh.ARRAY_INDEX] = data[2]
	if not _colours(data).is_empty():
		arrays[Mesh.ARRAY_COLOR] = _colours(data)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Drops every loose piece (triangles joined to each other but to nothing else) that lies
## wholly inside `box`.
func cut(data: Array, box: AABB) -> Array:
	var v: PackedVector3Array = data[0]
	var idx: PackedInt32Array = data[2]
	# Vertices at the same spot count as one, so seams do not split a piece.
	var group := PackedInt32Array()
	group.resize(v.size())
	var seen := {}
	for i in v.size():
		var key := Vector3i(v[i] * 20000.0)
		group[i] = seen.get_or_add(key, i)
	for t in range(0, idx.size(), 3):
		var a := _group_of(group, idx[t])
		for k: int in [1, 2]:
			var b := _group_of(group, idx[t + k])
			if b != a:
				group[b] = a
	var inside := {} # piece -> every vertex so far is inside the box
	var size := {}
	for t in range(0, idx.size(), 3):
		var g := _group_of(group, idx[t])
		size[g] = size.get(g, 0) + 1
		for k in 3:
			inside[g] = inside.get(g, true) and box.has_point(v[idx[t + k]])
	var kept := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if not inside[_group_of(group, idx[t])]:
			kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
	for g: int in inside:
		if inside[g]:
			print("cut a piece of ", size[g], " triangles")
	return simplify([v, data[1], kept, _colours(data)], kept.size())


func _group_of(group: PackedInt32Array, i: int) -> int:
	while group[i] != i:
		group[i] = group[group[i]]
		i = group[i]
	return i
