class_name ToolModels
## Made-in-code models (0.2.68) for the items that had no model on the ground (they were plain packets): at real
## size, out of a few primitives each. make(id) returns null for anything it doesn't know.

static var _mats := {}

static func _m(col: Color, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var key := col.to_html() + str(metal) + str(rough)
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	_mats[key] = m
	return m

static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size; bm.material = mat
	mi.mesh = bm; mi.position = pos; mi.rotation = rot
	root.add_child(mi)

static func _cyl(root: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, r2 := -1.0, seg := 12) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r if r2 < 0.0 else r2; cm.height = h; cm.radial_segments = seg; cm.rings = 1
	cm.material = mat
	mi.mesh = cm; mi.position = pos; mi.rotation = rot
	root.add_child(mi)

static func _torus(root: Node3D, r_in: float, r_out: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = r_in; tm.outer_radius = r_out; tm.rings = 16; tm.ring_segments = 8
	tm.material = mat
	mi.mesh = tm; mi.position = pos; mi.rotation = rot
	root.add_child(mi)

static func make(id: String) -> Node3D:
	var r := Node3D.new()
	var steel := _m(Color(0.55, 0.56, 0.58), 0.9, 0.35)
	var black := _m(Color(0.06, 0.06, 0.07), 0.0, 0.6)
	var wood := _m(Color(0.55, 0.38, 0.2), 0.0, 0.8)
	match id:
		"strap_250", "strap_2t":
			var col: Color = Strap.KINDS[id].col if Strap.KINDS.has(id) else Color(1, 0.5, 0.1)
			var big := id == "strap_2t"
			_cyl(r, 0.05 if big else 0.035, 0.05 if big else 0.025, Vector3.ZERO, _m(col, 0.0, 0.85), Vector3(PI / 2, 0, 0), -1.0, 16)
			_box(r, Vector3(0.09 if big else 0.06, 0.03, 0.05 if big else 0.03), Vector3(0, 0.05 if big else 0.035, 0), steel)     # the ratchet
			_box(r, Vector3(0.012, 0.012, 0.08), Vector3(0.05, -0.03, 0), steel)                                                  # the hook
		"knife":
			_box(r, Vector3(0.018, 0.022, 0.11), Vector3(0, 0, -0.055), black)
			_box(r, Vector3(0.004, 0.026, 0.13), Vector3(0, 0.002, 0.065), steel)
		"tyre_iron":
			_cyl(r, 0.009, 0.5, Vector3.ZERO, steel, Vector3(PI / 2, 0, 0))
			_cyl(r, 0.012, 0.06, Vector3(0, 0.02, 0.25), steel, Vector3(0.6, 0, 0), 0.016)
		"bat":
			_box(r, Vector3(0.105, 0.03, 0.55), Vector3(0, 0, 0.15), _m(Color(0.86, 0.78, 0.6), 0.0, 0.7))
			_cyl(r, 0.016, 0.3, Vector3(0, 0, -0.27), black, Vector3(PI / 2, 0, 0))
		"car_battery":
			_box(r, Vector3(0.26, 0.2, 0.17), Vector3.ZERO, black)
			_box(r, Vector3(0.25, 0.012, 0.16), Vector3(0, 0.106, 0), _m(Color(0.15, 0.15, 0.17)))
			_cyl(r, 0.012, 0.025, Vector3(0.09, 0.12, 0.05), _m(Color(0.7, 0.1, 0.1), 0.3, 0.5))
			_cyl(r, 0.012, 0.025, Vector3(-0.09, 0.12, 0.05), _m(Color(0.6, 0.6, 0.62), 0.5, 0.5))
		"wire":
			_torus(r, 0.07, 0.085, Vector3.ZERO, _m(Color(0.72, 0.42, 0.2), 0.8, 0.35))
		"rope":
			_torus(r, 0.09, 0.13, Vector3.ZERO, _m(Color(0.75, 0.65, 0.45), 0.0, 0.95))
		"lighter":
			_box(r, Vector3(0.025, 0.08, 0.012), Vector3.ZERO, _m(Color(0.8, 0.15, 0.1), 0.0, 0.4))
			_box(r, Vector3(0.022, 0.015, 0.011), Vector3(0, 0.047, 0), steel)
		"flint":
			_box(r, Vector3(0.06, 0.012, 0.012), Vector3.ZERO, _m(Color(0.25, 0.25, 0.27), 0.2, 0.8))
			_box(r, Vector3(0.07, 0.006, 0.025), Vector3(0, 0, 0.03), steel)
		"car_key":
			_box(r, Vector3(0.03, 0.006, 0.03), Vector3.ZERO, black)
			_box(r, Vector3(0.012, 0.003, 0.045), Vector3(0, 0, 0.035), steel)
		"bottle", "molotov":
			_cyl(r, 0.035, 0.2, Vector3.ZERO, _m(Color(0.25, 0.45, 0.3, 1.0), 0.0, 0.1))
			_cyl(r, 0.012, 0.06, Vector3(0, 0.13, 0), _m(Color(0.25, 0.45, 0.3), 0.0, 0.1), Vector3.ZERO, 0.03)
			if id == "molotov": _box(r, Vector3(0.02, 0.06, 0.02), Vector3(0, 0.18, 0), _m(Color(0.9, 0.9, 0.85)))
		"scrap":
			_box(r, Vector3(0.3, 0.004, 0.18), Vector3.ZERO, _m(Color(0.42, 0.3, 0.22), 0.6, 0.8), Vector3(0.1, 0.3, 0.05))
			_box(r, Vector3(0.22, 0.004, 0.12), Vector3(0.04, 0.02, 0.03), _m(Color(0.5, 0.5, 0.48), 0.7, 0.6), Vector3(-0.15, 1.1, 0.1))
		"brick":
			_box(r, Vector3(0.23, 0.076, 0.11), Vector3.ZERO, _m(Color(0.62, 0.28, 0.18), 0.0, 0.95))
		"tin_sheet":
			_box(r, Vector3(0.9, 0.01, 0.6), Vector3.ZERO, _m(Color(0.6, 0.62, 0.62), 0.8, 0.45))
		"rock":
			var sm := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.06; sp.height = 0.09; sp.radial_segments = 8; sp.rings = 4
			sp.material = _m(Color(0.45, 0.43, 0.4), 0.0, 0.95); sm.mesh = sp; r.add_child(sm)
		"wood":
			for i in 3: _cyl(r, 0.04, 0.4, Vector3((i - 1) * 0.08, 0, 0), wood, Vector3(PI / 2, 0, 0))
		"stick":
			for i in 4: _cyl(r, 0.012, 0.45, Vector3((i - 1.5) * 0.03, 0, 0), wood, Vector3(PI / 2, (i - 1.5) * 0.1, 0))
		"cloth":
			_box(r, Vector3(0.2, 0.03, 0.16), Vector3.ZERO, _m(Color(0.55, 0.5, 0.45), 0.0, 1.0))
		"gunpowder":
			_cyl(r, 0.04, 0.1, Vector3.ZERO, _m(Color(0.3, 0.3, 0.32), 0.6, 0.5))
		"brass":
			for i in 4: _cyl(r, 0.006, 0.05, Vector3((i - 1.5) * 0.015, 0, 0), _m(Color(0.8, 0.62, 0.25), 0.9, 0.3))
		"seeds":
			_box(r, Vector3(0.08, 0.12, 0.01), Vector3.ZERO, _m(Color(0.45, 0.65, 0.3)))
		"water_bottle", "water_dirty":
			_cyl(r, 0.035, 0.22, Vector3.ZERO, _m(Color(0.6, 0.8, 0.95, 1.0), 0.0, 0.1))
			_cyl(r, 0.016, 0.02, Vector3(0, 0.12, 0), _m(Color(0.1, 0.3, 0.8)))
		"soft_drink":
			_cyl(r, 0.033, 0.12, Vector3.ZERO, _m(Color(0.8, 0.1, 0.1), 0.8, 0.3))
		"bandage":
			_cyl(r, 0.03, 0.06, Vector3.ZERO, _m(Color(0.92, 0.9, 0.85), 0.0, 0.95), Vector3(PI / 2, 0, 0))
		_:
			r.free()
			return null
	return r
