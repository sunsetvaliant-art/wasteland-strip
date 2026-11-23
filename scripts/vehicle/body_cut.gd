class_name BodyCut
extends RefCounted
## Cutting a body model into pieces (0.2.55), from lines set once per model in the pause menu's Body tools:
##   tub     a cutting plane (position along the car + tilt) or a seam of clicked points; everything behind it is the
##           tub, in front the cab. A ute can then lose its factory tub for a custom tray, and the tub is a part
##   paint   (0.2.59) or paint it: every triangle of the model brushed as cab, tub or bonnet in Body tools. Painted
##           triangles go where they're painted; anything unpainted falls back to the lines. A painted bonnet's
##           outline, hinge and bay come from the painted triangles; a painted tub's front from its front-most point
##   bonnet  a shut line clicked round the bonnet; the panel comes off it (thickened, with an underside), hinged at the
##           back (or front) to open, and comes off whole for an engine swap. Under it a generic engine bay is drawn,
##           but never outside the bonnet's own outline (the bay's shader throws away anything outside it)
## Lines live in res://assets/vehicles/body_cuts.json (shipped) and user://body_cuts.json (yours, set in game; it
## overrides). Everything is in the car's body frame: x across (+ = the car's left... as Car lays it out), y up,
## z along the car (+ = forward), i.e. the model turned -90 degrees as Car turns it.

const SHIPPED := "res://assets/vehicles/body_cuts.json"
const USER := "user://body_cuts.json"
static var _cuts := {}
static var _loaded := false
static var _cache := {}          # glb + cut -> pieces

static func all() -> Dictionary:
	if not _loaded:
		_loaded = true
		_cuts = {}
		for p in [SHIPPED, USER]:
			if FileAccess.file_exists(p):
				var d = JSON.parse_string(FileAccess.get_file_as_string(p))
				if typeof(d) == TYPE_DICTIONARY:
					for k in d: _cuts[k] = d[k]
	return _cuts

static func of(glb: String) -> Dictionary:
	var c: Dictionary = all().get(glb, {})
	if c.has("paint"): return _derived(glb, c)
	return c

## Has this cut got a bonnet to take off
static func has_bonnet(bon: Dictionary) -> bool:
	return (bon.get("pts", []) as Array).size() >= 3

# ------------------------------------------------------------------------------------------------ painted triangles
const PART := {"cab": 1, "tub": 2, "bonnet": 3}
## The painted labels as a byte per triangle (0 = unpainted), in the order meshes_of / surfaces / triangles
static func labels_of(paint: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(int(paint.get("n", 0)))
	for r in paint.get("runs", []):
		var a := int(r[0]); var n := int(r[1]); var v := int(r[2])
		for i in range(a, mini(a + n, out.size())): out[i] = v
	return out

static func runs_of(labels: PackedByteArray) -> Array:
	var runs: Array = []
	var i := 0
	while i < labels.size():
		var v := labels[i]
		var j := i
		while j < labels.size() and labels[j] == v: j += 1
		if v != 0: runs.append([i, j - i, v])
		i = j
	return runs

static var _derived_cache := {}
## The cut with a painted bonnet's shut line and a painted tub's front worked out from the painted triangles
static var _dref := {}          # 0.2.68: glb -> [the saved entry, what came of it]: no hashing the paint on every call
static func _derived(glb: String, c: Dictionary) -> Dictionary:
	var r = _dref.get(glb)
	if r != null and is_same((r as Array)[0], c): return (r as Array)[1]
	var key := glb + str(hash(JSON.stringify(c)))
	if _derived_cache.has(key):
		_dref[glb] = [c, _derived_cache[key]]
		return _derived_cache[key]
	var out := c.duplicate(true)
	var lab := labels_of(c.paint)
	var bon_pts := PackedVector2Array()
	var bon_y := {}
	var tub_front := -1e9
	var has_tub := false
	var ti := 0
	for m in meshes_of(glb):
		var mesh: Mesh = m.mesh
		var xf: Transform3D = m.xf
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var nt := (I.size() if not I.is_empty() else V.size()) / 3
			for t in nt:
				var v: int = lab[ti] if ti < lab.size() else 0
				ti += 1
				if v != 3 and v != 2: continue
				for k in 3:
					var idx: int = I[t * 3 + k] if not I.is_empty() else t * 3 + k
					var p: Vector3 = xf * V[idx]
					if v == 3:
						var q := Vector2(snappedf(p.x, 0.01), snappedf(p.z, 0.01))
						bon_pts.append(q)
						bon_y[q] = maxf(float(bon_y.get(q, -1e9)), p.y)
					else:
						has_tub = true
						tub_front = maxf(tub_front, p.z)
	if bon_pts.size() >= 3:
		var hull := Geometry2D.convex_hull(bon_pts)
		var pts: Array = []
		for i in hull.size() - 1:
			pts.append([hull[i].x, float(bon_y.get(hull[i], 0.9)), hull[i].y])
		var b: Dictionary = out.get("bonnet", {})
		b["pts"] = pts
		b["from_paint"] = true
		if not b.has("hinge"): b["hinge"] = "rear"
		out["bonnet"] = b
	if has_tub and not out.has("tub"):
		out["tub"] = {"mode": "paint", "front": tub_front}
	if _derived_cache.size() > 32: _derived_cache.clear()
	_derived_cache[key] = out
	_dref[glb] = [c, out]
	return out


static func save(glb: String, entry: Dictionary) -> void:
	all()
	_cuts[glb] = entry
	var mine := {}
	if FileAccess.file_exists(USER):
		var d = JSON.parse_string(FileAccess.get_file_as_string(USER))
		if typeof(d) == TYPE_DICTIONARY: mine = d
	mine[glb] = entry
	var f := FileAccess.open(USER, FileAccess.WRITE)
	f.store_string(JSON.stringify(mine, "\t"))
	f.close()
	_cache.clear()

static func user_file_path() -> String:
	return ProjectSettings.globalize_path(USER)

# ------------------------------------------------------------------------------------------------ the model's meshes
## Every mesh in a body model with its transform into the body frame: [{mesh, xf}]
static func meshes_of(glb: String) -> Array:
	var ps: PackedScene = load("res://assets/vehicles/%s.glb" % glb)
	if ps == null: return []
	var inst := ps.instantiate()
	var out: Array = []
	var turn := Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3.ZERO)
	_collect(inst, turn, out)
	inst.free()
	return out

static func _collect(n: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf := parent_xf
	if n is Node3D: xf = parent_xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append({"mesh": (n as MeshInstance3D).mesh, "xf": xf})
	for c in n.get_children(): _collect(c, xf, out)

## Is a point (body frame) behind the tub cut?
static func behind_tub(tub: Dictionary, p: Vector3) -> bool:
	if str(tub.get("mode", "plane")) == "paint": return false            # painted: the labels say
	if str(tub.get("mode", "plane")) == "points":
		var pts: Array = tub.get("pts", [])         # [[y, z], ...]
		if pts.size() < 2: return false
		var srt := pts.duplicate()
		srt.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		var zc: float = float(srt[0][1])
		if p.y >= float(srt[-1][0]): zc = float(srt[-1][1])
		else:
			for i in srt.size() - 1:
				var a: Array = srt[i]; var b: Array = srt[i + 1]
				if p.y >= float(a[0]) and p.y <= float(b[0]):
					zc = lerpf(float(a[1]), float(b[1]), (p.y - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4))
					break
		return p.z < zc
	var z0 := float(tub.get("z", -0.5))
	var tilt := deg_to_rad(float(tub.get("tilt", 0.0)))
	var y0 := float(tub.get("y", 0.6))
	return p.z < z0 + tan(tilt) * (p.y - y0)

## The front-most point of the tub cut at deck height (where a tray starts)
static func tub_front_z(tub: Dictionary, y: float) -> float:
	if str(tub.get("mode", "plane")) == "paint": return float(tub.get("front", -0.5))
	if str(tub.get("mode", "plane")) == "points":
		var pts: Array = tub.get("pts", [])
		var z := -1e9
		for q in pts: z = maxf(z, float(q[1]))
		return z if z > -1e8 else -0.5
	return float(tub.get("z", -0.5)) + tan(deg_to_rad(float(tub.get("tilt", 0.0)))) * (y - float(tub.get("y", 0.6)))

static func in_poly(poly: PackedVector2Array, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)

static func bonnet_poly(bon: Dictionary) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for q in bon.get("pts", []): poly.append(Vector2(float(q[0]), float(q[2])))
	return poly

static func bonnet_floor(bon: Dictionary) -> float:
	var y := 1e9
	for q in bon.get("pts", []): y = minf(y, float(q[1]))
	return y - 0.06

## Cut a model into pieces: {cab: [meshes], tub: [meshes], bonnet: [meshes], under: [meshes]}; each piece mesh is
## an ArrayMesh in the body frame. Which pieces come back depends on what's set and what's asked for.
static func pieces(glb: String, want_tub: bool, want_bonnet: bool, col := Color(0, 0, 0, 0)) -> Dictionary:
	var cut := of(glb)
	var tub: Dictionary = cut.get("tub", {}) if want_tub else {}
	var bon: Dictionary = cut.get("bonnet", {}) if want_bonnet else {}
	var paint: Dictionary = cut.get("paint", {})
	# 0.2.68: a respray (the faces you marked as paint, in the car's own colour) and parts of your own (labels 4+)
	var respray: bool = col.a > 0.0 and cut.has("respray")
	var rmask := labels_of(cut.respray) if respray else PackedByteArray()
	var off_lv := {}
	var parts: Array = cut.get("parts", [])
	for i in parts.size():
		if bool((parts[i] as Dictionary).get("off", false)): off_lv[4 + i] = true
	var key := glb + JSON.stringify([tub, bon, hash(JSON.stringify(paint)), hash(JSON.stringify(cut.get("respray", {}))) if respray else 0, col.to_html() if respray else "", off_lv.keys()])
	if _cache.has(key): return _cache[key]
	var lab := labels_of(paint) if not paint.is_empty() else PackedByteArray()
	var ti := 0
	var poly_rule := not bon.is_empty() and not bool(bon.get("from_paint", false))
	var poly := bonnet_poly(bon)
	var floor_y := bonnet_floor(bon)
	var out := {"cab": [], "tub": [], "bonnet": [], "under": [], "acc": {}}
	for m in meshes_of(glb):
		var mesh: Mesh = m.mesh
		var xf: Transform3D = m.xf
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var mat: Material = mesh.surface_get_material(si)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if I.is_empty():
				I.resize(V.size())
				for i in V.size(): I[i] = i
			# vertices into the body frame once
			var B := PackedVector3Array(); B.resize(V.size())
			for i in V.size(): B[i] = xf * V[i]
			var cabI := PackedInt32Array(); var tubI := PackedInt32Array(); var bonI := PackedInt32Array()
			# 0.2.68: resprayed faces, and labels 4+ (parts of your own). Plain Arrays: appending through a cast to a
			# PackedInt32Array appends to a copy
			var resI := {"cab": [], "tub": [], "bonnet": []}
			var accI := {}
			for t in range(0, I.size(), 3):
				var lv := lab[ti] if ti < lab.size() else 0
				var rs: bool = respray and ti < rmask.size() and rmask[ti] != 0
				ti += 1
				var dest := "cab"
				if lv >= 4:
					if not accI.has(lv): accI[lv] = []
					(accI[lv] as Array).append_array([I[t], I[t + 1], I[t + 2]])
					if off_lv.has(lv): continue            # taken off this car
				elif lv == 1: dest = "cab"
				elif lv == 2: dest = "tub" if want_tub else "cab"
				elif lv == 3: dest = "bonnet" if want_bonnet else "cab"
				else:
					var a := B[I[t]]; var b := B[I[t + 1]]; var c := B[I[t + 2]]
					var ctr := (a + b + c) / 3.0
					# 0.2.56: everything inside the shut line above the line's lowest point (less a little: the bonnet's front
					# edge curls down past it) is the bonnet, steep bits and all; only faces pointing straight down stay
					var nrm := (b - a).cross(c - a)
					if poly_rule and ctr.y > floor_y - 0.1 and in_poly(poly, Vector2(ctr.x, ctr.z)) and (nrm.length_squared() < 1e-12 or nrm.normalized().y > -0.7):
						dest = "bonnet"
					elif not tub.is_empty() and behind_tub(tub, ctr): dest = "tub"
				if rs: (resI[dest] as Array).append_array([I[t], I[t + 1], I[t + 2]])
				elif dest == "cab": cabI.append_array([I[t], I[t + 1], I[t + 2]])
				elif dest == "tub": tubI.append_array([I[t], I[t + 1], I[t + 2]])
				else: bonI.append_array([I[t], I[t + 1], I[t + 2]])
			var mk := func(idx: PackedInt32Array, verts: PackedVector3Array, m2: Material) -> ArrayMesh:
				if idx.is_empty(): return null
				var a2 := arr.duplicate()
				a2[Mesh.ARRAY_VERTEX] = verts
				if a2[Mesh.ARRAY_NORMAL] != null:
					var N: PackedVector3Array = a2[Mesh.ARRAY_NORMAL]
					var N2 := PackedVector3Array(); N2.resize(N.size())
					for i in N.size(): N2[i] = (xf.basis * N[i]).normalized()
					a2[Mesh.ARRAY_NORMAL] = N2
				a2[Mesh.ARRAY_TANGENT] = null
				a2[Mesh.ARRAY_INDEX] = idx
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
				am.surface_set_material(0, m2)
				# 0.2.67: the piece keeps the whole model's vertex list, so its own bounds come from the faces it uses
				# (a tub's box was the size of the whole car: the cab's collision shoved it up)
				var lo := Vector3(1e9, 1e9, 1e9); var hi := -lo
				for vi in idx:
					lo = lo.min(verts[vi]); hi = hi.max(verts[vi])
				am.custom_aabb = AABB(lo, hi - lo)
				return am
			for pair in [["cab", cabI], ["tub", tubI], ["bonnet", bonI]]:
				var am = mk.call(pair[1], B, mat)
				if am != null: out[pair[0]].append(am)
				if respray:
					var am_r = mk.call(PackedInt32Array(resI[pair[0]]), B, respray_mat(mat, col))
					if am_r != null: out[pair[0]].append(am_r)
			for lv in accI:
				var am_a = mk.call(PackedInt32Array(accI[lv]), B, mat)
				if am_a != null:
					if not out.acc.has(lv): out.acc[lv] = []
					(out.acc[lv] as Array).append(am_a)
			# the bonnet's underside: the same panel 12 mm down, turned over, in a dull primer
			if not bonI.is_empty():
				var U := PackedVector3Array(); U.resize(B.size())
				for i in B.size(): U[i] = B[i] - Vector3(0, 0.012, 0)
				var ui := PackedInt32Array(); ui.resize(bonI.size())
				for t in range(0, bonI.size(), 3):
					ui[t] = bonI[t]; ui[t + 1] = bonI[t + 2]; ui[t + 2] = bonI[t + 1]
				var ua := []; ua.resize(Mesh.ARRAY_MAX)
				ua[Mesh.ARRAY_VERTEX] = U; ua[Mesh.ARRAY_INDEX] = ui
				var am2 := ArrayMesh.new()
				am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ua)
				var st := SurfaceTool.new(); st.create_from(am2, 0); st.generate_normals()
				var am3 := st.commit()
				am3.surface_set_material(0, EngineKit.mat("black"))
				out.under.append(am3)
	if _cache.size() > 24: _cache.clear()
	_cache[key] = out
	return out

# ------------------------------------------------------------------------------------------------ respray (0.2.68)
const RESPRAY_SHADER := """
shader_type spatial;
uniform vec4 col : source_color = vec4(0.6, 0.1, 0.1, 1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_tex = false;
uniform float avg = 0.5;        // the old paint's average brightness: its shading and grime come across, its colour doesn't
uniform float keep = 0.8;
uniform float gloss = 0.35;
void fragment() {
	float l = avg;
	if (has_tex) { vec3 t = texture(tex, UV).rgb; l = dot(t, vec3(0.299, 0.587, 0.114)); }
	float k = mix(1.0, clamp(l / max(avg, 0.04), 0.15, 1.6), keep);
	ALBEDO = col.rgb * k;
	ROUGHNESS = gloss;
	METALLIC = 0.2;
	SPECULAR = 0.55;
}
"""
static var _respray_shader: Shader
static var _respray_cache := {}
static var _avg_cache := {}
## The material for faces in a new colour: the old texture's light and shade, the new colour
static func respray_mat(orig: Material, col: Color) -> Material:
	var key := str(orig.get_instance_id() if orig else 0) + col.to_html()
	if _respray_cache.has(key): return _respray_cache[key]
	if _respray_shader == null:
		_respray_shader = Shader.new()
		_respray_shader.code = RESPRAY_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = _respray_shader
	sm.set_shader_parameter("col", col)
	var tex: Texture2D = null
	if orig is BaseMaterial3D: tex = (orig as BaseMaterial3D).albedo_texture
	if tex:
		sm.set_shader_parameter("tex", tex)
		sm.set_shader_parameter("has_tex", true)
		var tid := tex.get_instance_id()
		if not _avg_cache.has(tid):
			var a := 0.5
			var img := tex.get_image()
			if img:
				if img.is_compressed(): img.decompress()
				img.resize(24, 24, Image.INTERPOLATE_BILINEAR)
				var sum := 0.0
				for y in 24:
					for x in 24: sum += img.get_pixel(x, y).get_luminance()
				a = sum / 576.0
			_avg_cache[tid] = a
		sm.set_shader_parameter("avg", float(_avg_cache[tid]))
	if _respray_cache.size() > 64: _respray_cache.clear()
	_respray_cache[key] = sm
	return sm

## Your own parts (0.2.68): every model's named parts as [{glb, label, name}], for the Forge and the world
static func custom_parts() -> Array:
	var out: Array = []
	for g in all():
		var parts: Array = (all()[g] as Dictionary).get("parts", [])
		for i in parts.size():
			out.append({"glb": str(g), "label": 4 + i, "name": str((parts[i] as Dictionary).get("name", "Part %d" % (i + 1)))})
	return out

## A part of your own (or a cut cab / tub) as a loose thing in the world: its faces, a box round them, physgun group
static func part_body(glb: String, what: String, label := 0) -> RigidBody3D:
	var cut := of(glb)
	var meshes: Array = []
	if what == "acc":
		meshes = pieces(glb, false, false).acc.get(label, [])
	elif what == "tub":
		if not cut.has("tub"): return null
		meshes = pieces(glb, true, false).tub
	elif what == "cab":
		var pc := pieces(glb, cut.has("tub"), false)
		meshes = pc.cab
	if meshes.is_empty(): return null
	var rb := RigidBody3D.new()
	rb.add_to_group("physgun")
	var aabb := AABB(); var first := true
	for am in meshes:
		var mi := MeshInstance3D.new(); mi.mesh = am
		rb.add_child(mi)
		aabb = aabb_of(am) if first else aabb.merge(aabb_of(am))
		first = false
	var kind := ""
	for k in Car.catalog():
		if str(Car.catalog()[k].glb) == glb: kind = k
	if what != "acc" and kind != "":
		# a cut cab or tub sits on its mounts like one unbolted from a car, so it bolts onto a chassis
		var dd := VehicleSpecs.default_design(kind)
		loose_shapes(rb, aabb, float(dd.ride), float(dd.cab_offset[1]), float(dd.frame.width), what == "cab")
	else:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new(); bx.size = aabb.size.max(Vector3(0.06, 0.06, 0.06))
		cs.shape = bx; cs.position = aabb.get_center()
		rb.add_child(cs)
	var sz := aabb.size.max(Vector3(0.06, 0.06, 0.06))
	rb.mass = clampf(sz.x * sz.y * sz.z * 60.0, 4.0, 400.0)
	if what == "tub":
		rb.set_meta("tub_of", glb); rb.mass = 110.0
		rb.set_meta("forge_name", "Tub")
	elif what == "cab" and kind != "":
		rb.add_to_group("loose_bodies")
		rb.set_meta("body_of", kind)
		rb.set_meta("body_state", {"tub": "none"} if cut.has("tub") else {})
		rb.mass = clampf(float(Car.catalog()[kind].get("kg", 600)) * 0.25, 120.0, 600.0)
		rb.set_meta("forge_name", str(Car.catalog()[kind].name) + " cab")
	return rb

## Collision for a loose body or tub: a box from just above the rails (it sits on four mount pads, 12 cm up, so forks
## can slide in between) to its waist, its roof for a cab, and four pads over the rails. aabb in body space;
## y0 = cab offset height
static func loose_shapes(rb: RigidBody3D, aabb: AABB, ride: float, y0: float, frame_w: float, roofed := true) -> void:
	var rail_top := ride + 0.18 - y0
	var bot := maxf(aabb.position.y, rail_top + 0.12)
	var top := maxf(bot + 0.2, aabb.position.y + aabb.size.y * 0.6)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new(); bx.size = Vector3(maxf(aabb.size.x * 0.95, 0.4), top - bot, maxf(aabb.size.z * 0.97, 0.4))
	cs.shape = bx; cs.position = Vector3(aabb.get_center().x, (bot + top) * 0.5, aabb.get_center().z)
	rb.add_child(cs)
	if roofed and aabb.size.y > 0.9:           # a cab: its roof too
		var rs := CollisionShape3D.new()
		var rbx := BoxShape3D.new(); rbx.size = Vector3(aabb.size.x * 0.8, aabb.end.y - top, aabb.size.z * 0.45)
		rs.shape = rbx; rs.position = Vector3(aabb.get_center().x, (top + aabb.end.y) * 0.5, aabb.get_center().z)
		rb.add_child(rs)
	var hw := frame_w * 0.5
	for zf in [0.18, 0.82]:
		for sx in [-1.0, 1.0]:
			var ps := CollisionShape3D.new()
			var pb := BoxShape3D.new(); pb.size = Vector3(0.08, bot - rail_top, 0.08)
			ps.shape = pb
			ps.position = Vector3(sx * hw, (rail_top + bot) * 0.5, aabb.position.z + aabb.size.z * zf)
			rb.add_child(ps)

## A piece's real bounds (pieces carry the whole model's vertices; custom_aabb holds the faces' own box)
static func aabb_of(m: Mesh) -> AABB:
	if m is ArrayMesh and (m as ArrayMesh).custom_aabb.size != Vector3.ZERO: return (m as ArrayMesh).custom_aabb
	return m.get_aabb()

## The hinge for the bonnet: [pivot (body frame), axis] from the shut line; rear-hinged opens at the front
static func hinge(bon: Dictionary) -> Array:
	var pts: Array = bon.get("pts", [])
	var front := str(bon.get("hinge", "rear")) == "front"
	var zz := -1e9 if front else 1e9
	var yy := -1e9
	for q in pts:
		if front: zz = maxf(zz, float(q[2]))
		else: zz = minf(zz, float(q[2]))
	for q in pts:
		if absf(float(q[2]) - zz) < 0.25: yy = maxf(yy, float(q[1]))
	if yy < -1e8: yy = 0.9
	return [Vector3(0, yy, zz), Vector3.RIGHT]

## 0.2.65: per body, from tools/bonnet_tops.py: a 5 cm grid of the skin's height over the front of the car (body
## frame) and its paint colour
static var _info: Dictionary = {}
static func info(glb: String) -> Dictionary:
	if _info.is_empty():
		var t := FileAccess.get_file_as_string("res://assets/vehicles/body_info.json")
		var d = JSON.parse_string(t) if t != "" else null
		_info = d if d is Dictionary else {"_": {}}
	return _info.get(glb, {})

## 0.2.68: the engine bay's length along the car (body frame) from the skin: [firewall z, front z], or [] if unknown.
## Down the middle, from the nose back, the skin stays near bonnet height until the windscreen climbs away; the
## firewall's just ahead of the windscreen's foot
static var _bay_span := {}
static func bay_span(glb: String) -> Array:
	if _bay_span.has(glb): return _bay_span[glb]
	var d := info(glb)
	var out: Array = []
	if not d.is_empty():
		var c := float(d.cell); var nx := int(d.nx); var nz := int(d.nz)
		var h: Array = d.h
		var rows := []                       # [z, middle height] from the front back
		for iz in range(nz - 1, -1, -1):
			var vals := []
			for ix in range(nx):
				var x := float(d.x0) + (ix + 0.5) * c
				if absf(x) > 0.3: continue
				var v := float(h[iz * nx + ix])
				if v > -50.0: vals.append(v)
			if vals.size() < 3: continue
			vals.sort()
			rows.append([float(d.z0) + (iz + 0.5) * c, float(vals[vals.size() / 2])])
		if rows.size() >= 6:
			var front: float = float(rows[0][0])
			var bh := []
			for r in rows:
				if float(r[0]) < front - 0.15 and float(r[0]) > front - 0.6: bh.append(float(r[1]))
			bh.sort()
			var bon_h: float = float(bh[bh.size() / 2]) if not bh.is_empty() else float(rows[2][1])
			var fw := INF
			for r in rows:
				if float(r[0]) < front - 0.4 and float(r[1]) > bon_h + 0.14:
					fw = float(r[0]) - 0.04
					break
			if fw < INF: out = [fw, front]
	_bay_span[glb] = out
	return out

## The lowest the skin gets over a box of the car (body frame x0..x1, z0..z1): where the bonnet would hit an engine
static func skin_low(glb: String, x0: float, x1: float, z0: float, z1: float) -> float:
	var d := info(glb)
	if d.is_empty(): return INF
	var c := float(d.cell); var nx := int(d.nx); var nz := int(d.nz)
	var h: Array = d.h
	var lo := INF
	for iz in range(maxi(0, int((z0 - float(d.z0)) / c)), mini(nz, int((z1 - float(d.z0)) / c) + 1)):
		for ix in range(maxi(0, int((x0 - float(d.x0)) / c)), mini(nx, int((x1 - float(d.x0)) / c) + 1)):
			var v := float(h[iz * nx + ix])
			if v > -50.0: lo = minf(lo, v)
	return lo

static func paint_of(glb: String) -> Color:
	var p = info(glb).get("paint")
	if p is Array and p.size() >= 3: return Color(float(p[0]), float(p[1]), float(p[2]))
	return Color(0.07, 0.07, 0.075)

## The engine bay under the bonnet: walls down from the shut line, leaning in a little as they go down, drawn
## with a shader that discards anything outside the bonnet's outline seen from above
static var _bay_shader: Shader
static func bay_node(bon: Dictionary, bottom_y: float, col := Color(0.07, 0.07, 0.075)) -> MeshInstance3D:
	var poly := bonnet_poly(bon)
	if poly.size() < 3: return null
	var top := bonnet_floor(bon) + 0.03
	var c := Vector2.ZERO
	for p in poly: c += p
	c /= poly.size()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in poly.size():
		var a := poly[i]; var b := poly[(i + 1) % poly.size()]
		var a2 := a.lerp(c, 0.14); var b2 := b.lerp(c, 0.14)
		var q: Array[Vector3] = [Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b2.x, bottom_y, b2.y), Vector3(a2.x, bottom_y, a2.y)]
		var nrm := ((q[1] - q[0]).cross(q[3] - q[0])).normalized()
		for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.set_normal(nrm); st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.name = "EngineBay"
	if _bay_shader == null:
		_bay_shader = Shader.new()
		_bay_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec2 poly[24];
uniform int n = 0;
uniform vec4 col : source_color = vec4(0.07, 0.07, 0.075, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
bool inside(vec2 p) {
	bool c = false;
	for (int i = 0, j = n - 1; i < n; j = i++) {
		vec2 a = poly[i]; vec2 b = poly[j];
		if (((a.y > p.y) != (b.y > p.y)) && (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)) c = !c;
	}
	return c;
}
void fragment() {
	if (!inside(lp.xz)) discard;
	ALBEDO = col.rgb; ROUGHNESS = 0.55; METALLIC = 0.2;
}"""
	var sm := ShaderMaterial.new()
	sm.shader = _bay_shader
	var arr := PackedVector2Array()
	for i in mini(poly.size(), 24): arr.append(poly[i].lerp(c, -0.01))
	sm.set_shader_parameter("poly", arr)
	sm.set_shader_parameter("n", arr.size())
	sm.set_shader_parameter("col", col)         # 0.2.65: the body's own paint (sheet metal), a shade darker
	mi.material_override = sm
	return mi
