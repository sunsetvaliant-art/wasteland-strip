class_name BuildGen
extends RefCounted
## Buildings made from a floor plan. A plan is a footprint cut into rooms (rectangles that tile it, one set per
## storey); from the rooms come the walls (each room lines its own sides with a thin skin of its own finish, the
## outside gets cladding), the doors between rooms (every room is joined up to the hall or the living rooms), the
## windows on outside walls, floors, ceilings, a roof, stumps or a slab under it, steps up to the doors and stairs
## between storeys. BuildProps then furnishes each room for what it is.
##
## Local frame: x across, z front-to-back with the FRONT at +z (the side that faces the road), y up, y = 0 the top of
## the ground floor. All walls are axis-aligned in this frame; the building node turns it to face its road.

const T_IN := 0.05           # inside wall skin (two of them make an internal wall)
const T_OUT := 0.1           # cladding outside the frame
const DOOR_W := 0.86
const DOOR_H := 2.05
const RISE := 0.18           # stair rise and going
const GOING := 0.27
const KINDS := ["qlder", "cottage", "brick", "two_storey", "shed", "machine_shed", "dairy", "workshop", "warehouse", "shop", "mall", "tower", "pub", "school", "church", "hospital", "police", "fire", "post", "motel", "club"]

# ------------------------------------------------------------------------------------------------ materials
# key: [texture id, metres the texture covers, roughness scale]
const TEX := {
	"weatherboard": ["painted_boards", 2.2], "peeling": ["wood_peeling_paint_weathered", 2.0], "fibro": ["painted_fibro", 2.4],
	"brick": ["red_brick_03", 2.2], "plaster": ["painted_plaster_wall", 2.6], "plaster_worn": ["worn_plaster_wall", 2.6],
	"timber_floor": ["wood_floor_worn", 2.2], "lino": ["old_linoleum_flooring_01", 2.0], "tile": ["worn_tile_floor", 1.4],
	"carpet": ["dirty_carpet", 2.0], "concrete": ["garage_floor", 3.0], "concrete_worn": ["concrete_floor_worn_001", 3.0],
	"deck": ["wood_floor_deck", 2.0], "tin": ["corrugated_iron", 1.6], "tin_rust": ["corrugated_iron", 1.6],
	"roof_tile": ["roof_tiles_14", 2.4], "factory": ["factory_wall", 3.0], "timber": ["weathered_brown_planks", 1.6],
	"ceiling": ["painted_ceiling", 6.0],
}
const TINTS := {
	"cream": Color(1.0, 0.95, 0.82), "white": Color(1, 1, 1), "green": Color(0.78, 0.9, 0.78), "blue": Color(0.78, 0.86, 0.95),
	"yellow": Color(1.0, 0.93, 0.7), "pink": Color(1.0, 0.86, 0.82), "grey": Color(0.82, 0.82, 0.82), "teal": Color(0.72, 0.88, 0.86),
	"tan": Color(0.9, 0.82, 0.68), "dark": Color(0.6, 0.6, 0.6),
	# main-street paint
	"sage": Color(0.74, 0.82, 0.68), "terracotta": Color(0.86, 0.58, 0.46), "mustard": Color(0.93, 0.8, 0.46), "pale_blue": Color(0.74, 0.84, 0.92),
	"heritage": Color(0.42, 0.56, 0.44), "maroon": Color(0.56, 0.26, 0.24), "navy": Color(0.3, 0.37, 0.52), "charcoal": Color(0.34, 0.34, 0.36),
	"sandstone": Color(0.95, 0.83, 0.6), "monument": Color(0.42, 0.42, 0.44), "surfmist": Color(0.95, 0.94, 0.9), "woodland": Color(0.55, 0.57, 0.52),
	"basalt": Color(0.5, 0.5, 0.52), "brick_tan": Color(1.15, 1.05, 0.85), "brick_dark": Color(0.62, 0.55, 0.52),
	"sand": Color(0.92, 0.84, 0.7), "black": Color(0.22, 0.23, 0.25), "red": Color(0.86, 0.2, 0.18),
}
static var _mats := {}

static var _lod_mats := {}
const LOD_FADE := Vector2(98.0, 112.0)     # far-off versions vanish (dithered) nearer than this: the real one's there

## The same finish for the merged far-off buildings, dithered out near the camera
static func mat_lod(key: String) -> Material:
	if _lod_mats.has(key):
		return _lod_mats[key]
	var m: StandardMaterial3D = (mat(key) as StandardMaterial3D).duplicate()
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = LOD_FADE.x
	m.distance_fade_max_distance = LOD_FADE.y
	_lod_mats[key] = m
	return m

## "tex" or "tex:tint" or one of the plain finishes
static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var parts := key.split(":")
	var base := parts[0]
	var tint: Color = TINTS.get(parts[1], Color.WHITE) if parts.size() > 1 else Color.WHITE
	match base:
		"glass_lead", "glass_lead2":
			# highlight windows: patterned glass, a little colour in it
			m.albedo_color = Color(0.32, 0.4, 0.36) if base == "glass_lead" else Color(0.45, 0.36, 0.26)
			m.roughness = 0.35
			m.metallic = 0.3
			m.emission_enabled = true
			m.emission = m.albedo_color * 0.15
		"glass_dark":
			m.albedo_color = Color(0.12, 0.14, 0.15)
			m.roughness = 0.15
			m.metallic = 0.5
		"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.55, 0.62, 0.6, 0.28)
			m.roughness = 0.08
			m.metallic = 0.4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"lamp":
			# a fluoro tube or panel light: unshaded so it reads as lit with no real light cost
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.98, 0.92) * tint
		"trim":
			m.albedo_color = Color(0.86, 0.85, 0.8) * tint
			m.roughness = 0.75
		"enamel":
			m.albedo_color = Color(0.9, 0.9, 0.87) * tint
			m.roughness = 0.3
		"terrazzo":
			# polished mall floor: cream, glossy, catches the skylight
			m.albedo_color = Color(0.86, 0.83, 0.76) * tint
			m.roughness = 0.3
			m.metallic_specular = 0.45
		"rubber":
			m.albedo_color = Color(0.07, 0.07, 0.075)
			m.roughness = 0.85
		"grille":
			# a shop's roller grille: you can see through it
			var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			for i in 16:
				for j in 2:
					img.set_pixel(i, j, Color(0.75, 0.76, 0.78, 1))
					img.set_pixel(j, i, Color(0.75, 0.76, 0.78, 1))
			m.albedo_texture = ImageTexture.create_from_image(img)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(8, 8, 8)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.metallic = 0.6
			m.roughness = 0.4
		"cloth":
			m.albedo_color = Color(0.8, 0.8, 0.8) * tint
			m.roughness = 1.0
		"steel":
			m.albedo_color = Color(0.62, 0.63, 0.64)
			m.metallic = 0.85
			m.roughness = 0.38
		"dark":
			m.albedo_color = Color(0.08, 0.08, 0.08)
			m.roughness = 0.9
		"mirror":
			m.albedo_color = Color(0.75, 0.78, 0.8)
			m.metallic = 1.0
			m.roughness = 0.05
		"fabric":
			m.albedo_color = Color(0.72, 0.68, 0.6) * tint
			m.roughness = 1.0
		"door":
			m.albedo_color = Color(0.55, 0.4, 0.26) * tint
			m.roughness = 0.7
		"dirt":
			m.albedo_color = Color(0.36, 0.3, 0.22)
			m.roughness = 1.0
		_:
			var t: Array = TEX.get(base, TEX["plaster"])
			var dir := "res://assets/ph/tex/%s/%s" % [t[0], t[0]]
			m.albedo_texture = load(dir + "_diffuse.jpg")
			m.albedo_color = tint
			if ResourceLoader.exists(dir + "_nor_gl.jpg"):
				m.normal_enabled = true
				m.normal_texture = load(dir + "_nor_gl.jpg")
			if ResourceLoader.exists(dir + "_rough.jpg"):
				m.roughness_texture = load(dir + "_rough.jpg")
				m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if base in ["tin", "tin_rust", "roof_tile"] and parts.size() > 2 and parts[2] == "uv":
				m.uv1_scale = Vector3(1.0 / t[1], 1.0 / t[1], 1)          # roofs carry their own UVs (corrugations down the slope)
			else:
				m.uv1_triplanar = true
				m.uv1_triplanar_sharpness = 6.0
				m.uv1_scale = Vector3.ONE / float(t[1])
			if base in ["tin", "tin_rust"]:
				m.metallic = 0.3
				m.albedo_color = tint * (Color(0.82, 0.83, 0.84) if base == "tin" else Color(0.72, 0.52, 0.4))
				m.roughness = 0.75
				if parts.size() > 3 and parts[3] == "in":       # the underside of a roof sheet, seen from inside
					m.metallic = 0.0
					m.roughness = 0.95
					m.normal_enabled = false
					m.albedo_color = tint * Color(0.95, 0.95, 0.95)
	_mats[key] = m
	return m

# ------------------------------------------------------------------------------------------------ geometry sink
class Geo:
	var xf := Transform3D()       # applied to everything added (several buildings into one mesh)
	var sts := {}                 # material key -> SurfaceTool
	var shapes: Array = []        # [Transform3D, Vector3 size] collision boxes
	var tris := PackedVector3Array()   # extra collision triangles (roofs)

	func _st(mk: String) -> SurfaceTool:
		if not sts.has(mk):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts[mk] = s
		return sts[mk]

	func tri(mk: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
		var s := _st(mk)
		if (b - a).cross(c - a).dot(n) > 0.0:       # Godot's front faces wind clockwise
			var t := b; b = c; c = t
			var tu := ub; ub = uc; uc = tu
		var wn := (xf.basis * n).normalized()
		for p in [[a, ua], [b, ub], [c, uc]]:
			s.set_normal(wn)
			s.set_uv(p[1])
			s.add_vertex(xf * (p[0] as Vector3))

	func quad(mk: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua := Vector2(0, 0), ub := Vector2(1, 0), uc := Vector2(1, 1), ud := Vector2(0, 1)) -> void:
		tri(mk, a, b, c, n, ua, ub, uc)
		tri(mk, a, c, d, n, ua, uc, ud)

	## An axis-aligned box from min to max corner
	func aabb(mk: String, lo: Vector3, hi: Vector3, collide := true) -> void:
		var sz := hi - lo
		if sz.x <= 0.002 or sz.y <= 0.002 or sz.z <= 0.002:
			return
		box(mk, Transform3D(Basis(), (lo + hi) * 0.5), sz, collide)

	func box(mk: String, xf: Transform3D, size: Vector3, collide := true) -> void:
		var h := size * 0.5
		var c := []
		for i in 8:
			c.append(xf * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
		var bx := xf.basis.x.normalized()
		var by := xf.basis.y.normalized()
		var bz := xf.basis.z.normalized()
		# faces: corner indices, normal, uv extents
		quad(mk, c[1], c[3], c[7], c[5], bx, Vector2(0, 0), Vector2(0, size.y), Vector2(size.z, size.y), Vector2(size.z, 0))
		quad(mk, c[0], c[4], c[6], c[2], -bx, Vector2(0, 0), Vector2(size.z, 0), Vector2(size.z, size.y), Vector2(0, size.y))
		quad(mk, c[2], c[6], c[7], c[3], by, Vector2(0, 0), Vector2(0, size.z), Vector2(size.x, size.z), Vector2(size.x, 0))
		quad(mk, c[0], c[1], c[5], c[4], -by, Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.z), Vector2(0, size.z))
		quad(mk, c[4], c[5], c[7], c[6], bz, Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y))
		quad(mk, c[0], c[2], c[3], c[1], -bz, Vector2(0, 0), Vector2(0, size.y), Vector2(size.x, size.y), Vector2(size.x, 0))
		if collide:
			shapes.append([xf, size])

	## The mesh. Tangents only where a material needs them (roof sheets with their own UVs; the triplanar ones make
	## their own). set_mats false: leave the materials for the main thread (lod: the far-off, faded-near versions).
	func commit(set_mats := true, lod := false) -> ArrayMesh:
		var am := ArrayMesh.new()
		for mk in sts:
			var s: SurfaceTool = sts[mk]
			if ":uv" in mk:
				s.generate_tangents()
			s.commit(am)
			am.surface_set_name(am.get_surface_count() - 1, mk)
			if set_mats:
				am.surface_set_material(am.get_surface_count() - 1, BuildGen.mat_lod(mk) if lod else BuildGen.mat(mk))
		return am

# ------------------------------------------------------------------------------------------------ plans
## A plan for one building of `kind` on a w x d footprint (metres, before verandahs)
static func plan(kind: String, w: float, d: float, seed: int, sub := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var p := {"kind": kind, "w": w, "d": d, "seed": seed, "floors": [], "verandah": null, "roof": {}, "raised": 0.3,
		"stumps": false, "ext_doors": [], "under": false}
	var tint: String = ["cream", "white", "green", "blue", "yellow", "pink", "teal", "white", "cream"][rng.randi() % 9]
	match kind:
		"qlder":
			p.raised = rng.randf_range(2.3, 2.7)
			p.stumps = true
			p.under = true
			p.h = 3.0
			p.clad = "weatherboard:" + tint
			p.roof = {"type": "hip" if rng.randf() < 0.65 else "gable", "pitch": deg_to_rad(rng.randf_range(24, 32)), "mat": "tin" if rng.randf() < 0.7 else "tin_rust"}
			p.verandah = {"depth": rng.randf_range(2.2, 2.8), "sides": rng.randf() < 0.35}
			p.floors.append({"y": 0.0, "h": 3.0, "rooms": _hall_layout(w, d, 1.2, rng, false, false)})
		"cottage" when sub == "shack":
			# a 1960s timber beach shack: small, on low stumps, painted boards or fibro, a skillion or low gable tin roof,
			# a little front deck
			p.raised = rng.randf_range(0.5, 1.0)
			p.stumps = true
			p.h = 2.5
			var beach: String = ["white", "pale_blue", "teal", "yellow", "sage", "pink"][rng.randi() % 6]
			p.clad = ("weatherboard:" if rng.randf() < 0.6 else "fibro:") + beach
			p.roof = {"type": "skillion" if rng.randf() < 0.4 else "gable", "pitch": deg_to_rad(rng.randf_range(8, 16)), "mat": "tin" if rng.randf() < 0.5 else "tin_rust"}
			p.verandah = {"depth": rng.randf_range(1.6, 2.2), "sides": false}
			p.floors.append({"y": 0.0, "h": 2.5, "rooms": _open_layout(w, d, rng)})
		"two_storey" when sub == "units70":
			# 1970s sandstone-coloured two-storey walk-up units by the beach: flat-ish tile roof, the same up and down
			p.raised = 0.3
			p.h = 2.6
			p.clad = ["plaster:sandstone", "plaster:sandstone", "plaster:sand", "plaster:cream"][rng.randi() % 4]
			p.roof = {"type": "hip", "pitch": deg_to_rad(rng.randf_range(12, 16)), "mat": ["roof_tile:terracotta", "roof_tile", "roof_tile:brick_dark"][rng.randi() % 3]}
			p.fascia = "trim:" + ["white", "maroon", "charcoal"][rng.randi() % 3]
			p.floors.append({"y": 0.0, "h": 2.6, "rooms": _hall_layout(w, d, 2.2, rng, true, false)})
			p.floors.append({"y": 2.9, "h": 2.6, "rooms": _hall_layout(w, d, 2.2, rng, true, true)})
		"brick" when sub.begins_with("estate"):
			# a newer double brick home in an estate: each estate keeps to a palette (the builder's range, the council's
			# approved fascia colours) and the houses vary within it
			var pal := int(sub.get_slice(":", 1)) if sub.contains(":") else 0
			var ranges := [
				[["plaster:white", "brick:brick_tan"], ["roof_tile:charcoal", "roof_tile:basalt"], ["trim:monument", "trim:charcoal"]],
				[["brick:brick_tan", "brick"], ["roof_tile:terracotta", "roof_tile"], ["trim:surfmist", "trim:white"]],
				[["brick:brick_dark", "plaster:grey"], ["tin:charcoal", "tin:monument"], ["trim:woodland", "trim:monument"]],
				[["plaster:grey", "plaster:cream"], ["roof_tile:basalt", "roof_tile:charcoal"], ["trim:surfmist", "trim:charcoal"]]]
			var r: Array = ranges[pal % ranges.size()]
			p.raised = 0.25
			p.h = 2.7
			p.clad = r[0][rng.randi() % 2]
			p.roof = {"type": "hip" if rng.randf() < 0.8 else "gable", "pitch": deg_to_rad(rng.randf_range(20, 24)), "mat": r[1][rng.randi() % 2]}
			p.fascia = r[2][rng.randi() % 2]
			p.floors.append({"y": 0.0, "h": 2.7, "rooms": _open_layout(w, d, rng) if rng.randf() < 0.7 else _hall_layout(w, d, 1.2, rng, false, false)})
		"cottage":
			p.raised = rng.randf_range(0.5, 0.9)
			p.stumps = true
			p.h = 2.6
			p.clad = "fibro:" + tint
			p.roof = {"type": "gable", "pitch": deg_to_rad(rng.randf_range(18, 26)), "mat": "tin" if rng.randf() < 0.6 else "tin_rust"}
			p.floors.append({"y": 0.0, "h": 2.6, "rooms": _open_layout(w, d, rng)})
		"brick":
			p.raised = 0.3
			p.h = 2.6
			p.clad = "brick"
			p.roof = {"type": "hip", "pitch": deg_to_rad(rng.randf_range(20, 25)), "mat": "roof_tile" if rng.randf() < 0.6 else "tin"}
			p.floors.append({"y": 0.0, "h": 2.6, "rooms": _hall_layout(w, d, 1.2, rng, false, false) if rng.randf() < 0.5 else _open_layout(w, d, rng)})
		"tower":
			TowerGen.plan_into(p, w, d, rng, sub)
		"pub", "school", "church", "hospital", "police", "fire", "post", "motel", "club":
			CivicGen.plan_into(p, kind, w, d, rng)
		"two_storey":
			p.raised = 0.3
			p.h = 2.6
			p.clad = "brick" if rng.randf() < 0.5 else "weatherboard:" + tint
			p.roof = {"type": "hip" if rng.randf() < 0.5 else "gable", "pitch": deg_to_rad(rng.randf_range(22, 28)), "mat": "roof_tile" if p.clad == "brick" else "tin"}
			p.floors.append({"y": 0.0, "h": 2.6, "rooms": _hall_layout(w, d, 2.2, rng, true, false)})
			p.floors.append({"y": 2.9, "h": 2.6, "rooms": _hall_layout(w, d, 2.2, rng, true, true)})
		"shed":
			p.raised = 0.12
			p.h = rng.randf_range(3.6, 4.4) if w * d > 30.0 else rng.randf_range(2.3, 2.7)     # a garden shed's just head height
			p.clad = "tin" if rng.randf() < 0.6 else "tin_rust"
			p.roof = {"type": "gable", "ridge": "z", "pitch": deg_to_rad(rng.randf_range(10, 16)), "mat": p.clad}
			var rooms := [{"x0": -w / 2, "z0": -d / 2, "x1": w / 2, "z1": d / 2, "type": "shed"}]
			if rng.randf() < 0.45 and w > 8 and d > 7.5:
				# a lock-up store in a back corner
				var sx := -w / 2 if rng.randf() < 0.5 else w / 2 - 3.2
				rooms = [{"x0": -w / 2, "z0": -d / 2 + 3.2, "x1": w / 2, "z1": d / 2, "type": "shed"},
					{"x0": sx, "z0": -d / 2, "x1": sx + 3.2, "z1": -d / 2 + 3.2, "type": "store"},
					{"x0": (sx + 3.2) if sx < 0 else -w / 2, "z0": -d / 2, "x1": w / 2 if sx < 0 else sx, "z1": -d / 2 + 3.2, "type": "shed"}]
			p.floors.append({"y": 0.0, "h": p.h, "rooms": rooms})
		"machine_shed":
			p.raised = 0.05
			p.h = rng.randf_range(4.0, 4.8)
			p.clad = "tin_rust" if rng.randf() < 0.6 else "tin"
			p.open_front = true
			p.roof = {"type": "skillion", "pitch": deg_to_rad(8), "mat": p.clad}
			p.floors.append({"y": 0.0, "h": p.h, "rooms": [{"x0": -w / 2, "z0": -d / 2, "x1": w / 2, "z1": d / 2, "type": "machinery"}]})
		"dairy":
			p.raised = 0.2
			p.h = 2.9
			p.clad = "fibro:" + ["white", "cream", "grey"][rng.randi() % 3]
			p.roof = {"type": "gable", "pitch": deg_to_rad(15), "mat": "tin_rust" if rng.randf() < 0.5 else "tin"}
			var cut := -w / 2 + w * 0.62
			p.floors.append({"y": 0.0, "h": 2.9, "rooms": [
				{"x0": -w / 2, "z0": -d / 2, "x1": cut, "z1": d / 2, "type": "milking"},
				{"x0": cut, "z0": -d / 2, "x1": w / 2, "z1": d / 2 - 2.6, "type": "vat"},
				{"x0": cut, "z0": d / 2 - 2.6, "x1": w / 2, "z1": d / 2, "type": "office"}]})
		"workshop", "warehouse":
			var big := kind == "warehouse"
			p.raised = 0.15
			p.h = rng.randf_range(7.0, 8.5) if big else rng.randf_range(5.2, 6.4)
			p.clad = "factory" if rng.randf() < 0.6 else "tin"
			p.roof = {"type": "gable", "ridge": "z", "pitch": deg_to_rad(8), "mat": "tin"}
			var od := 4.0
			var rooms := [{"x0": -w / 2, "z0": -d / 2, "x1": w / 2, "z1": d / 2 - od, "type": "warehouse" if big else "workshop"}]
			var widths := [4.0, 3.6, 2.2] if not big else [5.0, 2.4]
			var types := ["office", "lunch", "toilet"] if not big else ["office", "toilet"]
			var x := -w / 2
			for i in types.size():
				if w / 2 - x < 1.6: break          # a narrow one: no room left for the rest
				var x1: float = x + widths[i] if i < types.size() - 1 else min(x + widths[i], w / 2)
				if w / 2 - x1 < 1.2: x1 = w / 2
				rooms.append({"x0": x, "z0": d / 2 - od, "x1": x1, "z1": d / 2, "type": types[i], "h": 2.7})
				x = x1
			if x < w / 2 - 0.5:
				rooms.append({"x0": x, "z0": d / 2 - od, "x1": w / 2, "z1": d / 2, "type": "warehouse" if big else "workshop"})
			p.floors.append({"y": 0.0, "h": p.h, "rooms": rooms})
		"shop":
			ShopGen.plan_into(p, w, d, rng, sub)
		"mall":
			MallGen.plan_into(p, w, d, rng, sub)
	var fi := 0
	for f in p.floors:
		var i := 0
		for r in f.rooms:
			r["id"] = "%d_%d" % [fi, i]
			r["f"] = fi
			if not r.has("h"): r["h"] = f.h
			r["ops"] = {"N": [], "S": [], "W": [], "E": []}
			i += 1
		fi += 1
	if p.kind == "mall":
		MallGen.openings(p, rng)
		return p
	for fl in p.floors.size():
		_connect(p, fl, rng)
	_ext_doors(p, rng)
	_windows(p, rng)
	return p

## Rooms either side of a hall running front to back. With stairs (two storeys), the hall is 2.2 wide: a 1.2 passage
## beside a 1.0 stair (ground) or stairwell (upstairs) in the middle of the run.
static func _hall_layout(w: float, d: float, hw: float, rng: RandomNumberGenerator, stairs: bool, upper: bool) -> Array:
	var off := rng.randf_range(-0.6, 0.6)
	var hx0: float = clampf(off - hw / 2, -w / 2 + 2.6, w / 2 - 2.6 - hw)
	var hx1: float = hx0 + hw
	var rooms: Array = []
	var flip := rng.randf() < 0.5
	var left_seq: Array
	var right_seq: Array
	if upper:
		left_seq = ["bed", "bed"]
		right_seq = ["bed", "bath"] if d < 11 else ["bed", "bath", "bed"]
	elif stairs:
		left_seq = ["lounge", "kitchen"]
		right_seq = ["dining", "laundry"] if d < 11 else ["dining", "bath", "laundry"]
	else:
		left_seq = ["lounge", "kitchen"] if d < 11 else ["lounge", "dining", "kitchen"]
		right_seq = ["bed", "bath"] if d < 8.5 else (["bed", "bath", "bed"] if d < 12 else ["bed", "bed", "bath", "laundry"])
	if flip:
		var t := left_seq; left_seq = right_seq; right_seq = t
	rooms.append_array(_strip(-w / 2, hx0, d, left_seq, rng))
	rooms.append_array(_strip(hx1, w / 2, d, right_seq, rng))
	if stairs:
		var sx0 := hx1 - 1.0
		var half := (ceil(2.9 / RISE) * GOING) / 2.0
		rooms.append({"x0": hx0, "z0": -d / 2, "x1": sx0, "z1": d / 2, "type": "hall", "hub": true})
		rooms.append({"x0": sx0, "z0": -half, "x1": hx1, "z1": half, "type": "void" if upper else "stair"})
		rooms.append({"x0": sx0, "z0": half, "x1": hx1, "z1": d / 2, "type": "hall"})
		rooms.append({"x0": sx0, "z0": -d / 2, "x1": hx1, "z1": -half, "type": "hall"})
	else:
		rooms.append({"x0": hx0, "z0": -d / 2, "x1": hx1, "z1": d / 2, "type": "hall", "hub": true})
	return rooms

## Rooms in a row from front (+z) to back, sized by what they are
static func _strip(x0: float, x1: float, d: float, seq: Array, rng: RandomNumberGenerator) -> Array:
	const WANT := {"lounge": 4.6, "dining": 3.2, "kitchen": 3.8, "bed": 3.4, "bath": 2.3, "laundry": 2.0, "study": 2.8}
	var tot := 0.0
	var ws := []
	for t in seq:
		var v: float = WANT.get(t, 3.0) * rng.randf_range(0.85, 1.15)
		ws.append(v)
		tot += v
	var out := []
	var z := d / 2
	for i in seq.size():
		var len: float = d * ws[i] / tot
		var z0 := -d / 2 if i == seq.size() - 1 else z - len
		out.append({"x0": x0, "z0": z0, "x1": x1, "z1": z, "type": seq[i]})
		z = z0
	return out

## A small house with no hall: living rooms down one side, bedrooms and the bathroom off them down the other
static func _open_layout(w: float, d: float, rng: RandomNumberGenerator) -> Array:
	var cut := -w / 2 + w * rng.randf_range(0.5, 0.6)
	var pub := ["lounge", "kitchen"]
	var priv := ["bed", "bath"] if d < 8.0 else ["bed", "bath", "bed"]
	var rooms: Array
	if rng.randf() < 0.5:
		rooms = _strip(-w / 2, cut, d, pub, rng) + _strip(cut, w / 2, d, priv, rng)
	else:
		rooms = _strip(-w / 2, -w / 2 + (w / 2 - cut), d, priv, rng) + _strip(-w / 2 + (w / 2 - cut), w / 2, d, pub, rng)
	for r in rooms:
		if r.type == "lounge": r["hub"] = true
	return rooms

# ------------------------------------------------------------------------------------------------ joining rooms up
## Which way two rooms meet: through an opening, a door, an archway, over a stair rail, or not at all
static func _rule(a: String, b: String) -> String:
	var s := [a, b]
	s.sort()
	var k := "%s|%s" % s
	if a == "hall" and b == "hall": return "open"
	if "void" in s:
		return "rail" if "hall" in s else "none"
	if "stair" in s:
		return "open" if "hall" in s else "none"
	if k in ["kitchen|lounge", "dining|kitchen", "dining|lounge"]: return "arch"
	if k in ["shed|shed", "workshop|workshop", "warehouse|warehouse"]: return "open"
	return "door"

const PREF := {
	"bath": {"hall": 6, "laundry": 4, "bed": 3, "kitchen": 2},
	"bed": {"hall": 6, "lounge": 4, "dining": 3, "bed": 1},
	"laundry": {"kitchen": 6, "hall": 5, "bath": 3, "dining": 2},
	"kitchen": {"lounge": 6, "dining": 6, "hall": 5},
	"store": {"shed": 6, "shop": 6, "lobby": 5, "hall": 3}, "office": {"workshop": 5, "warehouse": 5, "milking": 4, "lunch": 3},
	"lunch": {"workshop": 6, "office": 4}, "toilet": {"workshop": 5, "warehouse": 5, "lunch": 4, "office": 3, "lobby": 6, "hall": 5, "store": 4, "shop": 2},
	"vat": {"milking": 6}, "milking": {"office": 2},
	"lobby": {"shop": 6, "store": 4}, "hall": {"shop": 5, "hall": 4},
}

static func _pairs(rooms: Array) -> Array:
	var out := []
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var a: Dictionary = rooms[i]
			var b: Dictionary = rooms[j]
			for e in [["S", "N", "z1", "z0", "x"], ["N", "S", "z0", "z1", "x"], ["E", "W", "x1", "x0", "z"], ["W", "E", "x0", "x1", "z"]]:
				if absf(float(a[e[2]]) - float(b[e[3]])) > 0.02:
					continue
				var lo := maxf(a[e[4] + "0"], b[e[4] + "0"])
				var hi := minf(a[e[4] + "1"], b[e[4] + "1"])
				if hi - lo > 0.05:
					out.append({"a": a, "b": b, "sa": e[0], "sb": e[1], "lo": lo, "hi": hi})
	return out

static func _add_op(r: Dictionary, side: String, a: float, b: float, kind: String, y0 := 0.0, y1 := -1.0) -> Dictionary:
	var op := {"a": a, "b": b, "kind": kind, "y0": y0, "y1": (float(r.h) if y1 < 0 else y1)}
	r.ops[side].append(op)
	return op

static func _free_span(r: Dictionary, side: String, a: float, b: float) -> bool:
	for op in r.ops[side]:
		if a < float(op.b) + 0.15 and b > float(op.a) - 0.15:
			return false
	return true

static func _connect(p: Dictionary, fl: int, rng: RandomNumberGenerator) -> void:
	var rooms: Array = p.floors[fl].rooms
	var pairs := _pairs(rooms)
	var comp := {}
	for r in rooms: comp[r.id] = r.id
	var find := func(x: String) -> String:
		while comp[x] != x: x = comp[x]
		return x
	for pr in pairs:
		var rule := _rule(pr.a.type, pr.b.type)
		match rule:
			"open":
				_add_op(pr.a, pr.sa, pr.lo, pr.hi, "open")
				_add_op(pr.b, pr.sb, pr.lo, pr.hi, "open")
				comp[find.call(pr.a.id)] = find.call(pr.b.id)
			"rail":
				var hall: Dictionary = pr.a if pr.a.type == "hall" else pr.b
				var void_side: String = pr.sb if hall == pr.a else pr.sa
				# the stair comes up at the stairwell's back (N) edge: leave that open, rail the rest
				_add_op(hall, pr.sa if hall == pr.a else pr.sb, pr.lo, pr.hi, "open" if void_side == "N" else "rail")
				comp[find.call(pr.a.id)] = find.call(pr.b.id)
			"arch":
				var wdt := minf(2.6, pr.hi - pr.lo - 0.5)
				if wdt > 1.0:
					var c: float = (pr.lo + pr.hi) / 2.0
					_add_op(pr.a, pr.sa, c - wdt / 2, c + wdt / 2, "arch", 0.0, 2.3)
					_add_op(pr.b, pr.sb, c - wdt / 2, c + wdt / 2, "arch", 0.0, 2.3)
					comp[find.call(pr.a.id)] = find.call(pr.b.id)
	# the hub: the hall, else the lounge, else the biggest room
	var hub: Dictionary = rooms[0]
	for r in rooms:
		if r.get("hub", false) or (not hub.get("hub", false) and (r.x1 - r.x0) * (r.z1 - r.z0) > (hub.x1 - hub.x0) * (hub.z1 - hub.z0)):
			hub = r
	for _pass in rooms.size() + 2:
		var changed := false
		for r in rooms:
			if r.type in ["void", "stair"] or find.call(r.id) == find.call(hub.id):
				continue
			var best := {}
			var bs := -1.0
			for pr in pairs:
				var me_a: bool = pr.a == r
				if not me_a and pr.b != r: continue
				var o: Dictionary = pr.b if me_a else pr.a
				if o.type in ["void", "stair"] or find.call(o.id) != find.call(hub.id): continue
				if pr.hi - pr.lo < DOOR_W + 0.4: continue
				var sc: float = PREF.get(r.type, {}).get(o.type, 1) + rng.randf() * 0.5
				if sc > bs:
					bs = sc
					best = pr
			if best.is_empty():
				continue
			# a door near one end of the shared wall, clear of the corners
			var lo: float = best.lo + 0.2
			var hi: float = best.hi - 0.2 - DOOR_W
			var c0: float = lo if rng.randf() < 0.5 else hi
			if hi - lo > 0.1 and rng.randf() < 0.3: c0 = rng.randf_range(lo, hi)
			var sa: String = best.sa
			var sb: String = best.sb
			if _free_span(best.a, sa, c0, c0 + DOOR_W) and _free_span(best.b, sb, c0, c0 + DOOR_W):
				var opa := _add_op(best.a, sa, c0, c0 + DOOR_W, "door", 0.0, DOOR_H)
				_add_op(best.b, sb, c0, c0 + DOOR_W, "doorx", 0.0, DOOR_H)   # the other side of the same hole (no leaf)
				opa["leaf"] = true
				comp[find.call(r.id)] = find.call(hub.id)
				changed = true
		if not changed:
			break

## Doors to the outside: front into the hall or lounge (or the roller doors of a shed), back out of the kitchen/laundry
static func _ext_doors(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var rooms: Array = p.floors[0].rooms
	var w: float = p.w
	var d: float = p.d
	var find_room := func(types: Array, side: String) -> Dictionary:
		for t in types:
			for r in rooms:
				if r.type == t and absf(float(r["z1" if side == "S" else "z0"]) - (d / 2 if side == "S" else -d / 2)) < 0.02:
					return r
		return {}
	match p.kind:
		"qlder", "cottage", "brick", "two_storey":
			var fr: Dictionary = find_room.call(["hall", "lounge", "dining"], "S")
			if not fr.is_empty():
				var c := (float(fr.x0) + float(fr.x1)) / 2.0 - DOOR_W / 2
				if fr.type != "hall": c = rng.randf_range(float(fr.x0) + 0.3, float(fr.x1) - 0.3 - DOOR_W)
				var op := _add_op(fr, "S", c, c + DOOR_W, "door", 0.0, DOOR_H)
				op["leaf"] = true
				op["ext"] = true
				p.ext_doors.append({"room": fr, "side": "S", "c": c + DOOR_W / 2, "front": true})
			var br: Dictionary = find_room.call(["kitchen", "laundry", "hall", "dining"], "N")
			if not br.is_empty():
				var lo := float(br.x0) + 0.3
				var hi := float(br.x1) - 0.3 - DOOR_W
				for _t in 6:
					var c := rng.randf_range(lo, hi)
					if _free_span(br, "N", c, c + DOOR_W):
						var op := _add_op(br, "N", c, c + DOOR_W, "door", 0.0, DOOR_H)
						op["leaf"] = true
						op["ext"] = true
						p.ext_doors.append({"room": br, "side": "N", "c": c + DOOR_W / 2, "front": false})
						break
		"shed", "workshop", "warehouse":
			# roller doors: shed on the front gable, workshops along a long side; a walk-in door too
			for r in rooms:
				if r.type in ["shed", "workshop", "warehouse"]:
					var side := "S" if p.kind == "shed" else ("E" if rng.randf() < 0.5 else "W")
					var on_edge: bool = (side == "S" and absf(float(r.z1) - d / 2) < 0.02) or (side == "E" and absf(float(r.x1) - w / 2) < 0.02) or (side == "W" and absf(float(r.x0) + w / 2) < 0.02)
					if not on_edge: continue
					var a := float(r.x0) if side == "S" else float(r.z0)
					var b := float(r.x1) if side == "S" else float(r.z1)
					var rw := minf(3.6 if p.kind == "shed" else 4.5, b - a - 0.8)
					if rw < 1.8: break          # too small for a roller door: the walk-in door'll do
					var n := 1 if b - a < 9 else 2
					for k in n:
						var c := a + (b - a) * (k + 1) / (n + 1) - rw / 2
						if _free_span(r, side, c, c + rw):
							var op := _add_op(r, side, c, c + rw, "roller", 0.0, minf(float(r.h) - 0.4, 4.2 if p.kind != "shed" else 3.2))
							if float(op.y1) < 2.1:
								op.kind = "door"; op["leaf"] = true; op.b = op.a + DOOR_W; op.y1 = DOOR_H
							op["ext"] = true
							op["open_frac"] = rng.randf_range(0.4, 1.0)
					break
			# walk-in door into the office (workshops) or the side of the shed
			var dr: Dictionary = find_room.call(["office", "shed"], "S") if p.kind != "shed" else {}
			if p.kind == "shed":
				for r in rooms:
					if r.type == "shed" and absf(float(r.x0) + w / 2) < 0.02:
						var c := rng.randf_range(float(r.z0) + 0.5, float(r.z1) - 0.5 - DOOR_W)
						if _free_span(r, "W", c, c + DOOR_W):
							var op := _add_op(r, "W", c, c + DOOR_W, "door", 0.0, DOOR_H)
							op["leaf"] = true
							op["ext"] = true
						break
			elif not dr.is_empty():
				var c := (float(dr.x0) + float(dr.x1)) / 2.0 - DOOR_W / 2
				var op := _add_op(dr, "S", c, c + DOOR_W, "door", 0.0, DOOR_H)
				op["leaf"] = true
				op["ext"] = true
		"shop":
			ShopGen.ext_doors(p, rng)
		"pub", "school", "church", "hospital", "police", "fire", "post", "motel", "club":
			CivicGen.ext_doors(p, rng)
		"tower":
			for r in rooms:
				if r.type == "lobby":
					var op := _add_op(r, "S", -1.6, 1.6, "open", 0.0, 2.6)
					op["ext"] = true
					p.ext_doors.append({"room": r, "side": "S", "c": 0.0, "front": true})
		"dairy":
			for r in rooms:
				if r.type == "milking":
					var op := _add_op(r, "S", float(r.x0) + 1.0, float(r.x0) + 3.0, "open", 0.0, 2.4)
					op["ext"] = true
					var op2 := _add_op(r, "N", float(r.x0) + 1.0, float(r.x0) + 3.0, "open", 0.0, 2.4)
					op2["ext"] = true
				if r.type == "office":
					var c := (float(r.x0) + float(r.x1)) / 2.0 - DOOR_W / 2
					var op := _add_op(r, "S", c, c + DOOR_W, "door", 0.0, DOOR_H)
					op["leaf"] = true
					op["ext"] = true

static func _ext_side(p: Dictionary, r: Dictionary, side: String) -> bool:
	var w: float = p.w
	var d: float = p.d
	match side:
		"N": return absf(float(r.z0) + d / 2) < 0.02
		"S": return absf(float(r.z1) - d / 2) < 0.02
		"W": return absf(float(r.x0) + w / 2) < 0.02
		"E": return absf(float(r.x1) - w / 2) < 0.02
	return false

static func _windows(p: Dictionary, rng: RandomNumberGenerator) -> void:
	if p.kind == "shop":
		ShopGen.windows(p, rng)
		return
	for f in p.floors:
		for r in f.rooms:
			if r.type in ["void", "stair", "lift"] or r.get("nowin", false): continue
			for side in ["N", "S", "W", "E"]:
				if not _ext_side(p, r, side): continue
				if p.get("open_front", false) and side == "S": continue
				var a := float(r.x0) if side in ["N", "S"] else float(r.z0)
				var b := float(r.x1) if side in ["N", "S"] else float(r.z1)
				var len := b - a
				var ww := 1.2
				var y0 := 0.95
				var y1 := 2.1
				var n := int(len / 3.0)
				match r.type:
					"hall": n = 1 if len > 2.5 and side in ["N", "S"] and rng.randf() < 0.5 else 0
					"bath", "toilet", "laundry": ww = 0.7; y0 = 1.5; n = min(n, 1) if len > 1.5 else 0
					"lounge": ww = 1.8; n = max(n, 1)
					"bed", "kitchen", "dining", "office", "lunch", "study": n = max(n, 1)
					"shed", "workshop", "warehouse", "machinery", "store": ww = 1.5; y0 = 1.9 if p.kind == "shed" else float(r.h) - 1.5; y1 = y0 + 0.9; n = int(len / 7.0)
					"milking", "vat": ww = 1.4; y0 = 1.3; y1 = 2.2; n = int(len / 3.5)
				if side == "S" and r.type == "hall": n = 0
				for k in n:
					var c := a + len * (k + 1) / (n + 1) - ww / 2
					if _free_span(r, side, c - 0.1, c + ww + 0.1):
						_add_op(r, side, c, c + ww, "window", y0, y1)

# ------------------------------------------------------------------------------------------------ building it
## The shell of a plan: one mesh, box collision, doors. `ground` gives the ground height (in this frame) under a
## local x, z. Returns the node; plan["built"] gets the bits BuildProps needs.
static func build(p: Dictionary, ground: Callable) -> Node3D:
	var root := Node3D.new()
	root.name = "Building"
	var g := Geo.new()
	p["flights"] = []
	p["_windows"] = []
	p["_rollers"] = []
	g.set_meta("plan", p)
	var w: float = p.w
	var d: float = p.d
	var lowest := 0.0
	for c in [Vector2(-w / 2, -d / 2), Vector2(w / 2, -d / 2), Vector2(-w / 2, d / 2), Vector2(w / 2, d / 2), Vector2.ZERO]:
		lowest = minf(lowest, float(ground.call(c.x, c.y)))
	p["lowest"] = lowest
	var doors: Array = []
	var top_h := 0.0
	var cut: float = p.get("cut", INF)
	for fi in p.floors.size():
		var f: Dictionary = p.floors[fi]
		if fi > int(p.get("cut_floor", 99)): continue
		top_h = maxf(top_h, float(f.y) + float(f.h))
		for r in f.rooms:
			if r.get("poly", false): continue          # a traced mall's rooms are only for the fit-out (PolyMall)
			_room_shell(p, g, r, float(f.y), doors)
	var traced: bool = p.kind == "mall" and p.mall.has("poly")
	if not traced:
		_outer_skin(p, g, doors)
		_base(p, g, ground, lowest)
	if p.verandah != null:
		_verandah(p, g, ground)
	if p.kind == "shop":
		if cut == INF:
			ShopGen.top(p, g, top_h, ground)
	elif p.kind == "mall":
		if cut == INF:
			MallGen.top(p, g, top_h, ground)
	elif p.kind == "tower":
		if cut == INF:
			TowerGen.top(p, g)
	elif cut == INF:
		_roof(p, g, top_h)
	_ext_steps(p, g, ground)
	# the mesh and its collision
	var mi := MeshInstance3D.new()
	mi.name = "Shell"
	mi.mesh = g.commit()
	root.add_child(mi)
	var sb := StaticBody3D.new()
	sb.name = "Body"
	for s in g.shapes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[1]
		cs.shape = bs
		cs.transform = s[0]
		sb.add_child(cs)
	if g.tris.size() > 0:
		var cs := CollisionShape3D.new()
		var cps := ConcavePolygonShape3D.new()
		cps.backface_collision = true
		cps.set_faces(g.tris)
		cs.shape = cps
		sb.add_child(cs)
	root.add_child(sb)
	var di := 0
	for dd in doors:
		var pv := Node3D.new()
		pv.transform = dd.xf
		root.add_child(pv)
		var leaf := BuildDoor.new()
		leaf.key = "d%d" % di
		pv.add_child(leaf)
		leaf.setup(pv, DOOR_W - 0.04, DOOR_H - 0.03, mat("door:" + ("white" if dd.ext else "cream")), dd.get("glass", false))
		di += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed) + 77
	for wi in p._windows.size():
		var wd: Dictionary = p._windows[wi]
		var win := BuildWindow.new()
		win.key = "w%d" % wi
		win.transform = wd.xf
		root.add_child(win)
		win.setup(wd.w, wd.h, rng.randf() < (0.2 if wd.get("fixed", false) else 0.12), wd.get("fixed", false))
	for ri in p._rollers.size():
		var rd: Dictionary = p._rollers[ri]
		var ro := BuildRoller.new()
		ro.transform = rd.xf
		root.add_child(ro)
		ro.setup(rd.w, rd.h, rd.frac if rng.randf() < 0.6 else 0.0, rd.get("grille", false))
	if p.kind == "tower":
		TowerGen.lifts(p, root)
	elif p.kind == "mall" and p.has("mall") and p.mall.has("street_fl") and p.floors.size() > 1:
		# a village centre's lift: a panel in the car on each floor, F takes you to the other one
		var stops := []; var names := []; var panels := []
		for fi in p.floors.size():
			for r in p.floors[fi].rooms:
				if r.type == "lift":
					var cx := (float(r.x0) + float(r.x1)) / 2; var cz := (float(r.z0) + float(r.z1)) / 2
					stops.append(Vector3(cx, float(p.floors[fi].y) + 0.1, cz))
					names.append("Car park" if fi == 0 else "Shops")
					panels.append(Vector3(float(r.x1) - 0.25, 0, cz))
		for i in stops.size():
			var lf := BuildLift.new()
			root.add_child(lf)
			lf.setup(stops, names, i, float(p.d), panels[i])
	if p.has("sign"):
		# its name over the door, on a board
		if not p.has("_labels"): p["_labels"] = []
		var vd: float = float(p.verandah.depth) if p.verandah != null else 0.0
		var sy: float = float(p.h) - 0.45 if vd == 0.0 else float(p.h) - 0.75
		ShopGen._label(p, Vector3(0, sy, d / 2 + T_OUT + vd + 0.05), str(p.sign), 0.34, minf(w - 1.0, 9.0), 0.0, Color(0.1, 0.1, 0.12))
	if p.kind in ["shop", "mall", "tower"] or p.has("sign"):
		ShopGen.labels(p, root)
	return root

## The outside only, cheaply, into a shared Geo (whose xf is this building's transform): cladding without openings,
## dark panes where the windows are, the base, a plain verandah, the roof. For far-off buildings merged by the cell.
static func build_lod(p: Dictionary, g: Geo, ground: Callable) -> void:
	var w: float = p.w
	var d: float = p.d
	var nf: int = p.floors.size()
	var top_y: float = float(p.floors[nf - 1].y) + float(p.floors[nf - 1].h)
	var lowest := 0.0
	for c in [Vector2(-w / 2, -d / 2), Vector2(w / 2, -d / 2), Vector2(-w / 2, d / 2), Vector2(w / 2, d / 2)]:
		lowest = minf(lowest, float(ground.call(c.x, c.y)))
	var bot := -0.12
	if p.get("open_front", false):
		g.aabb(p.clad, Vector3(-w / 2 - T_OUT, bot, -d / 2 - T_OUT), Vector3(w / 2 + T_OUT, top_y, -d / 2), false)
		g.aabb(p.clad, Vector3(-w / 2 - T_OUT, bot, -d / 2), Vector3(-w / 2, top_y, d / 2), false)
		g.aabb(p.clad, Vector3(w / 2, bot, -d / 2), Vector3(w / 2 + T_OUT, top_y, d / 2), false)
		g.aabb("dirt", Vector3(-w / 2, -0.1, -d / 2), Vector3(w / 2, 0.0, d / 2), false)
	elif p.kind == "mall":
		# not a box: one block per room
		for f in p.floors:
			for r in f.rooms:
				if r.type != "void" and not r.get("poly", false):
					g.aabb(p.clad, Vector3(float(r.x0), float(f.y) + bot, float(r.z0)), Vector3(float(r.x1), float(f.y) + float(f.h), float(r.z1)), false)
	else:
		g.aabb(p.clad, Vector3(-w / 2 - T_OUT, bot, -d / 2 - T_OUT), Vector3(w / 2 + T_OUT, top_y, d / 2 + T_OUT), false)
		# window panes and doors drawn on
		for f in p.floors:
			for r in f.rooms:
				for side in ["N", "S", "W", "E"]:
					if not _ext_side(p, r, side): continue
					var si: Dictionary
					match side:
						"N": si = {"axis": "x", "fixed": -d / 2, "inward": 1.0}
						"S": si = {"axis": "x", "fixed": d / 2, "inward": -1.0}
						"W": si = {"axis": "z", "fixed": -w / 2, "inward": 1.0}
						_: si = {"axis": "z", "fixed": w / 2, "inward": -1.0}
					for op in r.ops[side]:
						if op.kind in ["window", "door", "roller", "open", "bay"]:
							var mk := "glass_dark" if op.kind == "window" else ("door" if op.kind == "door" else "dark")
							_wall_box(g, mk, si, float(op.a), float(op.b), float(f.y) + float(op.y0), float(f.y) + float(op.y1), -T_OUT - 0.02, -T_OUT + 0.01, false)
	if p.stumps:
		var nx := maxi(2, int(ceil(w / 2.4)))
		var nz := maxi(2, int(ceil(d / 2.4)))
		for i in nx + 1:
			for k in nz + 1:
				var x := -w / 2 + 0.15 + (w - 0.3) * i / nx
				var z := -d / 2 + 0.15 + (d - 0.3) * k / nz
				if i != 0 and i != nx and k != 0 and k != nz: continue
				var gy: float = ground.call(x, z)
				g.aabb("timber", Vector3(x - 0.11, gy - 0.3, z - 0.11), Vector3(x + 0.11, -0.12, z + 0.11), false)
	else:
		g.aabb("brick" if p.clad == "brick" else "concrete", Vector3(-w / 2 - T_OUT, lowest - 0.4, -d / 2 - T_OUT), Vector3(w / 2 + T_OUT, -0.12, d / 2 + T_OUT), false)
	if p.verandah != null:
		var vd: float = p.verandah.depth
		var h: float = p.floors[0].h
		var z1 := d / 2 + T_OUT + vd
		g.aabb("deck", Vector3(-w / 2, -0.1, d / 2 + T_OUT), Vector3(w / 2, 0.0, z1), false)
		for x in [-w / 2 + 0.1, 0.0, w / 2 - 0.1]:
			var gy: float = ground.call(x, z1 - 0.1)
			g.aabb("trim", Vector3(x - 0.07, gy, z1 - 0.17), Vector3(x + 0.07, h - 0.35, z1 - 0.03), false)
		g.aabb("trim", Vector3(-w / 2, 0.0, z1 - 0.1), Vector3(w / 2, 1.0, z1 - 0.05), false)
		var rm: String = p.roof.mat + ":white:uv"
		_roof_quad(g, rm, Vector3(-w / 2 - 0.35, h + 0.05, d / 2 + T_OUT), Vector3(w / 2 + 0.35, h + 0.05, d / 2 + T_OUT), Vector3(w / 2 + 0.35, h - 0.4, z1 + 0.35), Vector3(-w / 2 - 0.35, h - 0.4, z1 + 0.35))
	if p.kind == "shop":
		ShopGen.top(p, g, top_y, ground, true)
		return
	if p.kind == "mall":
		MallGen.top(p, g, top_y, ground, true)
		return
	if p.kind == "tower":
		TowerGen.top(p, g, true)
		return
	_roof(p, g, top_y)

## Edge geometry of a room side, in this frame: the line it runs along and how the skin box sits
static func _side_info(r: Dictionary, side: String) -> Dictionary:
	match side:
		"N": return {"axis": "x", "fixed": float(r.z0), "a": float(r.x0), "b": float(r.x1), "inward": 1.0}
		"S": return {"axis": "x", "fixed": float(r.z1), "a": float(r.x0), "b": float(r.x1), "inward": -1.0}
		"W": return {"axis": "z", "fixed": float(r.x0), "a": float(r.z0), "b": float(r.z1), "inward": 1.0}
		_: return {"axis": "z", "fixed": float(r.x1), "a": float(r.z0), "b": float(r.z1), "inward": -1.0}

## A wall piece from (along a..b, height y0..y1) on a side, offset from the line by t0..t1 (toward the room is +)
static func _wall_box(g: Geo, mk: String, si: Dictionary, a: float, b: float, y0: float, y1: float, t0: float, t1: float, collide := true) -> void:
	var o0: float = si.fixed + si.inward * t0
	var o1: float = si.fixed + si.inward * t1
	if si.axis == "x":
		g.aabb(mk, Vector3(a, y0, minf(o0, o1)), Vector3(b, y1, maxf(o0, o1)), collide)
	else:
		g.aabb(mk, Vector3(minf(o0, o1), y0, a), Vector3(maxf(o0, o1), y1, b), collide)

## Solid wall pieces along a..b at heights 0..h, skipping the openings
static func _cut_wall(g: Geo, mk: String, si: Dictionary, a: float, b: float, base: float, h: float, ops: Array, t0: float, t1: float) -> void:
	var sorted := ops.duplicate()
	sorted.sort_custom(func(x, y): return float(x.a) < float(y.a))
	var x := a
	for op in sorted:
		var oa := clampf(float(op.a), a, b)
		var ob := clampf(float(op.b), a, b)
		if ob <= oa: continue
		if oa > x:
			_wall_box(g, mk, si, x, oa, base, base + h, t0, t1)
		if float(op.y0) > 0.01:
			_wall_box(g, mk, si, oa, ob, base, base + float(op.y0), t0, t1)
		if float(op.y1) < h - 0.01:
			_wall_box(g, mk, si, oa, ob, base + float(op.y1), base + h, t0, t1)
		x = maxf(x, ob)
	if x < b:
		_wall_box(g, mk, si, x, b, base, base + h, t0, t1)

const FLOOR_MAT := {"lounge": "timber_floor", "dining": "timber_floor", "hall": "timber_floor", "stair": "timber_floor", "kitchen": "lino",
	"bed": "carpet", "bath": "tile", "laundry": "lino", "toilet": "tile", "shed": "concrete", "store": "concrete", "workshop": "concrete",
	"warehouse": "concrete_worn", "office": "carpet", "lunch": "lino", "machinery": "dirt", "milking": "concrete_worn", "vat": "concrete", "study": "carpet",
	"shop": "lino", "lobby": "lino",
	"carpark": "concrete_worn", "ramp": "concrete", "dock": "concrete_worn", "concourse": "terrazzo", "unit": "lino", "super": "lino",
	"super_store": "concrete", "bigbox": "lino", "foodcourt": "tile", "fc_kitchen": "tile", "service": "concrete", "security": "carpet", "lift": "concrete", "cinema": "carpet", "cine_hall": "carpet", "cine_lobby": "carpet"}

static func _skin_mat(p: Dictionary, r: Dictionary) -> String:
	if r.type in ["bath", "toilet"]: return "tile"
	if r.type in ["shed", "machinery", "workshop", "warehouse", "store"]: return p.clad
	if r.type in ["milking", "vat"]: return "plaster:white"
	if p.kind == "mall":
		match r.type:
			"carpark", "ramp", "dock", "service", "super_store", "lift": return "concrete"
			"fc_kitchen": return "tile"
			"cinema": return "plaster:charcoal"
			"cine_hall", "cine_lobby": return "plaster:maroon"
			"concourse", "lobby", "super", "bigbox", "foodcourt", "hall": return "plaster:white"
			"unit", "shop": return ["plaster:white", "plaster:cream", "plaster:sand", "plaster:pale_blue", "plaster:sage", "plaster:pink"][absi(hash(r.id) + int(p.seed)) % 6]
	if r.type == "shop": return ["plaster:white", "plaster:cream", "plaster:sand", "plaster:pale_blue", "plaster:sage"][absi(int(p.seed)) % 5]
	if r.type in ["store", "lobby"] and p.kind == "shop": return "plaster_worn:white"
	var seed := int(p.seed) + hash(r.id)
	return ["plaster:cream", "plaster:white", "plaster:green", "plaster:blue", "plaster:pink", "plaster:yellow", "plaster:tan"][absi(seed) % 7]

static func _room_shell(p: Dictionary, g: Geo, r: Dictionary, fy: float, doors: Array) -> void:
	var h: float = r.h
	var skin := _skin_mat(p, r)
	var x0: float = r.x0
	var x1: float = r.x1
	var z0: float = r.z0
	var z1: float = r.z1
	if r.type != "void":
		var fm: String = FLOOR_MAT.get(r.type, "timber_floor")
		if p.kind == "qlder" and fm == "carpet": fm = "timber_floor"
		if p.kind == "mall" and r.type in ["lobby", "shop", "unit", "super", "bigbox", "foodcourt", "concourse", "hall", "ramp"]: fm = "terrazzo"
		g.aabb(fm, Vector3(x0, fy - 0.12, z0), Vector3(x1, fy, z1))
	if p.has("cut"): h = minf(h, float(p.cut))
	if r.type not in ["void", "stair", "shed", "machinery", "workshop", "warehouse", "ramp"] and not r.get("open_above", false) and not p.has("cut"):
		var ch := minf(h, float(r.get("ceil", h)))          # a dropped ceiling (a mall shop under a high roof)
		g.aabb("concrete" if r.type in ["carpark", "dock"] else "trim:white", Vector3(x0, fy + ch, z0), Vector3(x1, fy + ch + 0.06, z1), false)
	if r.type == "void":
		return
	if r.type == "stair":
		_stair(g, r, fy, float(p.get("stair_rise", 2.9)))
		return
	for side in ["N", "S", "W", "E"]:
		var si := _side_info(r, side)
		var ops: Array = r.ops[side]
		# a rail across the stairwell instead of a wall
		for op in ops:
			if op.kind == "rail":
				_wall_box(g, "timber", si, float(op.a), float(op.b), fy + 0.95, fy + 1.0, 0.0, 0.06)
				var n := int((float(op.b) - float(op.a)) / 0.13)
				for k in n + 1:
					var c: float = float(op.a) + (float(op.b) - float(op.a)) * k / max(n, 1)
					_wall_box(g, "timber", si, c - 0.02, c + 0.02, fy, fy + 0.95, 0.01, 0.05, k % 3 == 0)
		var open_ops := []
		for op in ops:
			if op.kind != "liftdoor":
				open_ops.append(op)
		var thin := T_IN
		if r.type in ["shed", "machinery", "workshop", "warehouse"] and _ext_side(p, r, side):
			continue     # sheds: the cladding is the wall (built in _outer_skin)
		if p.get("open_front", false) and side == "S":
			continue
		_cut_wall(g, skin, si, si.a, si.b, fy, h, open_ops, 0.0, thin)
		# door leaves, window glass and frames
		for op in ops:
			match op.kind:
				"door":
					if op.get("leaf", false):
						var hinge_a := float(op.a) + 0.02
						var pos: Vector3
						var yaw := 0.0
						# the leaf lies flat in the wall's line when shut, pivot at the hinge end
						var off: float = si.fixed + si.inward * (T_IN * 0.5 if not op.get("ext", false) else -T_OUT * 0.5)
						if si.axis == "x":
							pos = Vector3(hinge_a, fy, off)
							yaw = 0.0
						else:
							pos = Vector3(off, fy, hinge_a)
							yaw = -PI / 2      # leaf's +x runs along +z
						doors.append({"xf": Transform3D(Basis(Vector3.UP, yaw), pos), "ext": op.get("ext", false)})
					_frame(g, si, op, fy, -T_OUT if op.get("ext", false) else -T_IN, T_IN)
				"doorx":
					_frame(g, si, op, fy, 0.0, T_IN)
				"window":
					var glass_t := -T_OUT * 0.5 if _ext_side(p, r, side) else 0.0
					# the window itself is its own node (BuildWindow): it opens, breaks and gets boarded
					p["_windows"].append({"xf": _opening_xf(si, (float(op.a) + float(op.b)) * 0.5, fy + (float(op.y0) + float(op.y1)) * 0.5, glass_t),
						"w": float(op.b) - float(op.a), "h": float(op.y1) - float(op.y0), "fixed": op.get("fixed", false)})
					_frame(g, si, op, fy, -T_OUT, T_IN)
					if op.get("display", false):
						# a shopfront: on a stall board of dark glazed tiles
						_wall_box(g, "tile:black", si, float(op.a) - 0.06, float(op.b) + 0.06, fy, fy + float(op.y0), -T_OUT - 0.07, -T_OUT + 0.01)
				"bay":
					ShopGen.bay(p, g, si, op, fy, doors)
					# sill
					_wall_box(g, "trim", si, float(op.a) - 0.05, float(op.b) + 0.05, fy + float(op.y0) - 0.04, fy + float(op.y0), -T_OUT - 0.04, T_IN + 0.03)
				"arch":
					_frame(g, si, op, fy, 0.0, T_IN)
				"roller":
					# a shutter on an inside wall (a mall shop's front); outside ones are done with the cladding
					if not _ext_side(p, r, side):
						_wall_box(g, "steel", si, float(op.a) - 0.1, float(op.b) + 0.1, fy + float(op.y1), fy + float(op.y1) + 0.35, -0.2, T_IN, false)
						p["_rollers"].append({"xf": _opening_xf(si, (float(op.a) + float(op.b)) * 0.5, fy + float(op.y0), -0.12),
							"w": float(op.b) - float(op.a), "h": float(op.y1) - float(op.y0), "frac": float(op.get("open_frac", 1.0)) * 0.94, "grille": op.get("grille", false)})

## Where an opening's own node sits: on the wall line (offset t toward the room), its +z pointing outside
static func _opening_xf(si: Dictionary, along: float, y: float, t: float) -> Transform3D:
	var off: float = si.fixed + si.inward * t
	var pos := Vector3(along, y, off) if si.axis == "x" else Vector3(off, y, along)
	var out := Vector3(0, 0, -si.inward) if si.axis == "x" else Vector3(-si.inward, 0, 0)
	return Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), pos)

## White frame strips round an opening, between offsets t0..t1
static func _frame(g: Geo, si: Dictionary, op: Dictionary, fy: float, t0: float, t1: float) -> void:
	var a := float(op.a)
	var b := float(op.b)
	var y0 := fy + float(op.y0)
	var y1 := fy + float(op.y1)
	_wall_box(g, "trim", si, a - 0.06, a, y0, y1 + 0.06, t0 - 0.012, t1 + 0.012, false)
	_wall_box(g, "trim", si, b, b + 0.06, y0, y1 + 0.06, t0 - 0.012, t1 + 0.012, false)
	_wall_box(g, "trim", si, a - 0.06, b + 0.06, y1, y1 + 0.06, t0 - 0.012, t1 + 0.012, false)

## Cladding round the outside of the footprint, storey by storey, cut where outside rooms have openings
static func _outer_skin(p: Dictionary, g: Geo, _doors: Array) -> void:
	var w: float = p.w
	var d: float = p.d
	var nf: int = mini(p.floors.size(), int(p.get("cut_floor", 99)) + 1)
	for fi in nf:
		var f: Dictionary = p.floors[fi]
		var fy: float = f.y
		var h: float = float(f.h) if fi == nf - 1 else float(p.floors[fi + 1].y) - fy
		if p.has("cut"): h = minf(h, float(p.cut))
		var bot := fy - 0.12 if fi == 0 else fy
		for side in ["N", "S", "W", "E"]:
			if p.get("open_front", false) and side == "S":
				# open-fronted machinery shed: posts across the front
				var nb := maxi(2, int(w / 4.5))
				for k in nb + 1:
					var x := -w / 2 + w * k / nb
					g.aabb("steel", Vector3(x - 0.08, 0, d / 2 - 0.16), Vector3(x + 0.08, h, d / 2))
				continue
			var ops := []
			for r in f.rooms:
				if not _ext_side(p, r, side): continue
				for op in r.ops[side]:
					var o: Dictionary = op.duplicate()
					o.y0 = float(o.y0) + (fy - bot)
					o.y1 = float(o.y1) + (fy - bot)
					ops.append(o)
			var si: Dictionary
			match side:
				"N": si = {"axis": "x", "fixed": -d / 2, "inward": 1.0}
				"S": si = {"axis": "x", "fixed": d / 2, "inward": -1.0}
				"W": si = {"axis": "z", "fixed": -w / 2, "inward": 1.0}
				_: si = {"axis": "z", "fixed": w / 2, "inward": -1.0}
			var a := -w / 2 - T_OUT if si.axis == "x" else -d / 2
			var b := w / 2 + T_OUT if si.axis == "x" else d / 2
			var shed: bool = p.kind in ["shed", "machine_shed", "workshop", "warehouse"]
			if p.kind == "mall":
				# a mall needn't fill its block: no wall along the stretches of the edge where there's no room behind it
				var spans := []
				for r in f.rooms:
					if r.type != "void" and _ext_side(p, r, side):
						spans.append([float(r.x0), float(r.x1)] if si.axis == "x" else [float(r.z0), float(r.z1)])
				spans.sort_custom(func(u, v): return u[0] < v[0])
				var at: float = a
				for sp in spans + [[b, b]]:
					if float(sp[0]) - at > 0.05:
						ops.append({"a": at, "b": float(sp[0]), "kind": "open", "y0": 0.0, "y1": 999.0})
					at = maxf(at, float(sp[1]))
			_cut_wall(g, p.clad, si, a, b, bot, h + (fy - bot), ops, -T_OUT, 0.0 if not shed else 0.04)
			# roller doors: their own nodes (BuildRoller), a steel header over each
			for op in ops:
				if op.kind == "roller":
					var top := bot + float(op.y1)
					_wall_box(g, "steel", si, float(op.a) - 0.1, float(op.b) + 0.1, top, top + 0.35, -0.25, 0.05, false)
					p["_rollers"].append({"xf": _opening_xf(si, (float(op.a) + float(op.b)) * 0.5, bot + float(op.y0), -T_OUT * 0.5),
						"w": float(op.b) - float(op.a), "h": float(op.y1) - float(op.y0), "frac": float(op.get("open_frac", 1.0)) * 0.94})

## What it stands on: a slab with a plinth, or stumps (high ones for a Queenslander, with the space under it open)
static func _base(p: Dictionary, g: Geo, ground: Callable, lowest: float) -> void:
	var w: float = p.w
	var d: float = p.d
	if p.stumps:
		var nx := maxi(2, int(ceil(w / 2.4)))
		var nz := maxi(2, int(ceil(d / 2.4)))
		for i in nx + 1:
			for k in nz + 1:
				var x := -w / 2 + 0.15 + (w - 0.3) * i / nx
				var z := -d / 2 + 0.15 + (d - 0.3) * k / nz
				var gy: float = ground.call(x, z)
				g.aabb("timber" if p.kind == "qlder" else "concrete", Vector3(x - 0.11, gy - 0.4, z - 0.11), Vector3(x + 0.11, -0.12, z + 0.11))
		# bearers under the floor, and a skirt of battens on low-set houses
		for k in nz + 1:
			var z := -d / 2 + 0.15 + (d - 0.3) * k / nz
			g.aabb("timber", Vector3(-w / 2, -0.32, z - 0.08), Vector3(w / 2, -0.12, z + 0.08), false)
		if p.kind == "cottage":
			for side in [[Vector3(-w / 2 - T_OUT, 0, -d / 2 - T_OUT), Vector3(w / 2 + T_OUT, 0, -d / 2)], [Vector3(-w / 2 - T_OUT, 0, d / 2), Vector3(w / 2 + T_OUT, 0, d / 2 + T_OUT)],
					[Vector3(-w / 2 - T_OUT, 0, -d / 2), Vector3(-w / 2, 0, d / 2)], [Vector3(w / 2, 0, -d / 2), Vector3(w / 2 + T_OUT, 0, d / 2)]]:
				var lo: Vector3 = side[0]
				var hi: Vector3 = side[1]
				g.aabb("timber:dark", Vector3(lo.x, lowest - 0.3, lo.z), Vector3(hi.x, -0.12, hi.z))
		if p.under:
			# a slab under the back half where the laundry and the junk live
			var gy: float = ground.call(0, -d / 4)
			p["under_y"] = gy
	else:
		g.aabb("brick" if p.clad == "brick" else "concrete", Vector3(-w / 2 - T_OUT, lowest - 0.4, -d / 2 - T_OUT), Vector3(w / 2 + T_OUT, -0.12, d / 2 + T_OUT))

## Stairs inside a stair cell, rising from its front (+z) to its back to the storey above
static func _stair(g: Geo, r: Dictionary, fy: float, rise_to: float) -> void:
	var n := int(ceil(rise_to / RISE))
	var rise := rise_to / n
	var run := (float(r.z1) - float(r.z0)) / n
	for i in n:
		var zf := float(r.z1) - i * run
		g.aabb("timber_floor", Vector3(float(r.x0) + 0.02, fy, zf - run), Vector3(float(r.x1) - 0.02, fy + (i + 1) * rise, zf), false)
		if i > 0:   # solid under the ramp so nobody walks in under the stair
			g.shapes.append([Transform3D(Basis(), Vector3((float(r.x0) + float(r.x1)) / 2, fy + i * rise * 0.5, zf - run / 2)), Vector3(float(r.x1) - float(r.x0) - 0.04, i * rise, run)])
	var sf := Vector3((float(r.x0) + float(r.x1)) / 2, fy, float(r.z1))
	var st := Vector3((float(r.x0) + float(r.x1)) / 2, fy + rise_to, float(r.z0))
	_ramp(g, sf + (sf - st).normalized() * 0.5, st, float(r.x1) - float(r.x0) - 0.04)

## An invisible slope from foot to top for walking up steps
static func _ramp(g: Geo, foot: Vector3, top: Vector3, width: float) -> void:
	var dir := (top - foot)
	var hd := Vector3(dir.x, 0, dir.z).normalized()
	var side := hd.cross(Vector3.UP).normalized()
	var z := -dir.normalized()
	var y := z.cross(side).normalized()
	if y.y < 0: y = -y; side = -side
	var basis := Basis(side, y, z)
	var len := dir.length()
	var mid := (foot + top) * 0.5 - y * 0.06
	g.shapes.append([Transform3D(basis, mid), Vector3(width, 0.12, len)])

## Steps (a flight of them, as many as it takes) from the ground up to a door sill at `top`, going out along `out`
static func _flight(g: Geo, top: Vector3, out: Vector3, width: float, ground: Callable, mk := "timber") -> void:
	var gy: float = ground.call(top.x + out.x * 0.5, top.z + out.z * 0.5)
	if top.y - gy < 0.08:
		return
	# step down and out until the steps meet the ground where they are (ground falling away under a flight just
	# makes it longer, so it never stops short in mid-air)
	var rise := RISE
	var n := 0
	while n < 70:
		var c := top + out * (GOING * (n + 0.5))
		if top.y - (n + 1) * rise <= float(ground.call(c.x, c.z)) + 0.03:
			break
		n += 1
	if n == 0:
		n = 1
	var rise_to := n * rise
	gy = top.y - rise_to
	var side := out.cross(Vector3.UP).normalized()
	var yaw := atan2(out.x, out.z)
	var basis := Basis(Vector3.UP, yaw)
	for i in n:
		var h := top.y - (i + 1) * rise     # top of step i (counting down from the door)
		var c := top + out * (GOING * (i + 0.5)) + Vector3(0, 0, 0)
		var bot := minf(gy, float(ground.call(c.x, c.z))) - 0.1
		if n > 4: bot = h - 0.05          # open treads on a long flight
		var cy := (h + bot) * 0.5
		g.box(mk, Transform3D(basis, Vector3(c.x, cy, c.z)), Vector3(width, h - bot, GOING), false)
	# stringers on long flights
	if n > 4:
		for s in [-1.0, 1.0]:
			var a: Vector3 = top + side * (width * 0.5 + 0.03) * s
			var b: Vector3 = a + out * (GOING * n) + Vector3(0, -rise_to, 0)
			var mid: Vector3 = (a + b) * 0.5 + Vector3(0, -0.12, 0)
			var dv: Vector3 = (b - a)
			var zz: Vector3 = dv.normalized()
			var yy: Vector3 = zz.cross(side).normalized()
			if yy.y < 0: yy = -yy
			g.box("timber", Transform3D(Basis(yy.cross(zz).normalized(), yy, zz), mid), Vector3(0.05, 0.25, dv.length()), false)
			# handrail on posts
			g.box("timber", Transform3D(Basis(yy.cross(zz).normalized(), yy, zz), mid + Vector3(0, 0.95, 0)), Vector3(0.05, 0.06, dv.length()), false)
			var np := maxi(2, int(dv.length() / 1.3))
			for k in np + 1:
				var pp: Vector3 = a.lerp(b, float(k) / np)
				g.aabb("timber", pp + Vector3(-0.03, -0.1, -0.03), pp + Vector3(0.03, 0.92, 0.03), false)
	# the slope runs on past the bottom step into the ground, so there's no lip at the foot
	var foot := top + out * (GOING * n) + Vector3(0, -rise_to, 0)
	if g.has_meta("plan"):
		var pl: Dictionary = g.get_meta("plan")
		if not pl.has("flights"): pl["flights"] = []
		pl.flights.append({"top": top, "foot": foot + (foot - top).normalized() * 0.5})
	_ramp(g, foot + (foot - top).normalized() * 0.9, top, width)

## A front verandah (and sometimes down the sides) on posts, with a rail and its own skillion roof
static func _verandah(p: Dictionary, g: Geo, ground: Callable) -> void:
	var w: float = p.w
	var d: float = p.d
	var vd: float = p.verandah.depth
	var sides: bool = p.verandah.sides
	var h: float = p.floors[0].h
	var x0 := -w / 2 - (vd if sides else 0.0)
	var x1 := w / 2 + (vd if sides else 0.0)
	var z0 := d / 2 + T_OUT
	var z1 := d / 2 + T_OUT + vd
	var rects := [[x0, z0, x1, z1]]
	if sides:
		rects.append([x0, -d / 2 + 1.0, -w / 2 - T_OUT, z0])
		rects.append([w / 2 + T_OUT, -d / 2 + 1.0, x1, z0])
	var stair_x := 0.0
	for e in p.ext_doors:
		if e.front: stair_x = e.c
	for rc in rects:
		g.aabb("deck", Vector3(rc[0], -0.1, rc[1]), Vector3(rc[2], 0.0, rc[3]))
	# posts and stumps along the outer edge
	var pts := []
	var n := maxi(2, int((x1 - x0) / 2.6))
	for k in n + 1:
		pts.append(Vector2(x0 + 0.08 + (x1 - x0 - 0.16) * k / n, z1 - 0.08))
	if sides:
		for s in [x0 + 0.08, x1 - 0.08]:
			var m := maxi(1, int((z1 - (-d / 2 + 1.0)) / 2.6))
			for k in m:
				pts.append(Vector2(s, -d / 2 + 1.08 + (z1 - (-d / 2 + 1.0)) * k / m))
	for pt in pts:
		var gy: float = ground.call(pt.x, pt.y)
		g.aabb("timber", Vector3(pt.x - 0.1, gy - 0.3, pt.y - 0.1), Vector3(pt.x + 0.1, -0.1, pt.y + 0.1))
		g.aabb("trim", Vector3(pt.x - 0.06, 0, pt.y - 0.06), Vector3(pt.x + 0.06, h - 0.35, pt.y + 0.06))
	# rail along the front, gap at the stairs
	var rail := func(a: Vector3, b: Vector3) -> void:
		var len := a.distance_to(b)
		if len < 0.2: return
		var dir := (b - a).normalized()
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.z))
		g.box("trim", Transform3D(basis, (a + b) * 0.5 + Vector3(0, 0.95, 0)), Vector3(0.07, 0.06, len))
		g.box("trim", Transform3D(basis, (a + b) * 0.5 + Vector3(0, 0.12, 0)), Vector3(0.05, 0.05, len), false)
		var nb := int(len / 0.12)
		for k in nb:
			var c := a + (b - a) * (k + 0.5) / nb
			g.box("trim", Transform3D(basis, c + Vector3(0, 0.53, 0)), Vector3(0.035, 0.8, 0.035), false)
	var zr := z1 - 0.08
	rail.call(Vector3(x0 + 0.1, 0, zr), Vector3(stair_x - 0.65, 0, zr))
	rail.call(Vector3(stair_x + 0.65, 0, zr), Vector3(x1 - 0.1, 0, zr))
	if sides:
		rail.call(Vector3(x0 + 0.08, 0, -d / 2 + 1.1), Vector3(x0 + 0.08, 0, zr))
		rail.call(Vector3(x1 - 0.08, 0, -d / 2 + 1.1), Vector3(x1 - 0.08, 0, zr))
	else:
		rail.call(Vector3(x0 + 0.08, 0, z0 + 0.05), Vector3(x0 + 0.08, 0, zr))
		rail.call(Vector3(x1 - 0.08, 0, z0 + 0.05), Vector3(x1 - 0.08, 0, zr))
	# front stairs down to the yard: straight out, or (a high-set house, now and then, or where straight out would
	# run a long way) from a landing at the top, turned to run down along the front of the verandah
	var srng := RandomNumberGenerator.new()
	srng.seed = int(p.seed) + 5
	var drop: float = -float(ground.call(stair_x, z1 + 2.0))
	var turn: bool = p.kind == "qlder" and (srng.randf() < 0.35 or drop > 3.2)
	if turn:
		var lz0 := z1
		var lz1 := z1 + 1.3
		g.aabb("deck", Vector3(stair_x - 0.65, -0.1, lz0), Vector3(stair_x + 0.65, 0.0, lz1))
		for px in [stair_x - 0.58, stair_x + 0.58]:
			var gy0: float = ground.call(px, lz1 - 0.07)
			g.aabb("timber", Vector3(px - 0.07, gy0 - 0.3, lz1 - 0.14), Vector3(px + 0.07, -0.1, lz1))
			g.aabb("trim", Vector3(px - 0.04, 0.0, lz1 - 0.12), Vector3(px + 0.04, 1.0, lz1 - 0.02), false)
		# down toward the lower end of the front (or the side with more room)
		var left_h: float = ground.call(stair_x - 3.0, lz0 + 0.65)
		var right_h: float = ground.call(stair_x + 3.0, lz0 + 0.65)
		var dir := -1.0 if left_h < right_h - 0.2 else (1.0 if right_h < left_h - 0.2 else (-1.0 if stair_x > 0.0 else 1.0))
		# a rail across the far side of the landing
		g.aabb("trim", Vector3(stair_x - 0.65, 0.93, lz1 - 0.1), Vector3(stair_x + 0.65, 1.0, lz1 - 0.04))
		var sx0 := stair_x - 0.65 * dir
		g.aabb("trim", Vector3(minf(sx0, sx0 - 0.06 * dir), 0.93, lz0), Vector3(maxf(sx0, sx0 - 0.06 * dir), 1.0, lz1), true)
		_flight(g, Vector3(stair_x + 0.65 * dir, 0.0, (lz0 + lz1) * 0.5 + 0.05), Vector3(dir, 0, 0), 1.0, ground)
	else:
		_flight(g, Vector3(stair_x, 0.0, z1), Vector3(0, 0, 1), 1.2, ground)
	# skillion roof from the wall plate down to the posts
	var ov := 0.35
	var ya := h + 0.05
	var yb := h - 0.4
	var rm: String = p.roof.mat + ":white:uv"
	for rc in rects:
		var a := Vector3(rc[0] - (ov if rc[0] <= x0 + 0.01 else 0.0), ya, rc[1])
		var b := Vector3(rc[2] + (ov if rc[2] >= x1 - 0.01 else 0.0), ya, rc[1])
		var far: float = rc[3] + (ov if rc == rects[0] else 0.0)
		if rc != rects[0]:
			# side verandahs slope out sideways
			var outx: float = rc[0] - ov if rc[0] < 0 else rc[2] + ov
			var inx: float = rc[2] if rc[0] < 0 else rc[0]
			var q0 := Vector3(inx, ya, rc[1]); var q1 := Vector3(inx, ya, rc[3] + ov)
			var q2 := Vector3(outx, yb, rc[3] + ov); var q3 := Vector3(outx, yb, rc[1])
			_roof_quad(g, rm, q0, q1, q2, q3)
			continue
		var c := Vector3(b.x, yb, far)
		var dd := Vector3(a.x, yb, far)
		_roof_quad(g, rm, a, b, c, dd)
		# beam along the posts
		g.aabb("trim", Vector3(rc[0], yb - 0.2, rc[3] - 0.15), Vector3(rc[2], yb - 0.02, rc[3] - 0.01), false)

## A roof sheet (two-sided, a little thick) with the corrugations running down the slope
static func _roof_quad(g: Geo, mk: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(d - a).normalized()
	if n.y < 0: n = -n
	var eave := (b - a)
	var u_dir := eave.normalized()
	var v_dir := n.cross(u_dir).normalized()
	var uv := func(p: Vector3) -> Vector2: return Vector2((p - a).dot(u_dir), (p - a).dot(v_dir))
	var t := n * 0.03
	g.quad(mk, a + t, b + t, c + t, d + t, n, uv.call(a), uv.call(b), uv.call(c), uv.call(d))
	var mk_in := mk + ":in" if mk.ends_with(":uv") else mk
	g.quad(mk_in, a, b, c, d, -n, uv.call(a), uv.call(b), uv.call(c), uv.call(d))
	for pp in [[a, b], [b, c], [c, d], [d, a]]:
		var e0: Vector3 = pp[0]
		var e1: Vector3 = pp[1]
		var en := (e1 - e0).cross(n).normalized()
		g.quad(mk, e0, e1, e1 + t, e0 + t, en, Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.03), Vector2(0, 0.03))
	g.tris.append_array(PackedVector3Array([a, b, c, a, c, d]))

static func _roof_tri(g: Geo, mk: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0: n = -n
	var u_dir := (b - a).normalized()
	var v_dir := n.cross(u_dir).normalized()
	var uv := func(p: Vector3) -> Vector2: return Vector2((p - a).dot(u_dir), (p - a).dot(v_dir))
	var t := n * 0.03
	g.tri(mk, a + t, b + t, c + t, n, uv.call(a), uv.call(b), uv.call(c))
	g.tri(mk + ":in" if mk.ends_with(":uv") else mk, a, b, c, -n, uv.call(a), uv.call(b), uv.call(c))
	g.tris.append_array(PackedVector3Array([a, b, c]))

static func _roof(p: Dictionary, g: Geo, top: float) -> void:
	var w: float = p.w
	var d: float = p.d
	var ov := 0.5 if p.kind in ["qlder", "cottage", "brick", "two_storey"] else 0.25
	var x0 := -w / 2 - T_OUT - ov
	var x1 := w / 2 + T_OUT + ov
	var z0 := -d / 2 - T_OUT - ov
	var z1 := d / 2 + T_OUT + ov
	if p.verandah != null:
		z1 = d / 2 + T_OUT + 0.15
	var rmat: String = p.roof.mat + ":white:uv"
	var pitch: float = p.roof.pitch
	var y := top + 0.06
	var along_x: bool = (w >= d) if not p.roof.has("ridge") else (p.roof.ridge == "x")
	# the ceiling-top / wall-plate: close the top of the walls so the roof space isn't open to the sky at the ends
	match p.roof.type:
		"skillion":
			var drop := (z1 - z0) * tan(pitch)
			_roof_quad(g, rmat, Vector3(x0, y + drop, z0), Vector3(x1, y + drop, z0), Vector3(x1, y, z1), Vector3(x0, y, z1))
			# fill the triangle sides with cladding
			for s in [-w / 2 - T_OUT, w / 2]:
				var steps := 6
				for k in steps:
					var za := -d / 2 + d * k / steps
					var hh := (z1 - (za + d / steps)) * tan(pitch)
					g.aabb(p.clad, Vector3(s, y, za), Vector3(s + T_OUT, y + hh, za + d / steps), false)
			g.aabb(p.clad, Vector3(-w / 2 - T_OUT, y, -d / 2 - T_OUT), Vector3(w / 2 + T_OUT, y + drop - ov * tan(pitch), -d / 2), false)
		"gable", "hip":
			var span := (z1 - z0) if along_x else (x1 - x0)
			var rh := span * 0.5 * tan(pitch)
			if p.roof.type == "gable":
				if along_x:
					var zm := (z0 + z1) * 0.5
					_roof_quad(g, rmat, Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y + rh, zm), Vector3(x0, y + rh, zm))
					_roof_quad(g, rmat, Vector3(x1, y, z0), Vector3(x0, y, z0), Vector3(x0, y + rh, zm), Vector3(x1, y + rh, zm))
					_gable_end(p, g, "x", -w / 2 - T_OUT, y, rh - ov * tan(pitch), (z0 + ov), (z1 - ov) if p.verandah == null else d / 2 + T_OUT)
					_gable_end(p, g, "x", w / 2, y, rh - ov * tan(pitch), (z0 + ov), (z1 - ov) if p.verandah == null else d / 2 + T_OUT)
				else:
					var xm := (x0 + x1) * 0.5
					_roof_quad(g, rmat, Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(xm, y + rh, z1), Vector3(xm, y + rh, z0))
					_roof_quad(g, rmat, Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(xm, y + rh, z0), Vector3(xm, y + rh, z1))
					_gable_end(p, g, "z", -d / 2 - T_OUT, y, rh - ov * tan(pitch), x0 + ov, x1 - ov)
					_gable_end(p, g, "z", d / 2, y, rh - ov * tan(pitch), x0 + ov, x1 - ov)
				# ridge cap
				if along_x:
					g.aabb(rmat.replace(":uv", ""), Vector3(x0, y + rh - 0.02, (z0 + z1) / 2 - 0.12), Vector3(x1, y + rh + 0.06, (z0 + z1) / 2 + 0.12), false)
				else:
					g.aabb(rmat.replace(":uv", ""), Vector3((x0 + x1) / 2 - 0.12, y + rh - 0.02, z0), Vector3((x0 + x1) / 2 + 0.12, y + rh + 0.06, z1), false)
			else:
				# hip: ridge shortened by half the span at each end
				if along_x:
					var zm := (z0 + z1) * 0.5
					var hs := (z1 - z0) * 0.5
					var ra := Vector3(minf(x0 + hs, (x0 + x1) / 2), y + rh, zm)
					var rb := Vector3(maxf(x1 - hs, (x0 + x1) / 2), y + rh, zm)
					_roof_quad(g, rmat, Vector3(x0, y, z1), Vector3(x1, y, z1), rb, ra)
					_roof_quad(g, rmat, Vector3(x1, y, z0), Vector3(x0, y, z0), ra, rb)
					_roof_tri(g, rmat, Vector3(x0, y, z0), Vector3(x0, y, z1), ra)
					_roof_tri(g, rmat, Vector3(x1, y, z1), Vector3(x1, y, z0), rb)
				else:
					var xm := (x0 + x1) * 0.5
					var hs := (x1 - x0) * 0.5
					var ra := Vector3(xm, y + rh, minf(z0 + hs, (z0 + z1) / 2))
					var rb := Vector3(xm, y + rh, maxf(z1 - hs, (z0 + z1) / 2))
					_roof_quad(g, rmat, Vector3(x0, y, z0), Vector3(x0, y, z1), rb, ra)
					_roof_quad(g, rmat, Vector3(x1, y, z1), Vector3(x1, y, z0), ra, rb)
					_roof_tri(g, rmat, Vector3(x1, y, z0), Vector3(x0, y, z0), ra)
					_roof_tri(g, rmat, Vector3(x0, y, z1), Vector3(x1, y, z1), rb)
	# fascia boards round the eaves
	var fm := str(p.get("fascia", "trim" if p.kind in ["qlder", "cottage", "brick", "two_storey"] else "steel"))
	g.aabb(fm, Vector3(x0, y - 0.18, z0 - 0.03), Vector3(x1, y + 0.02, z0), false)
	g.aabb(fm, Vector3(x0, y - 0.18, z1), Vector3(x1, y + 0.02, z1 + 0.03), false)
	# soffit under the eaves so you don't see into the roof
	g.aabb("trim" if fm.begins_with("trim") else "steel", Vector3(x0, y - 0.02, z0), Vector3(x1, y, z1), false)

## A gable-end triangle of cladding on the wall line (a thin prism)
static func _gable_end(p: Dictionary, g: Geo, axis: String, fixed: float, y: float, rh: float, a: float, b: float) -> void:
	var mid := (a + b) * 0.5
	var pt := func(u: float, yy: float, t: float) -> Vector3:
		return Vector3(fixed + t, yy, u) if axis == "x" else Vector3(u, yy, fixed + t)
	var n := Vector3(1, 0, 0) if axis == "x" else Vector3(0, 0, 1)
	var mk: String = p.clad
	for t in [0.0, T_OUT]:
		var nn := -n if t == 0.0 else n
		var p0: Vector3 = pt.call(a, y - 0.02, t)
		var p1: Vector3 = pt.call(b, y - 0.02, t)
		var p2: Vector3 = pt.call(mid, y + rh, t)
		g.tri(mk, p0, p1, p2, nn, Vector2(a, y), Vector2(b, y), Vector2(mid, y + rh))

## Steps up to the outside doors that aren't on a verandah
static func _ext_steps(p: Dictionary, g: Geo, ground: Callable) -> void:
	for e in p.ext_doors:
		if e.front and p.verandah != null:
			continue
		var r: Dictionary = e.room
		var out := Vector3(0, 0, 1) if e.side == "S" else Vector3(0, 0, -1)
		var zline := float(r.z1) + T_OUT if e.side == "S" else float(r.z0) - T_OUT
		var top := Vector3(float(e.c), 0.0, zline)
		if p.kind == "qlder" or float(ground.call(top.x, top.z + out.z)) < -0.9:
			# a landing then the flight
			g.aabb("deck", Vector3(top.x - 0.8, -0.1, minf(zline, zline + out.z * 1.2)), Vector3(top.x + 0.8, 0.0, maxf(zline, zline + out.z * 1.2)))
			for sx in [-0.72, 0.72]:
				var pz := zline + out.z * 1.12
				var gy: float = ground.call(top.x + sx, pz)
				g.aabb("timber", Vector3(top.x + sx - 0.07, gy - 0.3, pz - 0.07), Vector3(top.x + sx + 0.07, -0.1, pz + 0.07), false)
			top = top + out * 1.2
		_flight(g, top, out, 1.0, ground, "timber" if p.stumps else "concrete")
