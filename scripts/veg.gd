class_name Vegetation
extends Node3D
## Streams plants around the camera from the map masks, the same groups as the browser build (forest, open, town,
## beach, wet, understory, edge) plus grass. Trees in 256 m cells out to TREE_R, scrub in 64 m cells, grass in 32 m.
## Everything is deterministic: the same spot always grows the same plants.

const X0 := -8960.0
const Z0 := -16960.0
const MPX := 10.0
var TREE_R := 750.0
var UNDER_R := 110.0
var GRASS_R := 55.0
var SCAN_R := 26.0             # scanned grass clumps out to here, the lighter procedural blades beyond

# key, groups it grows in (weight) — from VEG_DEF
const DEF := {
	"jungle": {"forest": 1.0}, "island1": {"forest": 0.9, "open": 0.3},
	"rubberfig": {"forest": 0.5, "wet": 0.6, "town": 0.3}, "ghostgum": {"forest": 0.7, "open": 1.0}, "tree2": {"open": 0.8, "town": 0.5, "forest": 0.3},
	"coconut": {"beach": 1.0, "town": 0.5}, "palms": {"beach": 0.8, "wet": 0.4, "town": 0.5}, "palm4": {"town": 0.7, "beach": 0.4, "wet": 0.3},
	"banana": {"wet": 0.8, "town": 0.5}, "bamboo": {"wet": 1.0}, "jacaranda": {"town": 0.8, "open": 0.4},
	"fern": {"under": 1.0}, "fern2": {"under": 1.0, "edge": 0.3}, "monstera": {"under": 0.6}, "elephant": {"under": 0.6, "wet": 0.2},
	"bush1": {"edge": 1.0, "under": 0.4}, "shrub1": {"edge": 0.8}, "shrub4": {"edge": 0.8}, "weed": {"edge": 0.6},
}
const TREES := ["jungle", "island1", "rubberfig", "ghostgum", "tree2", "coconut", "palms", "palm4", "banana", "bamboo", "jacaranda"]
const SMALL := ["fern", "fern2", "monstera", "elephant", "bush1", "shrub1", "shrub4", "weed"]

var terrain: Terrain3D
var mask: Image
var mask2: Image
var roadmask: Image       # 5 m clearance from the nearest road edge: (m + 10) x 10
var meshes := {}
var groups := {}        # group -> [[key, weight], ...]
var grass_mesh: ArrayMesh
var scan_meshes: Array = []     # photogrammetry grass and weed clumps, one mesh per variant
var layers := {}        # name -> {cell, radius, cells: {}}
var colliders: Array = []

var density := 1.0

## Live from the settings menu. A density change regrows the scrub and grass.
func set_ranges(tree_r: float, grass_r: float, dens: float) -> void:
	TREE_R = tree_r
	GRASS_R = grass_r
	UNDER_R = max(grass_r * 1.8, 80.0)
	if layers.is_empty():
		return
	layers.tree.r = TREE_R
	layers.small.r = UNDER_R
	layers.grass.r = GRASS_R
	SCAN_R = clamp(grass_r * 0.4, 10.0, 30.0)
	if layers.has("scan"): layers.scan.r = SCAN_R
	if abs(dens - density) > 0.01:
		density = dens
		for n in ["small", "grass", "scan"]:
			for k in layers[n].cells:
				if layers[n].cells[k]: layers[n].cells[k].queue_free()
			layers[n].cells.clear()

func setup(t: Terrain3D) -> void:
	terrain = t
	mask = load("res://assets/vegmask.png")
	mask2 = load("res://assets/vegmask2.png")
	if ResourceLoader.exists("res://assets/roadmask.png"):
		roadmask = load("res://assets/roadmask.png")
	for k in DEF:
		meshes[k] = load("res://assets/veg/%s.res" % k)
		for g in DEF[k]:
			if not groups.has(g):
				groups[g] = []
			groups[g].append([k, DEF[k][g]])
	grass_mesh = _make_grass()
	_load_scans()
	layers = {
		"tree": {"cell": 256.0, "r": TREE_R, "cells": {}},
		"small": {"cell": 64.0, "r": UNDER_R, "cells": {}},
		"grass": {"cell": 32.0, "r": GRASS_R, "cells": {}},
	}
	if scan_meshes.size():
		layers["scan"] = {"cell": 12.0, "r": SCAN_R, "cells": {}}

## Pull every clump out of the Poly Haven grass sets (they come as a scene of variants), bake each one's transform
## into its own mesh, and give it the wind / translucency shader with its own photo textures.
func _load_scans() -> void:
	# grass sets are a scene of separate clumps; the weeds are one plant made of pieces (merge them)
	var sets := {"grass_medium_02": [1.0, false], "grass_medium_01": [1.0, false], "weed_plant_02": [0.08, true], "dandelion_01": [0.06, true]}
	for id in sets:
		var path := "res://assets/ph/grass/%s/%s.gltf" % [id, id]
		if not ResourceLoader.exists(path):
			continue
		var root: Node3D = load(path).instantiate()
		var mis := root.find_children("*", "MeshInstance3D", true, false)
		var groups: Array = [mis] if sets[id][1] else mis.map(func(m): return [m])
		for grp in groups:
			var faces := 0
			for m in grp: faces += (m as MeshInstance3D).mesh.get_faces().size() / 3
			if faces > (4000 if sets[id][1] else 1600) or faces < 100:
				continue          # too heavy to scatter by the thousand, or a stray scrap
			var surfs: Array = []
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := -lo
			for mi in grp:
				var m := mi as MeshInstance3D
				var xf := Transform3D()
				var p: Node = m
				while p != root and p != null:
					xf = (p as Node3D).transform * xf
					p = p.get_parent()
				var st := SurfaceTool.new()
				for si in m.mesh.get_surface_count():
					st.clear()
					st.create_from(m.mesh, si)
					var arr := st.commit_to_arrays()
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
					for i in v.size():
						v[i] = xf * v[i]
						lo = lo.min(v[i])
						hi = hi.max(v[i])
						if nrm.size(): nrm[i] = (xf.basis * nrm[i]).normalized()
					arr[Mesh.ARRAY_VERTEX] = v
					if nrm.size(): arr[Mesh.ARRAY_NORMAL] = nrm
					surfs.append([arr, m.get_active_material(si)])
			# sit it on the ground at its footprint centre
			var c := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
			var out := ArrayMesh.new()
			for sf in surfs:
				var arr: Array = sf[0]
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				for i in v.size(): v[i] -= c
				arr[Mesh.ARRAY_VERTEX] = v
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				var src := sf[1] as BaseMaterial3D
				var sm := ShaderMaterial.new()
				sm.shader = load("res://shaders/grass_scan.gdshader")
				if src:
					sm.set_shader_parameter("albedo_tex", src.albedo_texture)
					sm.set_shader_parameter("normal_tex", src.normal_texture)
					sm.set_shader_parameter("rough_tex", src.roughness_texture)
				sm.set_shader_parameter("height", max(hi.y - lo.y, 0.05))
				out.surface_set_material(out.get_surface_count() - 1, sm)
			scan_meshes.append({"mesh": out, "w": float(sets[id][0]) / (1.0 if sets[id][1] else 1.0), "h": hi.y - lo.y, "weed": sets[id][1]})
		root.free()

func sample(x: float, z: float) -> Color:
	var px := clampi(int((x - X0) / MPX), 0, mask.get_width() - 1)
	var pz := clampi(int((z - Z0) / MPX), 0, mask.get_height() - 1)
	return mask.get_pixel(px, pz)

func sample2(x: float, z: float) -> Color:
	var px := clampi(int((x - X0) / MPX), 0, mask2.get_width() - 1)
	var pz := clampi(int((z - Z0) / MPX), 0, mask2.get_height() - 1)
	return mask2.get_pixel(px, pz)

## metres from the nearest road's outer edge (negative = on the road); 15 when there's no road about
func road_clearance(x: float, z: float) -> float:
	if roadmask == null:
		return 15.0
	var fx := (x - X0) / 5.0
	var fz := (z - Z0) / 5.0
	var ix := clampi(int(fx), 0, roadmask.get_width() - 2)
	var iz := clampi(int(fz), 0, roadmask.get_height() - 2)
	var tx := clampf(fx - ix, 0, 1)
	var tz := clampf(fz - iz, 0, 1)
	var a := lerpf(roadmask.get_pixel(ix, iz).r, roadmask.get_pixel(ix + 1, iz).r, tx)
	var b := lerpf(roadmask.get_pixel(ix, iz + 1).r, roadmask.get_pixel(ix + 1, iz + 1).r, tx)
	return lerpf(a, b, tz) * 25.5 - 10.0

func _pick(rng: RandomNumberGenerator, g: String) -> String:
	var L: Array = groups.get(g, [])
	if L.is_empty():
		return ""
	var tot := 0.0
	for e in L: tot += e[1]
	var r := rng.randf() * tot
	for e in L:
		r -= e[1]
		if r <= 0: return e[0]
	return L[0][0]

func update(cam_pos: Vector3, budget := 3) -> void:
	for name in layers:
		var L: Dictionary = layers[name]
		var cs: float = L.cell
		var r: float = L.r
		var cx := floori(cam_pos.x / cs)
		var cz := floori(cam_pos.z / cs)
		var n := ceili(r / cs) + 1
		var want := []
		for i in range(-n, n + 1):
			for j in range(-n, n + 1):
				var ox := (cx + i) * cs + cs * 0.5
				var oz := (cz + j) * cs + cs * 0.5
				var d := Vector2(ox - cam_pos.x, oz - cam_pos.z).length() - cs * 0.71
				if d < r:
					var key := Vector2i(cx + i, cz + j)
					if not L.cells.has(key):
						want.append([d, key])
		want.sort_custom(func(a, b): return a[0] < b[0])
		for w in want.slice(0, budget):
			L.cells[w[1]] = _build(name, w[1], cs)
		for key in L.cells.keys():
			var ox: float = key.x * cs + cs * 0.5
			var oz: float = key.y * cs + cs * 0.5
			if Vector2(ox - cam_pos.x, oz - cam_pos.z).length() - cs * 0.71 > r + cs:
				var node: Node3D = L.cells[key]
				if node: node.queue_free()
				L.cells.erase(key)

func _height(x: float, z: float) -> float:
	var h := terrain.data.get_height(Vector3(x, 0, z))
	return h

func _build(layer: String, key: Vector2i, cs: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(key.x, key.y, layer.hash()))
	var x0 := key.x * cs
	var z0 := key.y * cs
	var per := {}     # key -> Array[Transform3D]
	var step: float = {"tree": 8.0, "small": 2.6, "grass": 0.9, "scan": 0.6}[layer]
	var nn := int(cs / step)
	for i in nn:
		for j in nn:
			var x: float = x0 + (i + rng.randf()) * step
			var z: float = z0 + (j + rng.randf()) * step
			var m := sample(x, z)          # r canopy, g sand, b town, a wet
			var m2 := sample2(x, z)        # r short grass, g cane, b water
			if m2.b > 0.45 or m.b > 0.55:
				continue
			var kind := ""
			var sc := 1.0
			match layer:
				"tree":
					var p := m.r * 0.9 + m.g * 0.22 + m.b * 0.1 + m.a * 0.25 + 0.025
					if m2.g > 0.4: p *= 0.05      # cane paddocks stay open
					if rng.randf() > p: continue
					var gw := {"forest": m.r, "beach": m.g * 1.5, "town": m.b * 0.8, "wet": m.a * 0.7, "open": 0.12 * (1.0 - m.r)}
					var tot := 0.0
					for g in gw: tot += gw[g]
					var r := rng.randf() * tot
					var grp := "open"
					for g in gw:
						r -= gw[g]
						if r <= 0: grp = g; break
					kind = _pick(rng, grp)
					sc = rng.randf_range(0.75, 1.25)
				"small":
					var pu := m.r * 0.55
					var pe := (1.0 - m.r) * 0.06 * (1.0 - m.b) + m.a * 0.15
					var rr := rng.randf()
					rr /= max(density, 0.1)
					if rr < pu: kind = _pick(rng, "under")
					elif rr < pu + pe: kind = _pick(rng, "edge")
					else: continue
					sc = rng.randf_range(0.7, 1.3)
				"grass":
					var pg := (1.0 - m.r * 0.6) * (1.0 - m.g) * (1.0 - m.b) * 0.85
					if rng.randf() > pg * density: continue
					kind = "_grass"
					sc = rng.randf_range(0.7, 1.3) * (1.0 + m2.g * 1.2 + (1.0 - m2.r) * 0.4)   # long and rank where nobody mows
				"scan":
					var pg := (1.0 - m.r * 0.5) * (1.0 - m.g) * (1.0 - m.b * 0.8) * 0.9
					if rng.randf() > pg * density: continue
					var tot := 0.0
					for e in scan_meshes: tot += e.w
					var r := rng.randf() * tot
					var pick := 0
					for si in scan_meshes.size():
						r -= scan_meshes[si].w
						if r <= 0.0:
							pick = si
							break
					kind = "_scan%d" % pick
					# scale each clump to a real height: 25-70 cm, longer in the rank paddocks
					if scan_meshes[pick].weed:
						sc = rng.randf_range(0.8, 1.3)
					else:
						var want := rng.randf_range(0.25, 0.5) * (1.0 + m2.g * 0.8 + (1.0 - m2.r) * 0.4)
						sc = want / max(float(scan_meshes[pick].h), 0.05)
			if kind == "":
				continue
			var clear := road_clearance(x, z)
			if clear < {"tree": 3.5, "small": 1.2, "grass": 0.2, "scan": 0.3}[layer]:
				continue
			var h := _height(x, z)
			if is_nan(h):
				continue
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
			if layer == "grass" or layer == "scan":
				basis = basis.rotated(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf() * 0.15)
			if not per.has(kind): per[kind] = []
			per[kind].append(Transform3D(basis, Vector3(x, h - 0.05, z)))
	var node := Node3D.new()
	for kind in per:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if kind.begins_with("_scan"):
			mm.mesh = scan_meshes[int(kind.substr(5))].mesh
		else:
			mm.mesh = grass_mesh if kind == "_grass" else meshes[kind]
		var xs: Array = per[kind]
		mm.instance_count = xs.size()
		for k in xs.size():
			mm.set_instance_transform(k, xs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = layers[layer].r + 40.0
		mmi.visibility_range_end_margin = 30.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if layer == "grass":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if layer == "scan":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = layers[layer].r + 6.0
			mmi.visibility_range_end_margin = 6.0
		node.add_child(mmi)
	# trunks you can't drive through: simple cylinders for the trees near the ground the player is on
	if layer == "tree":
		var body := StaticBody3D.new()
		for kind in per:
			for xf: Transform3D in per[kind]:
				var cs2 := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.3 * xf.basis.get_scale().x
				cyl.height = 4.0
				cs2.shape = cyl
				cs2.position = xf.origin + Vector3(0, 2, 0)
				body.add_child(cs2)
		node.add_child(body)
	add_child(node)
	return node

func _make_grass() -> ArrayMesh:
	# one clump: 14 curved blades, darker at the root
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for b in 14:
		var a := rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf() * 0.28
		var lean := Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5) * 0.5
		var h := rng.randf_range(0.35, 0.8)
		var w := rng.randf_range(0.025, 0.045)
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var segs := 4
		var prev_l := off - side
		var prev_r := off + side
		for s in range(1, segs + 1):
			var t := float(s) / segs
			var c := off + Vector3(0, h * t, 0) + lean * t * t
			var ww := 1.0 - t * 0.95
			var l := c - side * ww
			var r := c + side * ww
			var c0 := Color(0.16, 0.24, 0.07).lerp(Color(0.42, 0.55, 0.18), t - 1.0 / segs)
			var c1 := Color(0.16, 0.24, 0.07).lerp(Color(0.42, 0.55, 0.18), t)
			for v in [[prev_l, c0, t - 1.0 / segs], [prev_r, c0, t - 1.0 / segs], [r, c1, t], [prev_l, c0, t - 1.0 / segs], [r, c1, t], [l, c1, t]]:
				st.set_color(v[1])
				st.set_uv(Vector2(0, v[2]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
			prev_l = l
			prev_r = r
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grass.gdshader")
	st.set_material(m)
	return st.commit()

## After a terrain edit: drop the cells over that ground so they regrow on the new heights
func refresh_area(c: Vector3, r: float) -> void:
	for name in layers:
		var L: Dictionary = layers[name]
		var cs: float = L.cell
		for key in L.cells.keys():
			var ox: float = key.x * cs + cs * 0.5
			var oz: float = key.y * cs + cs * 0.5
			if Vector2(ox - c.x, oz - c.z).length() < r + cs * 0.71:
				if L.cells[key]: L.cells[key].queue_free()
				L.cells.erase(key)
