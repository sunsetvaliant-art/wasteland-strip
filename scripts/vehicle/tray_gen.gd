class_name TrayGen
extends RefCounted
## Custom trays, made in code to fit the chassis behind a cab whose tub has come off (0.2.55). Aussie tray builds:
##   type      steel (painted, timber deck) or alloy (bare, checker plate)
##   size      fills the chassis behind the cab by default; length and width adjustable
##   headboard with a ladder rack over the cab
##   sides     drop sides that hinge down (and back up)
##   boxes     under-tray toolboxes, a double tapered toolbox, or a marine-carpet-lined gullwing box on the deck
##   extras    spare wheel carrier, water tank, jerry can holders, a box canopy with lift-up doors
##   lights    plain round, square LED bars, sequential indicators, recessed in the rear bar
## A tray config is a plain Dictionary (design.tray) so it saves and travels with the car.

const DEFAULT := {"type": "alloy", "len": 0.0, "wid": 0.0, "head": true, "rack": true, "sides": true, "boxes": "under",
	"spare": true, "tank": false, "jerry": false, "canopy": false, "lights": "led", "carpet": true}
const BOXES := ["none", "under", "tapered", "gullwing"]
const LIGHTS := ["round", "led", "seq", "recessed"]

static func item_def(id: String) -> Dictionary:
	if id.begins_with("tub_"): return {"name": "Ute tub (%s)" % id.trim_prefix("tub_"), "w": 6, "h": 4, "stack": 1, "kind": "misc", "part": "tub"}
	return {}

static func cfg_of(design: Dictionary) -> Dictionary:
	var c: Dictionary = DEFAULT.duplicate(true)
	var t = design.get("tray", {})
	if t is Dictionary:
		for k in t: c[k] = t[k]
	return c

static var _mats := {}
static func m(key: String) -> StandardMaterial3D:
	if _mats.has(key): return _mats[key]
	var mt := StandardMaterial3D.new()
	var spec: Array = {"alloy": [Color(0.8, 0.81, 0.82), 0.35, 0.42], "steel": [Color(0.1, 0.1, 0.1), 0.2, 0.55], "timber": [Color(0.42, 0.3, 0.2), 0.0, 0.85],
		"black": [Color(0.05, 0.05, 0.05), 0.2, 0.6], "carpet": [Color(0.2, 0.22, 0.25), 0.0, 1.0], "rubber": [Color(0.03, 0.03, 0.03), 0.0, 0.9],
		"tank": [Color(0.12, 0.12, 0.12), 0.0, 0.7], "jerry": [Color(0.15, 0.3, 0.15), 0.2, 0.5], "rim": [Color(0.55, 0.55, 0.55), 0.7, 0.4],
		"red": [Color(0.5, 0.02, 0.02), 0.0, 0.3], "amber": [Color(0.6, 0.3, 0.0), 0.0, 0.3], "lens": [Color(0.9, 0.9, 0.9), 0.0, 0.2]}.get(key, [Color(0.5, 0.5, 0.5), 0.3, 0.5])
	mt.albedo_color = spec[0]; mt.metallic = spec[1]; mt.roughness = spec[2]
	if key == "alloy":
		mt.albedo_texture = _checker()
		mt.uv1_triplanar = true; mt.uv1_world_triplanar = false; mt.uv1_scale = Vector3.ONE * 6.0
	if key in ["red", "amber"]:
		mt.emission_enabled = true; mt.emission = spec[0]; mt.emission_energy_multiplier = 0.0
	_mats[key] = mt
	return mt

## A little checker-plate texture made once
static var _chk: ImageTexture
static func _checker() -> ImageTexture:
	if _chk != null: return _chk
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var v := 0.72
			for cc: Vector2 in [Vector2(16, 16), Vector2(48, 48)]:
				var d := Vector2(x, y) - cc
				var r := d.rotated(PI / 4 if cc.x < 32 else -PI / 4)
				if absf(r.x) < 9.0 and absf(r.y) < 2.5: v = 0.88
			img.set_pixel(x, y, Color(v, v, v * 1.01))
	img.generate_mipmaps()
	_chk = ImageTexture.create_from_image(img)
	return _chk

## Build a tray on a car: deck front at z_front (just behind the cab), deck top at y_deck, the frame's back end at
## z_frame_end. Returns {node, shapes: [[Transform3D, Vector3 size]], sides: [pivot nodes], doors: [pivot nodes],
## lights: {brake: [mats], seq: [mesh instances]}}
static func build(cfg: Dictionary, z_front: float, y_deck: float, z_frame_end: float, body_w: float, cab_top: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "Tray"
	var L: float = float(cfg.len) if float(cfg.len) > 0.5 else clampf(z_front - z_frame_end + 0.3, 1.5, 2.6)
	var W: float = float(cfg.wid) if float(cfg.wid) > 0.5 else clampf(body_w + 0.06, 1.6, 2.0)
	var alloy: bool = str(cfg.type) == "alloy"
	var mat_main := "alloy" if alloy else "steel"
	var zb := z_front - L
	var zc := (z_front + zb) * 0.5
	var out := {"node": root, "shapes": [], "sides": [], "doors": [], "brake": [], "seq": []}
	var add := func(mt: String, size: Vector3, at: Vector3, parent: Node3D = null, basis := Basis.IDENTITY) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = size
		mi.mesh = bm; mi.material_override = m(mt)
		mi.transform = Transform3D(basis, at)
		(parent if parent != null else root).add_child(mi)
		return mi
	# bearers and crossmembers under the deck
	for s: float in [-1.0, 1.0]: add.call("black", Vector3(0.08, 0.1, L), Vector3(s * 0.45, y_deck - 0.08, zc))
	var nx := int(L / 0.45)
	for i in nx + 1: add.call("black", Vector3(W - 0.02, 0.06, 0.05), Vector3(0, y_deck - 0.06, zb + 0.05 + i * (L - 0.1) / nx))
	# the deck
	if alloy:
		add.call("alloy", Vector3(W, 0.025, L), Vector3(0, y_deck - 0.012, zc))
	else:
		var np := int(W / 0.14)
		for i in np: add.call("timber", Vector3(W / np - 0.008, 0.03, L), Vector3(-W * 0.5 + (i + 0.5) * W / np, y_deck - 0.015, zc))
	out.shapes.append([Transform3D(Basis.IDENTITY, Vector3(0, y_deck - 0.03, zc)), Vector3(W, 0.06, L)])
	# rear bar with the lights
	add.call(mat_main, Vector3(W, 0.14, 0.08), Vector3(0, y_deck - 0.09, zb - 0.02))
	_lights(cfg, root, W, y_deck - 0.09, zb - 0.065, out)
	# headboard and ladder rack
	if cfg.head:
		var hh := 0.85
		for s: float in [-1.0, 1.0]: add.call(mat_main, Vector3(0.05, hh, 0.05), Vector3(s * (W * 0.5 - 0.03), y_deck + hh * 0.5, z_front - 0.03))
		add.call(mat_main, Vector3(W, 0.05, 0.05), Vector3(0, y_deck + hh, z_front - 0.03))
		for i in 7: add.call(mat_main, Vector3(0.025, hh - 0.05, 0.025), Vector3(-W * 0.4 + i * W * 0.8 / 6.0, y_deck + hh * 0.5, z_front - 0.03))
		out.shapes.append([Transform3D(Basis.IDENTITY, Vector3(0, y_deck + hh * 0.5, z_front - 0.03)), Vector3(W, hh, 0.06)])
		if cfg.rack:
			var ry := maxf(cab_top + 0.12, y_deck + hh + 0.05)
			for s: float in [-1.0, 1.0]:
				add.call(mat_main, Vector3(0.045, ry - y_deck - hh, 0.045), Vector3(s * (W * 0.5 - 0.03), (ry + y_deck + hh) * 0.5, z_front - 0.03))
				add.call(mat_main, Vector3(0.045, 0.045, 1.1), Vector3(s * (W * 0.5 - 0.03), ry, z_front + 0.5))
			for zz in [z_front - 0.03, z_front + 1.02]: add.call(mat_main, Vector3(W, 0.045, 0.045), Vector3(0, ry, zz))
	# drop sides: hinged along the bottom edge
	var zf_side := z_front - (0.05 if cfg.head else 0.0)
	if cfg.sides:
		var sh := 0.3
		var sides := [[Vector3(-W * 0.5, y_deck, zc), Vector3(0, 0, 1), L, -1.0], [Vector3(W * 0.5, y_deck, zc), Vector3(0, 0, 1), L, 1.0], [Vector3(0, y_deck, zb), Vector3(1, 0, 0), W, 0.0]]
		for sd in sides:
			var piv := Node3D.new()
			piv.position = sd[0]
			piv.set_meta("hinge_axis", Vector3(0, 0, 1) if sd[3] != 0.0 else Vector3(1, 0, 0))
			piv.set_meta("drop_sign", -float(sd[3]) if sd[3] != 0.0 else -1.0)
			root.add_child(piv)
			var len: float = sd[2] - (0.08 if sd[3] == 0.0 else 0.06)
			var size := Vector3(0.03, sh, len) if sd[3] != 0.0 else Vector3(len, sh, 0.03)
			add.call(mat_main, size, Vector3(0, sh * 0.5, 0), piv)
			add.call(mat_main, Vector3(size.x + 0.01, 0.03, size.z + 0.01), Vector3(0, sh, 0), piv)
			out.sides.append(piv)
	# boxes
	match str(cfg.boxes):
		"under":
			for s: float in [-1.0, 1.0]:
				add.call(mat_main, Vector3(0.42, 0.42, 0.9), Vector3(s * (W * 0.5 - 0.22), y_deck - 0.3, z_front - 0.55))
				add.call("black", Vector3(0.02, 0.04, 0.12), Vector3(s * (W * 0.5 - 0.005), y_deck - 0.2, z_front - 0.55))
		"tapered":
			for s: float in [-1.0, 1.0]:
				var tb := _tapered(m(mat_main), 0.5, 0.48, 0.26, 1.0)
				tb.position = Vector3(s * (W * 0.5 - 0.25), y_deck - 0.07, z_front - 0.6)
				if s < 0: tb.rotation.y = PI
				root.add_child(tb)
		"gullwing":
			var gd := 0.75; var gh := 0.72
			add.call(mat_main, Vector3(W, gh, 0.03), Vector3(0, y_deck + gh * 0.5, zf_side - gd))
			add.call(mat_main, Vector3(W, 0.03, gd), Vector3(0, y_deck + gh, zf_side - gd * 0.5))
			if cfg.carpet: add.call("carpet", Vector3(W - 0.08, 0.01, gd - 0.06), Vector3(0, y_deck + 0.01, zf_side - gd * 0.5))
			for s: float in [-1.0, 1.0]:
				var piv := Node3D.new()
				piv.position = Vector3(s * W * 0.5, y_deck + gh, zf_side - gd * 0.5)
				piv.set_meta("hinge_axis", Vector3(0, 0, 1))
				piv.set_meta("drop_sign", s * 1.0)
				root.add_child(piv)
				add.call(mat_main, Vector3(0.025, gh, gd), Vector3(0, -gh * 0.5, 0), piv)
				add.call("black", Vector3(0.02, 0.03, 0.14), Vector3(s * 0.015, -gh * 0.8, 0), piv)
				out.doors.append(piv)
			out.shapes.append([Transform3D(Basis.IDENTITY, Vector3(0, y_deck + gh * 0.5, zf_side - gd * 0.5)), Vector3(W, gh, gd)])
	# spare wheel under the back of the tray
	if cfg.spare:
		var sp := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.37; cm.bottom_radius = 0.37; cm.height = 0.24; cm.radial_segments = 20
		sp.mesh = cm; sp.material_override = m("rubber")
		sp.position = Vector3(0, y_deck - 0.3, zb + 0.5)
		root.add_child(sp)
		var rim := MeshInstance3D.new()
		var rm := CylinderMesh.new(); rm.top_radius = 0.22; rm.bottom_radius = 0.22; rm.height = 0.25; rm.radial_segments = 16
		rim.mesh = rm; rim.material_override = m("rim")
		rim.position = sp.position
		root.add_child(rim)
	if cfg.tank:
		add.call("tank", Vector3(0.62, 0.3, 0.55), Vector3(0, y_deck - 0.28, zb + (1.15 if cfg.spare else 0.45)))
	if cfg.jerry:
		for s: float in [-1.0, 1.0]:
			add.call("black", Vector3(0.2, 0.48, 0.38), Vector3(s * (W * 0.5 - 0.11), y_deck + 0.26, zb + 0.24))
			add.call("jerry", Vector3(0.16, 0.45, 0.34), Vector3(s * (W * 0.5 - 0.11), y_deck + 0.25, zb + 0.24))
	# box canopy with lift-up doors each side
	if cfg.canopy:
		var cz0 := zf_side - (0.78 if str(cfg.boxes) == "gullwing" else 0.0)
		var cl := cz0 - zb - 0.05
		var ch := 0.85
		var ccz := cz0 - cl * 0.5
		add.call(mat_main, Vector3(W, 0.03, cl), Vector3(0, y_deck + ch, ccz))
		add.call(mat_main, Vector3(W, ch, 0.03), Vector3(0, y_deck + ch * 0.5, cz0))
		add.call(mat_main, Vector3(W, ch * 0.3, 0.03), Vector3(0, y_deck + ch * 0.85, zb + 0.04))
		for s: float in [-1.0, 1.0]:
			var piv := Node3D.new()
			piv.position = Vector3(s * W * 0.5, y_deck + ch, ccz)
			piv.set_meta("hinge_axis", Vector3(0, 0, 1))
			piv.set_meta("drop_sign", s * 1.0)
			root.add_child(piv)
			add.call(mat_main, Vector3(0.025, ch - 0.02, cl - 0.04), Vector3(0, -ch * 0.5, 0), piv)
			add.call("black", Vector3(0.02, 0.03, 0.18), Vector3(s * 0.016, -ch * 0.85, 0), piv)
			out.doors.append(piv)
		out.shapes.append([Transform3D(Basis.IDENTITY, Vector3(0, y_deck + ch + 0.015, ccz)), Vector3(W, 0.04, cl)])
	return out

static func _tapered(mt: Material, w_top: float, h: float, w_bot: float, len: float) -> MeshInstance3D:
	## a double-tapered toolbox: full width at the top, tapering in underneath (seen from behind, a trapezoid)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := len * 0.5
	var p := [Vector3(-w_top * 0.5, 0, 0), Vector3(w_top * 0.5, 0, 0), Vector3(w_top * 0.5 - (w_top - w_bot), -h, 0), Vector3(-w_top * 0.5, -h, 0)]
	var front := []; var back := []
	for q in p:
		front.append(q + Vector3(0, 0, hz)); back.append(q - Vector3(0, 0, hz))
	var quads := [[front[0], front[1], front[2], front[3]], [back[1], back[0], back[3], back[2]]]
	for i in 4: quads.append([back[i], back[(i + 1) % 4], front[(i + 1) % 4], front[i]])
	for qd in quads:
		var n: Vector3 = ((qd[1] - qd[0]).cross(qd[3] - qd[0])).normalized()
		for v in [qd[0], qd[1], qd[2], qd[0], qd[2], qd[3]]:
			st.set_normal(n); st.add_vertex(v)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mt
	return mi

static func _lights(cfg: Dictionary, root: Node3D, W: float, y: float, z: float, out: Dictionary) -> void:
	var kind := str(cfg.lights)
	for s: float in [-1.0, 1.0]:
		var x := s * (W * 0.5 - 0.16)
		match kind:
			"round":
				for i in 2:
					var mi := MeshInstance3D.new()
					var cm := CylinderMesh.new(); cm.top_radius = 0.045; cm.bottom_radius = 0.045; cm.height = 0.03; cm.radial_segments = 14
					mi.mesh = cm
					var lm: StandardMaterial3D = m("red").duplicate() if i == 0 else m("amber").duplicate()
					mi.material_override = lm
					mi.rotation.x = PI * 0.5
					mi.position = Vector3(x + s * (-0.06 + i * 0.12), y, z)
					root.add_child(mi)
					if i == 0: out.brake.append(lm)
			"led", "seq", "recessed":
				var segs := 5 if kind == "seq" else 1
				for i in segs:
					var mi := MeshInstance3D.new()
					var bm := BoxMesh.new()
					bm.size = Vector3(0.24 / segs - 0.004, 0.06, 0.02 if kind != "recessed" else 0.01)
					mi.mesh = bm
					var lm: StandardMaterial3D = m("red" if kind != "seq" else ("amber" if i > 1 else "red")).duplicate()
					mi.material_override = lm
					mi.position = Vector3(x + s * (-0.12 + (i + 0.5) * 0.24 / segs), y, z + (0.025 if kind == "recessed" else 0.0))
					root.add_child(mi)
					if kind == "seq" and i > 1: out.seq.append([lm, i - 2, s])
					else: out.brake.append(lm)
