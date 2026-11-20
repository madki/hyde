class_name FigureSdf
## Turns a figure mesh (studio/figures/<name>.res) into a signed distance field: a 3D grid that
## holds, for every point around the figure, how far it is from the surface (negative inside).
## Two fields can be blended, swollen and joined smoothly, which two unrelated meshes cannot;
## studio/figure_bake.gd uses that to draw one figure turning into the other. Desktop only.
##
## The solid is found by carving: the mesh is drawn from 13 directions and a grid cell is kept
## only if it lies between the nearest and furthest surface in every one of them. That works on
## models that are not watertight, at the price of filling hollows no direction can see into.
##
## Building takes a while in GDScript, so the result is kept in studio/cache/ (not committed)
## and only rebuilt when the mesh file or the settings below change.

const VOXEL := 0.008 # grid cell size in metres
const THICKEN := 0.003 # metres added all round so thin parts survive the smoothing
const RASTER := 2 # pixels per grid cell when the mesh is drawn for carving
const PAD := 0.12 # empty margin kept around the figure, in metres
const VERSION := 4 # bump to throw away cached fields after changing this file
const FIGURES := "res://studio/figures/"
const CACHE := "res://studio/cache/"
const _BIG := 1e10


## The field for figure `fig_name`: { "size": Vector3i, "box": AABB, "texture": ImageTexture3D }.
## `box` is the part of the figure's own space the grid covers; distances are in metres.
static func load_or_build(fig_name: String) -> Dictionary:
	var mesh_path := FIGURES + fig_name + ".res"
	var cache_path := CACHE + fig_name + ".sdf"
	var stamp := "%d/%d/%s/%s/%d" % [VERSION, FileAccess.get_modified_time(mesh_path), VOXEL, PAD, RASTER]
	var field := {}
	if FileAccess.file_exists(cache_path):
		var f := FileAccess.open(cache_path, FileAccess.READ)
		var saved: Variant = f.get_var()
		if saved is Dictionary and saved.get("stamp", "") == stamp:
			field = saved
	if field.is_empty():
		var began := Time.get_ticks_msec()
		field = build(load(mesh_path) as Mesh)
		field["stamp"] = stamp
		DirAccess.make_dir_recursive_absolute(CACHE)
		FileAccess.open(cache_path, FileAccess.WRITE).store_var(field)
		print("built distance field for ", fig_name, " ", field.size, " in ",
				(Time.get_ticks_msec() - began) / 1000.0, " s")
	var n: Vector3i = field.size
	var bytes: PackedByteArray = field.data
	var slices: Array[Image] = []
	var slice_bytes := n.x * n.y * 4
	for z in n.z:
		slices.append(Image.create_from_data(n.x, n.y, false, Image.FORMAT_RF,
				bytes.slice(z * slice_bytes, (z + 1) * slice_bytes)))
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RF, n.x, n.y, n.z, false, slices)
	return {"size": n, "box": field.box, "texture": tex}


## { "size": Vector3i, "box": AABB, "data": PackedByteArray of 32-bit floats, x fastest }.
static func build(mesh: Mesh) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var box := AABB(verts[0], Vector3.ZERO)
	for p in verts:
		box = box.expand(p)
	box = box.grow(PAD)
	var n := Vector3i((box.size / VOXEL).ceil())
	box.size = Vector3(n) * VOXEL

	var solid := PackedByteArray()
	solid.resize(n.x * n.y * n.z)
	solid.fill(1)
	for a: Vector3 in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1),
			Vector3(1, 1, 0), Vector3(1, -1, 0), Vector3(1, 0, 1), Vector3(1, 0, -1),
			Vector3(0, 1, 1), Vector3(0, 1, -1), Vector3(1, 1, 1), Vector3(1, 1, -1),
			Vector3(1, -1, 1), Vector3(1, -1, -1)]:
		_carve(solid, n, box.position, verts, idx, a.normalized())

	# Distance to the surface from both sides, measured between cell centres: the surface
	# itself sits half a cell in from the first cell of the other kind.
	var outside := _distance_to(solid, 1, n)
	var inside := _distance_to(solid, 0, n)
	var field := PackedFloat32Array()
	field.resize(solid.size())
	for i in solid.size():
		if solid[i] == 1:
			field[i] = -(sqrt(inside[i]) - 0.5) * VOXEL
		else:
			field[i] = (sqrt(outside[i]) - 0.5) * VOXEL
	# The carved solid is made of whole cells; a light blur takes the steps out of the surface.
	# Blurring would erase parts one cell thick, so everything is first made a touch fatter.
	for i in field.size():
		field[i] -= THICKEN
	for axis in 3:
		_blur_axis(field, n, axis)
	return {"size": n, "box": box, "data": field.to_byte_array()}


## Clears every cell of `solid` that, seen along `dir`, is in front of the nearest surface or
## behind the furthest one.
static func _carve(solid: PackedByteArray, n: Vector3i, origin: Vector3,
		verts: PackedVector3Array, idx: PackedInt32Array, dir: Vector3) -> void:
	var side := (Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).cross(dir).normalized()
	var up := dir.cross(side)
	var inv := RASTER / VOXEL
	# Project the mesh onto the plane facing `dir`, in pixels a fraction of a grid cell wide.
	var count := verts.size()
	var pu := PackedFloat32Array()
	var pv := PackedFloat32Array()
	var pw := PackedFloat32Array()
	pu.resize(count)
	pv.resize(count)
	pw.resize(count)
	var u_min := INF
	var v_min := INF
	var u_max := -INF
	var v_max := -INF
	for i in count:
		var p := verts[i]
		var u := p.dot(side) * inv
		var v := p.dot(up) * inv
		pu[i] = u
		pv[i] = v
		pw[i] = p.dot(dir)
		u_min = minf(u_min, u)
		v_min = minf(v_min, v)
		u_max = maxf(u_max, u)
		v_max = maxf(v_max, v)
	u_min = floorf(u_min) - 1.0
	v_min = floorf(v_min) - 1.0
	var res_u := int(ceilf(u_max - u_min)) + 2
	var res_v := int(ceilf(v_max - v_min)) + 2
	var near := PackedFloat32Array()
	var far := PackedFloat32Array()
	near.resize(res_u * res_v)
	far.resize(res_u * res_v)
	near.fill(INF)
	far.fill(-INF)
	for t in range(0, idx.size(), 3):
		var ia := idx[t]
		var ib := idx[t + 1]
		var ic := idx[t + 2]
		var ax := pu[ia] - u_min
		var ay := pv[ia] - v_min
		var bx := pu[ib] - u_min
		var by := pv[ib] - v_min
		var cx := pu[ic] - u_min
		var cy := pv[ic] - v_min
		var area := (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
		if absf(area) < 1e-9:
			continue
		var aw := pw[ia]
		var bw := pw[ib]
		var cw := pw[ic]
		var x0 := maxi(int(ceilf(minf(ax, minf(bx, cx)) - 0.5)), 0)
		var x1 := mini(int(floorf(maxf(ax, maxf(bx, cx)) - 0.5)), res_u - 1)
		var y0 := maxi(int(ceilf(minf(ay, minf(by, cy)) - 0.5)), 0)
		var y1 := mini(int(floorf(maxf(ay, maxf(by, cy)) - 0.5)), res_v - 1)
		for y in range(y0, y1 + 1):
			var py := y + 0.5
			for x in range(x0, x1 + 1):
				var px := x + 0.5
				var wa := ((bx - px) * (cy - py) - (by - py) * (cx - px)) / area
				if wa < -1e-4:
					continue
				var wb := ((cx - px) * (ay - py) - (cy - py) * (ax - px)) / area
				if wb < -1e-4:
					continue
				var wc := 1.0 - wa - wb
				if wc < -1e-4:
					continue
				var depth := wa * aw + wb * bw + wc * cw
				var at := y * res_u + x
				if depth < near[at]:
					near[at] = depth
				if depth > far[at]:
					far[at] = depth

	# Thin parts seen edge-on (a hat brim) can slip between pixel centres: let every pixel
	# also take the range of its neighbours, so they are kept, a hair fatter.
	_spread(near, far, res_u, res_v, 1)
	_spread(near, far, res_u, res_v, res_u)

	var step_u := side.x * RASTER
	var step_v := up.x * RASTER
	var step_w := dir.x * VOXEL
	var i := 0
	for z in n.z:
		for y in n.y:
			var p := origin + Vector3(0.5, y + 0.5, z + 0.5) * VOXEL
			var u := p.dot(side) * inv - u_min
			var v := p.dot(up) * inv - v_min
			var w := p.dot(dir)
			for x in n.x:
				if solid[i] == 1:
					var at := int(v) * res_u + int(u)
					if u < 0.0 or v < 0.0 or int(u) >= res_u or int(v) >= res_v \
							or w < near[at] or w > far[at]:
						solid[i] = 0
				i += 1
				u += step_u
				v += step_v
				w += step_w


## Widens each pixel's depth range to include its two neighbours `stride` apart.
static func _spread(near: PackedFloat32Array, far: PackedFloat32Array, res_u: int, res_v: int,
		stride: int) -> void:
	var near_in := near.duplicate()
	var far_in := far.duplicate()
	var last := res_u * res_v - stride
	for at in range(stride, last):
		near[at] = minf(near_in[at], minf(near_in[at - stride], near_in[at + stride]))
		far[at] = maxf(far_in[at], maxf(far_in[at - stride], far_in[at + stride]))


## Squared distance, in cells, from every cell to the nearest one whose `solid` value is `want`.
## (Felzenszwalb and Huttenlocher's exact distance transform, one axis at a time.)
static func _distance_to(solid: PackedByteArray, want: int, n: Vector3i) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(solid.size())
	for i in solid.size():
		d[i] = 0.0 if solid[i] == want else _BIG
	var strides := [1, n.x, n.x * n.y]
	for axis in 3:
		var length: int = n[axis]
		var stride: int = strides[axis]
		var a1 := (axis + 1) % 3
		var a2 := (axis + 2) % 3
		var f := PackedFloat32Array()
		var site := PackedInt32Array()
		var bound := PackedFloat32Array()
		f.resize(length)
		site.resize(length)
		bound.resize(length + 1)
		for j in n[a2]:
			for k in n[a1]:
				var start: int = j * strides[a2] + k * strides[a1]
				var any := false
				for q in length:
					var value := d[start + q * stride]
					f[q] = value
					if value < _BIG:
						any = true
				if not any:
					continue
				var top := 0
				site[0] = 0
				bound[0] = -_BIG
				bound[1] = _BIG
				for q in range(1, length):
					var fq := f[q] + q * q
					var p := site[top]
					var cross := (fq - (f[p] + p * p)) / (2.0 * q - 2.0 * p)
					while cross <= bound[top]:
						top -= 1
						p = site[top]
						cross = (fq - (f[p] + p * p)) / (2.0 * q - 2.0 * p)
					top += 1
					site[top] = q
					bound[top] = cross
					bound[top + 1] = _BIG
				top = 0
				for q in length:
					while bound[top + 1] < q:
						top += 1
					var p := site[top]
					d[start + q * stride] = (q - p) * (q - p) + f[p]
	return d


## One 1-2-1 blur pass along one axis, in place.
static func _blur_axis(field: PackedFloat32Array, n: Vector3i, axis: int) -> void:
	var strides := [1, n.x, n.x * n.y]
	var length: int = n[axis]
	var stride: int = strides[axis]
	var a1 := (axis + 1) % 3
	var a2 := (axis + 2) % 3
	for j in n[a2]:
		for k in n[a1]:
			var at: int = j * strides[a2] + k * strides[a1]
			var before := field[at]
			for q in length - 1:
				var here := field[at]
				field[at] = (before + here * 2.0 + field[at + stride]) * 0.25
				before = here
				at += stride
			field[at] = (before + field[at] * 3.0) * 0.25
