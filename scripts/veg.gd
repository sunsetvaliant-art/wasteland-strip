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
var SCAN_R := 10.0             # real grass_medium_01 clumps out to here, cards of them beyond

# key, groups it grows in (weight) — from VEG_DEF
const DEF := {
	# the subtropics: rainforest with palms and figs through it, bananas and bamboo wherever it's wet or someone once
	# lived, gums and jacarandas in the open, coconuts on the sand
	"jungle": {"forest": 1.0, "wet": 0.3}, "island1": {"forest": 0.9, "open": 0.35, "wet": 0.2},
	"rubberfig": {"forest": 0.6, "wet": 0.6, "town": 0.4, "open": 0.2}, "ghostgum": {"forest": 0.5, "open": 1.0, "town": 0.2}, "tree2": {"open": 0.8, "town": 0.5, "forest": 0.4},
	"coconut": {"beach": 1.0, "town": 0.5, "wet": 0.15}, "palms": {"beach": 0.8, "wet": 0.5, "town": 0.5, "forest": 0.35, "open": 0.12}, "palm4": {"town": 0.7, "beach": 0.4, "wet": 0.4, "forest": 0.3, "open": 0.1},
	"banana": {"wet": 0.8, "town": 0.6, "forest": 0.2, "open": 0.15}, "bamboo": {"wet": 1.0, "forest": 0.2, "open": 0.08, "town": 0.15}, "jacaranda": {"town": 0.8, "open": 0.45},
	"fern": {"under": 1.0, "edge": 0.15}, "fern2": {"under": 1.0, "edge": 0.35}, "monstera": {"under": 0.7, "edge": 0.1}, "elephant": {"under": 0.7, "wet": 0.2, "edge": 0.2},
	# Poly Haven plants added 2026-11-13 (tools/bake_veg.gd PH): more kinds under the trees and along the edges
	"pachira": {"wet": 0.4, "town": 0.4, "forest": 0.12}, "calathea": {"under": 0.7}, "fern3": {"under": 0.9, "edge": 0.3}, "anthurium": {"under": 0.2},
	"shrub2": {"edge": 0.6, "under": 0.2}, "shrub3": {"edge": 0.7, "under": 0.15}, "nettle": {"edge": 0.35}, "periwinkle": {"edge": 0.25},
	"stump": {"under": 0.12, "edge": 0.08}, "mossrock": {"under": 0.15},
	"bush1": {"edge": 1.0, "under": 0.5}, "shrub1": {"edge": 0.8, "under": 0.25}, "shrub4": {"edge": 0.8, "under": 0.25}, "weed": {"edge": 0.7},
}
const TREES := ["jungle", "island1", "rubberfig", "ghostgum", "tree2", "coconut", "palms", "palm4", "banana", "bamboo", "jacaranda"]
const SMALL := ["fern", "fern2", "monstera", "elephant", "bush1", "shrub1", "shrub4", "weed"]

var terrain: Terrain3D
var mask: Image
var mask2: Image
var roadmask: Image       # 5 m clearance from the nearest road edge: (m + 10) x 10
var meshes := {}
var groups := {}        # group -> [[key, weight], ...]
var scan_meshes: Array = []     # photogrammetry grass and weed clumps, one mesh per variant
var near_mats: Array = []
var card_mesh: ArrayMesh        # beyond the real clumps: crossed cards showing pictures of them
var card_mat: ShaderMaterial
var cards_ready := false
var layers := {}        # name -> {cell, radius, cells: {}}
var colliders: Array = []

var density := 1.0
var cam_last := Vector3.ZERO

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
	SCAN_R = clamp(grass_r * 0.22, 7.0, 14.0)
	if layers.has("scan"): layers.scan.r = SCAN_R
	_apply_hand_over()
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
	_load_scans()
	layers = {
		"tree": {"cell": 256.0, "r": TREE_R, "cells": {}},
		"small": {"cell": 64.0, "r": UNDER_R, "cells": {}},
		"grass": {"cell": 16.0, "r": GRASS_R + 8.0, "cells": {}},
		"cane": {"cell": 32.0, "r": 210.0, "cells": {}},
	}
	_make_cane()
	if scan_meshes.size():
		layers["scan"] = {"cell": 8.0, "r": SCAN_R, "cells": {}}
		_make_cards()
	_apply_hand_over()

## Pull every clump out of the Poly Haven grass sets (they come as a scene of variants), bake each one's transform
## into its own mesh, and give it the wind / translucency shader with its own photo textures.
func _load_scans() -> void:
	# grass sets are a scene of separate clumps; the weeds are one plant made of pieces (merge them)
	var sets := {"grass_medium_01": [1.0, false], "weed_plant_02": [0.05, true], "dandelion_01": [0.04, true]}
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
			var nf := 0
			for sf in surfs: nf += (sf[0][Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if sf[0][Mesh.ARRAY_INDEX] != null else (sf[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			scan_meshes.append({"mesh": out, "w": float(sets[id][0]), "h": hi.y - lo.y, "weed": sets[id][1], "faces": nf})
			for si in out.get_surface_count(): near_mats.append(out.surface_get_material(si))
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
	cam_last = cam_pos
	for name in layers:
		if name == "grass" and not cards_ready: continue
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
	var step: float = {"tree": 8.0, "small": 2.6, "grass": 0.42, "scan": 0.34, "cane": 1.55}[layer]
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
				"cane":
					# the cane paddocks: stools in rows a pace and a half apart, standing three metres
					if m2.g < 0.4: continue
					x = x0 + (i + 0.5) * step + rng.randf_range(-0.12, 0.12)
					kind = "_cane"
					sc = rng.randf_range(0.82, 1.2)
				"tree":
					var p := m.r * 0.95 + m.g * 0.26 + m.b * 0.14 + m.a * 0.42 + 0.05
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
					sc = rng.randf_range(0.65, 1.4)
					if rng.randf() < 0.06 and grp in ["forest", "open"]: sc = rng.randf_range(1.6, 2.1)      # the odd giant standing over the rest
				"small":
					var pu := m.r * 0.7
					var pe := (1.0 - m.r) * 0.11 * (1.0 - m.b * 0.6) + m.a * 0.28
					var rr := rng.randf()
					rr /= max(density, 0.1)
					if rr < pu: kind = _pick(rng, "under")
					elif rr < pu + pe: kind = _pick(rng, "edge")
					else: continue
					sc = rng.randf_range(0.6, 1.7)
				"grass":
					# cards: pictures of the grass_medium_01 clumps, dense and cheap
					var pg := (1.0 - m.r * 0.6) * (1.0 - m.g) * (1.0 - m.b) * 0.9
					if rng.randf() > pg * density: continue
					kind = "_card"
					sc = rng.randf_range(0.7, 1.25) * (1.0 + m2.g * 0.7 + (1.0 - m2.r) * 0.35)
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
			if clear < 6.0 and Roads.inst:
				clear = Roads.inst.edge_dist(x, z)        # near a road: the exact distance from its seal
			if clear < {"tree": 3.5, "small": 1.2, "grass": 0.2, "scan": 0.3, "cane": 2.5}[layer]:
				continue
			if Buildings.blocked(x, z, {"tree": 3.0, "small": 0.8, "grass": 0.0, "scan": 0.0, "cane": 1.5}[layer]):
				continue
			var h := _height(x, z)
			if is_nan(h):
				continue
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
			if layer == "grass" or layer == "scan":
				basis = basis.rotated(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf() * 0.15)
			if not per.has(kind): per[kind] = []
			var sink := 0.05
			if layer == "grass": sink = 0.07 + 0.11 * sc        # cards: wide flat quads, so on any slope the low side shows
			elif layer == "scan": sink = 0.04 + 0.03 * sc
			per[kind].append(Transform3D(basis, Vector3(x, h - sink, z)))
			# bananas, bamboo and palms come in clumps; ferns in drifts
			var extra := 0
			if layer == "tree" and kind in ["banana", "bamboo", "palms", "palm4"]: extra = rng.randi_range(1, 3)
			elif layer == "small" and kind in ["fern", "fern2", "elephant"]: extra = rng.randi_range(0, 2)
			for _c in extra:
				var ca := rng.randf() * TAU
				var cr := rng.randf_range(1.6, 4.2) if layer == "tree" else rng.randf_range(0.5, 1.4)
				var cx := x + cos(ca) * cr
				var cz := z + sin(ca) * cr
				if road_clearance(cx, cz) < (4.5 if layer == "tree" else 1.5) or Buildings.blocked(cx, cz, 3.0 if layer == "tree" else 0.8): continue
				var ch := _height(cx, cz)
				if is_nan(ch): continue
				per[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc * rng.randf_range(0.7, 1.15)), Vector3(cx, ch - 0.05, cz)))
	var node := Node3D.new()
	for kind in per:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if kind.begins_with("_scan"):
			mm.mesh = scan_meshes[int(kind.substr(5))].mesh
		else:
			mm.mesh = card_mesh if kind == "_card" else (cane_mesh if kind == "_cane" else meshes[kind])
		var xs: Array = per[kind]
		mm.instance_count = xs.size()
		for k in xs.size():
			mm.set_instance_transform(k, xs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = layers[layer].r + 40.0
		mmi.visibility_range_end_margin = 30.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if layer == "cane": mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if layer == "grass" or layer == "scan":
			# no cell-by-cell cut-off (that made rings): the shaders thin the grass out clump by clump
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 0.0
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

func _apply_hand_over() -> void:
	if OS.get_environment("GRASS_NOHIDE") != "": return
	for m in near_mats: (m as ShaderMaterial).set_shader_parameter("far_hide", SCAN_R)
	if card_mat:
		card_mat.set_shader_parameter("near_hide", SCAN_R if layers.has("scan") else 0.0)
		card_mat.set_shader_parameter("far_hide", GRASS_R)

## Photograph four of the fuller grass_medium_01 clumps side by side (flat ambient light, so the scene lights the
## cards later), then make the crossed-card mesh that shows them. Takes a couple of frames; the card layer waits.
## Sugar cane: a painted stool of it (jointed stalks, long arching leaves) on two crossed cards three metres tall
var cane_mesh: ArrayMesh
func _make_cane() -> void:
	var S := 512
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.45, 0.15, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var line := func(a: Vector2, b: Vector2, wd: float, col: Color) -> void:
		var n := int(a.distance_to(b)) + 1
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			var hw := int(ceil(wd * S / 256.0 / 2.0))
			for dx in range(-hw, hw + 1):
				var px := int(p.x) + dx
				var py := int(p.y)
				if px >= 0 and px < S and py >= 0 and py < S:
					img.set_pixel(px, py, col.darkened(absf(dx) / maxf(hw, 1.0) * 0.25))
	# leaves first (behind), then the stalks
	var stalks := []
	for k in 11:
		stalks.append([rng.randf_range(0.14, 0.86) * S, rng.randf_range(0.5, 0.72), rng.randf_range(-0.07, 0.07)])
	for st in stalks:
		var top := Vector2(st[0] + st[2] * S, S * (1.0 - st[1]))
		for l in rng.randi_range(7, 10):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var from := Vector2(lerpf(st[0], top.x, rng.randf_range(0.6, 1.0)), lerpf(S * 0.98, top.y, rng.randf_range(0.6, 1.0)))
			var reach := rng.randf_range(0.14, 0.36) * S
			var rise := rng.randf_range(0.1, 0.34) * S
			var col := Color(0.2, 0.42, 0.1).lerp(Color(0.48, 0.62, 0.2), rng.randf())
			if rng.randf() < 0.18: col = Color(0.62, 0.55, 0.28)          # a dead one
			var prev := from
			for sgm in 9:
				var t := (sgm + 1) / 9.0
				# up and out, then drooping over
				var p := from + Vector2(side * reach * t, -rise * sin(t * PI * 0.72) / sin(PI * 0.72) * (1.0 - 0.5 * t * t))
				line.call(prev, p, lerpf(5.0, 1.0, t), col)
				prev = p
	for st in stalks:
		var base := Vector2(st[0], S - 1)
		var top := Vector2(st[0] + st[2] * S, S * (1.0 - st[1]))
		var col := Color(0.62, 0.68, 0.3).lerp(Color(0.5, 0.4, 0.5), rng.randf() * 0.4)
		line.call(base, top, 5.0, col)
		var nodes := 9
		for j in nodes:
			var p := base.lerp(top, (j + 0.5) / nodes)
			line.call(p + Vector2(-6, 0), p + Vector2(6, 0), 1.0, col.darkened(0.35))
	img.fix_alpha_edges()
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	m.backlight_enabled = true
	m.backlight = Color(0.25, 0.35, 0.1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.3, 0.3 + PI * 0.5]:
		var d := Vector3(cos(a), 0, sin(a)) * 1.25
		var q := [[-d, Vector2(0, 1)], [d, Vector2(1, 1)], [d + Vector3(0, 3.1, 0), Vector2(1, 0)], [-d + Vector3(0, 3.1, 0), Vector2(0, 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st2.set_normal(Vector3(0, 1, 0))
			st2.set_uv(q[idx][1])
			st2.add_vertex(q[idx][0])
	st2.set_material(m)
	cane_mesh = st2.commit()

func _make_cards() -> void:
	var picks: Array = []
	for i in scan_meshes.size():
		if not scan_meshes[i].weed and scan_meshes[i].faces >= 600: picks.append(i)
	if picks.is_empty():
		return
	while picks.size() < 4: picks.append(picks[picks.size() % picks.size()])
	picks = picks.slice(0, 4)
	var sv := SubViewport.new()
	sv.size = Vector2i(1024, 256)
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	sv.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 1.0
	cam.position = Vector3(2.0, 0.5, 5.0)
	sv.add_child(cam)
	cam.current = true
	for f in 4:
		var sm: Dictionary = scan_meshes[picks[f]]
		var mesh: ArrayMesh = sm.mesh.duplicate()
		for si in mesh.get_surface_count():
			var mt: ShaderMaterial = mesh.surface_get_material(si).duplicate()
			mt.set_shader_parameter("wind", 0.0)
			mt.set_shader_parameter("dry", Color(1, 1, 1))
			mesh.surface_set_material(si, mt)
		var aabb := mesh.get_aabb()
		var fit: float = 0.94 / max(aabb.size.y, max(aabb.size.x, aabb.size.z) * 0.6)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.scale = Vector3.ONE * fit
		mi.position = Vector3(0.5 + f, -aabb.position.y * fit + 0.02, 0)
		sv.add_child(mi)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
	img.generate_mipmaps()
	card_mat = ShaderMaterial.new()
	card_mat.shader = load("res://shaders/grass_card.gdshader")
	card_mat.set_shader_parameter("atlas", ImageTexture.create_from_image(img))
	# two crossed quads, 0.6 m tall, frame chosen per clump in the shader
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.0, PI * 0.5, PI * 0.25 + PI * 0.5]:
		var d := Vector3(cos(a), 0, sin(a)) * 0.3
		var n := Vector3(-d.z, 0, d.x).normalized()
		var q := [[-d, Vector2(0, 1)], [d, Vector2(1, 1)], [d + Vector3(0, 0.6, 0), Vector2(1, 0)], [-d + Vector3(0, 0.6, 0), Vector2(0, 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(q[idx][1])
			st.add_vertex(q[idx][0])
	st.set_material(card_mat)
	card_mesh = st.commit()
	_apply_hand_over()
	cards_ready = true

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
