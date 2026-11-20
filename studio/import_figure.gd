extends SceneTree
## Turns a downloaded character model (.glb / .gltf / .fbx, anywhere on disk) into the plain
## static mesh the street scenes use for a figure: studio/figures/<name>.res. Desktop only.
##
##   godot --headless --path . -s res://studio/import_figure.gd -- --src=/abs/model.glb \
##       --name=jekyll [--height=1.85] [--tris=100000] [--pose=0.6] [--skip=Stand,Base] [--yaw=0]
##       [--smooth=8 [--smooth-below=1.5]] [--cut=x0,y0,z0,x1,y1,z1[;...]]
##
## Only the shape is kept (positions, normals, triangles): the figures are drawn as inked
## silhouettes by studio/figure.gdshader, so textures and materials are not needed.
## `--pose` freezes a rigged model part-way (0..1) through its first animation; without it the
## rest pose is used. `--skip` leaves out meshes by node name. The result stands on the ground
## at the origin, `--height` metres tall, facing +Z after `--yaw` degrees.
## `--cut` removes loose pieces of the model (a beard, a prop: any part not joined to the rest)
## that lie wholly inside one of the given boxes, measured in metres on the finished figure.
## Record the model's author, source and licence in CREDITS.md.

const OUT_DIR := "res://studio/figures/"


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
	var data := flatten(scene, Array(Shot.arg("skip").split(",", false)))
	scene.queue_free()
	data = simplify(data, int(Shot.arg("tris")) if Shot.has_arg("tris") else 100000)
	data = stand(data, float(Shot.arg("height")) if Shot.has_arg("height") else 1.85,
			deg_to_rad(float(Shot.arg("yaw"))))
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


## All meshes under `scene` flattened into one (positions + normals + indices, in `scene` space),
## skinned to the skeleton's current pose where there is one. `skip` = node names to leave out.
func flatten(scene: Node3D, skip: Array) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
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
			for i in si:
				idx.append(base + i)
	return [verts, norms, idx]


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
	for i in idx:
		if not remap.has(i):
			remap[i] = v.size()
			v.append(data[0][i])
			n.append(data[1][i])
		out.append(remap[i])
	return [v, n, out]


## Stands the figure on the ground at the origin, `height` metres tall, turned by `yaw`.
func stand(data: Array, height: float, yaw: float) -> Array:
	var v: PackedVector3Array = data[0]
	var n: PackedVector3Array = data[1]
	var rot := Basis(Vector3.UP, yaw)
	var box := AABB(rot * v[0], Vector3.ZERO)
	for i in v.size():
		v[i] = rot * v[i]
		n[i] = rot * n[i]
		box = box.expand(v[i])
	var k := height / box.size.y
	var off := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	for i in v.size():
		v[i] = (v[i] - off) * k
	return [v, n, data[2]]


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
	return [v, n, idx]


func to_mesh(data: Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data[0]
	arrays[Mesh.ARRAY_NORMAL] = data[1]
	arrays[Mesh.ARRAY_INDEX] = data[2]
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
	return simplify([v, data[1], kept], kept.size())


func _group_of(group: PackedInt32Array, i: int) -> int:
	while group[i] != i:
		group[i] = group[group[i]]
		i = group[i]
	return i
