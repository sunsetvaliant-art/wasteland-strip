class_name EngineKit
extends RefCounted
## The modular engine kit (0.2.55). Every engine is built from interchangeable parts, all made in code from one shared
## spacing so ports, decks and bolt patterns always line up:
##   block     i3, i4, i6, V6, V8, each SMALL or BIG (big = taller deck, wider sump, more litres; same bolt pattern)
##   head      3, 4 or 6 cylinder; flathead, pushrod, SOHC or DOHC; low, medium or high compression. A V6 wears two
##             3-cylinder heads and a V8 two 4s, mirrored so the intake ports face the valley and the exhaust faces out
##   exhaust   manifolds for 3, 4 and 6 cylinder heads (a V8 uses the same 4 as an inline 4, one per bank)
##   intake    inline 3, inline 4, inline 6, V6 valley, V8 valley
##   fuel      carby or EFI throttle body (petrol), mechanical or electronic injection pump (diesel): the FUEL SYSTEM
##             decides what the engine is. Diesel won't fire without a high-compression head
##   ignition  a carby needs a distributor and coil; EFI's ECU does the spark
##   ECU       the silver box up top in the bay: petrol or diesel, for 3, 4, 6 or 8 cylinders; must match or it won't
##             run. Needed by a throttle body or an electronic pump. Tuned with a laptop: fuel, timing, rev limit
##   front     one belt: crank > water pump > alternator. No alternator: the battery drains while it runs
## Heads set the character: flathead lazy and torquey (~70% of a DOHC's power, 4.5k), pushrod torque (5.5k), SOHC the
## middle (6.5k), DOHC revs (7.5k). Petrol on a high-compression head makes more power but pings under load and
## wears the engine unless an ECU tune pulls timing (a carby can't). No condition on parts.
## A build is a plain Dictionary (design.kit) so it saves and travels with the car:
##   {block, heads: [id, (id)], exhaust: [id, (id)], intake, fuel, ign, ecu, alt: bool, tune: {fuel, timing, limit}, spanner: 0..1}
## Missing parts are "" (or false for the alternator).

# ------------------------------------------------------------------------------------------------ the parts
const BLOCKS := {
	"i3": {"name": "inline 3", "cyl": 3, "banks": 1, "vee": 0.0, "litres": [1.0, 1.5], "kg": [85, 105]},
	"i4": {"name": "inline 4", "cyl": 4, "banks": 1, "vee": 0.0, "litres": [1.8, 2.6], "kg": [120, 150]},
	"i6": {"name": "inline 6", "cyl": 6, "banks": 1, "vee": 0.0, "litres": [3.0, 4.2], "kg": [180, 220]},
	"v6": {"name": "V6", "cyl": 6, "banks": 2, "vee": 60.0, "litres": [3.0, 4.0], "kg": [160, 190]},
	"v8": {"name": "V8", "cyl": 8, "banks": 2, "vee": 90.0, "litres": [4.4, 5.8], "kg": [220, 270]},
}
const VALVETRAIN := {
	"flat": {"name": "flathead", "power": 0.70, "peak": 1800.0, "redline": 4500.0},
	"push": {"name": "pushrod", "power": 0.85, "peak": 2600.0, "redline": 5500.0},
	"sohc": {"name": "SOHC", "power": 0.92, "peak": 3400.0, "redline": 6500.0},
	"dohc": {"name": "DOHC", "power": 1.00, "peak": 4400.0, "redline": 7500.0},
}
const COMP := {"lo": {"name": "low compression", "mul": 0.92}, "med": {"name": "medium compression", "mul": 1.0}, "hi": {"name": "high compression", "mul": 1.08}}
const FUELS := {
	"carby": {"name": "Carburettor and air cleaner", "diesel": false, "ecu": false, "mul": 1.0},
	"tb": {"name": "EFI throttle body and pod filter", "diesel": false, "ecu": true, "mul": 1.06},
	"mech": {"name": "Mechanical diesel injection pump", "diesel": true, "ecu": false, "mul": 1.0},
	"epump": {"name": "Electronic diesel injection pump", "diesel": true, "ecu": true, "mul": 1.08},
}
const PITCH := 0.105            # bore spacing (m): every block, head and manifold shares it
const SIDE := ["intake", "exhaust"]

## Item ids for every part (registered with Items through item_def)
static func block_id(lay: String, big: bool) -> String: return "eb_%s_%s" % [lay, "big" if big else "small"]
static func head_id(cyl: int, vt: String, comp: String) -> String: return "eh_%d_%s_%s" % [cyl, vt, comp]
static func exhaust_id(cyl: int) -> String: return "ex_%d" % cyl
static func intake_id(lay: String) -> String: return "ei_%s" % lay
static func fuel_id(f: String) -> String: return "ef_%s" % f
static func ecu_id(diesel: bool, cyl: int) -> String: return "ecu_%s_%d" % ["d" if diesel else "p", cyl]

static var _items := {}
## Item definition for a part id ({} if it isn't one)
static func item_def(id: String) -> Dictionary:
	if _items.is_empty(): _register()
	return _items.get(id, {})

static func all_items() -> Array:
	if _items.is_empty(): _register()
	return _items.keys()

static func _register() -> void:
	for lay in BLOCKS:
		for big in [false, true]:
			var b: Dictionary = BLOCKS[lay]
			_items[block_id(lay, big)] = {"name": "%s %s block (%.1f L)" % ["Big" if big else "Small", b.name, b.litres[1 if big else 0]], "w": 4, "h": 3, "stack": 1, "kind": "misc", "part": "block"}
	for cyl in [3, 4, 6]:
		for vt in VALVETRAIN:
			for c in COMP:
				_items[head_id(cyl, vt, c)] = {"name": "%d-cyl %s head, %s" % [cyl, VALVETRAIN[vt].name, COMP[c].name], "w": 3 if cyl < 6 else 4, "h": 1, "stack": 1, "kind": "misc", "part": "head"}
		_items[exhaust_id(cyl)] = {"name": "%d-cyl exhaust manifold" % cyl, "w": 3 if cyl < 6 else 4, "h": 1, "stack": 1, "kind": "misc", "part": "exhaust"}
	for lay in ["i3", "i4", "i6", "v6", "v8"]:
		_items[intake_id(lay)] = {"name": "%s intake manifold" % (BLOCKS[lay].name.capitalize() if lay.begins_with("i") else BLOCKS[lay].name + " valley"), "w": 3, "h": 2 if lay.begins_with("v") else 1, "stack": 1, "kind": "misc", "part": "intake"}
	for f in FUELS:
		_items[fuel_id(f)] = {"name": FUELS[f].name, "w": 2, "h": 2, "stack": 1, "kind": "misc", "part": "fuel"}
	for d in [false, true]:
		for cyl in [3, 4, 6, 8]:
			_items[ecu_id(d, cyl)] = {"name": "ECU, %s %d-cyl" % ["diesel" if d else "petrol", cyl], "w": 2, "h": 1, "stack": 1, "kind": "misc", "part": "ecu"}
	_items["ign_dizzy"] = {"name": "Distributor and coil", "w": 1, "h": 2, "stack": 1, "kind": "misc", "part": "ign"}
	_items["alternator"] = {"name": "Alternator", "w": 2, "h": 2, "stack": 1, "kind": "misc", "part": "alt"}
	_items["laptop"] = {"name": "Laptop and tuning cable", "w": 2, "h": 2, "stack": 1, "kind": "misc"}

## What a block id means: [layout, big]
static func parse_block(id: String) -> Array:
	var p := id.split("_")
	if p.size() < 3 or not BLOCKS.has(p[1]): return []
	return [p[1], p[2] == "big"]

## [cyl, valvetrain, compression] for a head id
static func parse_head(id: String) -> Array:
	var p := id.split("_")
	if p.size() < 4: return []
	return [int(p[1]), p[2], p[3]]

static func bank_cyl(lay: String) -> int:
	var b: Dictionary = BLOCKS[lay]
	return int(b.cyl) / int(b.banks)

# ------------------------------------------------------------------------------------------------ builds
static func make(lay: String, big: bool, vt: String, comp: String, fuel: String, alt := true) -> Dictionary:
	var b: Dictionary = BLOCKS[lay]
	var bc := bank_cyl(lay)
	var heads: Array = []
	var ex: Array = []
	for i in int(b.banks):
		heads.append(head_id(bc, vt, comp))
		ex.append(exhaust_id(bc))
	var f: Dictionary = FUELS[fuel]
	return {"block": block_id(lay, big), "heads": heads, "exhaust": ex, "intake": intake_id(lay), "fuel": fuel_id(fuel),
		"ign": "" if f.ecu or f.diesel else "ign_dizzy", "ecu": ecu_id(f.diesel, int(b.cyl)) if f.ecu else "", "alt": alt,
		"tune": {"fuel": 0.0, "timing": 0.0, "limit": 0.0}, "spanner": 0.0}

## The engine each body comes with, by era and where it's from
static func stock(def: Dictionary) -> Dictionary:
	var n := str(def.get("name", "")).to_lower()
	var big4 := str(def.get("cls", "")) == "4x4"
	if n.contains("hemi") or n.contains("blown") or n.contains("muscle") or n.contains("charger"): return make("v8", true, "push", "hi", "carby")
	if n.contains("chevy") or n.contains("f-series") or n.contains("relic pickup") or n.contains("workhorse") or n.contains("ford"): return make("v8", true, "push", "med", "carby")
	if n.contains("gt") or n.contains("fairlane") or n.contains("monaro"): return make("v8", false, "push", "med", "carby")
	if n.contains("falcon") or n.contains("valiant") or n.contains("holden") or n.contains("kingswood") or n.contains("wagon"): return make("i6", n.contains("valiant"), "push", "med", "carby")
	if n.contains("hilux") or n.contains("land cruiser") or n.contains("cruiser") or n.contains("patrol"): return make("i6", true, "sohc", "hi", "mech")
	if n.contains("pickup"): return make("i4", true, "sohc", "med", "carby") if not big4 else make("i4", true, "sohc", "hi", "mech")
	if n.contains("mini") or n.contains("scooter") or n.contains("kei"): return make("i3", false, "sohc", "med", "carby")
	if big4: return make("i6", true, "push", "med", "carby")
	return make("i6", false, "push", "med", "carby")

# ------------------------------------------------------------------------------------------------ will it run, and how well
## What's wrong with a build ("" if it'll run)
static func fault(k: Dictionary) -> String:
	if k.is_empty() or str(k.get("block", "")) == "": return "No engine in it"
	var pb := parse_block(str(k.block))
	if pb.is_empty(): return "No engine in it"
	var b: Dictionary = BLOCKS[pb[0]]
	var bc := bank_cyl(pb[0])
	var heads: Array = k.get("heads", [])
	for i in int(b.banks):
		if i >= heads.size() or str(heads[i]) == "": return "Missing a cylinder head"
		var ph := parse_head(str(heads[i]))
		if ph.is_empty() or int(ph[0]) != bc: return "The head doesn't suit that block"
	if str(k.get("intake", "")) != intake_id(pb[0]): return "No intake manifold" if str(k.get("intake", "")) == "" else "Wrong intake manifold for that block"
	var fs := str(k.get("fuel", "")).trim_prefix("ef_")
	if not FUELS.has(fs): return "No carby, throttle body or injection pump"
	var f: Dictionary = FUELS[fs]
	if f.diesel:
		for h in heads.slice(0, int(b.banks)):
			if parse_head(str(h))[2] != "hi": return "Not enough compression to light diesel (needs a high-compression head)"
	if f.ecu:
		if str(k.get("ecu", "")) == "": return "Injected: it needs an ECU"
		if str(k.ecu) != ecu_id(f.diesel, int(b.cyl)): return "Wrong ECU for this engine (%s %d-cyl)" % ["diesel" if f.diesel else "petrol", int(b.cyl)]
	elif not f.diesel and str(k.get("ign", "")) != "ign_dizzy":
		return "A carby needs a distributor and coil"
	return ""

static func is_diesel(k: Dictionary) -> bool:
	var fs := str(k.get("fuel", "")).trim_prefix("ef_")
	return FUELS.has(fs) and FUELS[fs].diesel

static func has_ecu(k: Dictionary) -> bool:
	return str(k.get("ecu", "")) != ""

## Pings under load: petrol on a high-compression head (or with the timing wound up) and no tune to pull it back
static func pings(k: Dictionary) -> float:
	if is_diesel(k): return 0.0
	var t: Dictionary = k.get("tune", {})
	var hi := false
	for h in k.get("heads", []):
		var ph := parse_head(str(h))
		if not ph.is_empty() and ph[2] == "hi": hi = true
	var p := (0.6 if hi else 0.0) + maxf(float(t.get("timing", 0.0)) - 0.3, 0.0) * 1.2
	if hi and has_ecu(k): p -= 0.6 * clampf(-float(t.get("timing", 0.0)) / 0.5 + 0.4, 0.0, 1.0)   # a tune with the timing pulled back
	return clampf(p, 0.0, 1.0)

## Smokes: a diesel turned up with a spanner or fuelled up on the laptop
static func smokes(k: Dictionary) -> float:
	if not is_diesel(k): return 0.0
	return clampf(float(k.get("spanner", 0.0)) + maxf(float(k.get("tune", {}).get("fuel", 0.0)) - 0.3, 0.0) * 1.4, 0.0, 1.0)

## The engine as the car sim wants it (same shape as VehicleSpecs.ENGINES entries)
static func stats(k: Dictionary) -> Dictionary:
	var pb := parse_block(str(k.get("block", "")))
	if pb.is_empty(): pb = ["i4", false]
	var lay: String = pb[0]; var big: bool = pb[1]
	var b: Dictionary = BLOCKS[lay]
	var heads: Array = k.get("heads", [])
	var ph := parse_head(str(heads[0])) if not heads.is_empty() and str(heads[0]) != "" else [bank_cyl(lay), "push", "med"]
	var vt: Dictionary = VALVETRAIN.get(ph[1], VALVETRAIN.push)
	var comp: float = COMP.get(ph[2], COMP.med).mul
	var fs := str(k.get("fuel", "")).trim_prefix("ef_")
	var f: Dictionary = FUELS.get(fs, FUELS.carby)
	var t: Dictionary = k.get("tune", {})
	var L: float = b.litres[1 if big else 0]
	var diesel: bool = f.diesel
	# torque per litre at the peak: petrol ~105 Nm/L for a DOHC, diesel more down low
	var peak_nm := L * (118.0 if diesel else 105.0) * comp * float(f.mul)
	var vt_power: float = vt.power
	# the valvetrain mostly moves where it makes it: a flathead's torque is all down low, a DOHC's up high
	peak_nm *= lerpf(1.0, vt_power, 0.35)
	var redline: float = vt.redline
	var peak: float = vt.peak
	if diesel:
		redline = minf(redline, 4300.0) - 400.0
		peak = minf(peak, 2200.0)
	if f.ecu:
		peak_nm *= 1.0 + 0.05 * float(t.get("fuel", 0.0)) + 0.06 * float(t.get("timing", 0.0))
		redline += 600.0 * float(t.get("limit", 0.0))
	if diesel and not f.ecu: peak_nm *= 1.0 + 0.12 * float(k.get("spanner", 0.0))
	var ex: Array = k.get("exhaust", [])
	var ex_ok := ex.size() >= int(b.banks) and not ex.slice(0, int(b.banks)).has("")
	if not ex_ok: peak_nm *= 0.82
	# curve: rises to the peak, holds, falls toward the redline (a DOHC holds on; a flathead falls away)
	var fall := lerpf(0.55, 0.64, (vt_power - 0.7) / 0.3)
	var curve := [[0, peak_nm * 0.45], [800, peak_nm * (0.72 if diesel else 0.62)], [int(peak * 0.55), peak_nm * 0.88],
		[int(peak), peak_nm], [int(lerpf(peak, redline, 0.5)), peak_nm * lerpf(1.0, fall, 0.45)],
		[int(redline), peak_nm * fall], [int(redline + 600.0), peak_nm * fall * 0.75]]
	var cyl := int(b.cyl)
	return {"name": describe(k), "glb": "", "cyl": cyl, "sound": sound_key(k), "pitch_mul": pitch_mul(k), "rough": 0.35 if diesel else (0.12 if ph[1] == "flat" else 0.0),
		"idle": 750 if not diesel else 680, "redline": int(redline), "limiter": int(redline + 300.0), "curve": curve,
		"inertia": 0.08 + L * 0.035, "friction": 8.0 + L * 3.5, "kg": int(b.kg[1 if big else 0]) + (25 if diesel else 0),
		"len": length_of(lay) + 0.35, "kit": true, "diesel": diesel}

static func describe(k: Dictionary) -> String:
	var pb := parse_block(str(k.get("block", "")))
	if pb.is_empty(): return "No engine"
	var b: Dictionary = BLOCKS[pb[0]]
	var heads: Array = k.get("heads", [])
	var ph := parse_head(str(heads[0])) if not heads.is_empty() and str(heads[0]) != "" else []
	var fs := str(k.get("fuel", "")).trim_prefix("ef_")
	return "%.1f L %s%s%s" % [b.litres[1 if pb[1] else 0], b.name, (" " + VALVETRAIN[ph[1]].name) if not ph.is_empty() else "",
		(" diesel" if FUELS.has(fs) and FUELS[fs].diesel else (" EFI" if fs == "tb" else ""))]

## Which recorded engine to play and how to pitch it: V8s burble, sixes are smooth, diesels clatter
static func sound_key(k: Dictionary) -> String:
	var pb := parse_block(str(k.get("block", "")))
	var lay: String = pb[0] if not pb.is_empty() else "i6"
	var ph := parse_head(str(k.get("heads", [""])[0])) if not k.get("heads", []).is_empty() else []
	var vt: String = ph[1] if not ph.is_empty() else "push"
	match lay:
		"v8": return "v8_hemi" if vt in ["sohc", "dohc"] else ("v8_pickup" if pb[1] else "v8_351")
		"v6": return "v8_351"
		"i6": return "i6_40" if vt in ["sohc", "dohc"] or is_diesel(k) else "i6_202"
	return "i4_22r"

static func pitch_mul(k: Dictionary) -> float:
	var pb := parse_block(str(k.get("block", "")))
	var lay: String = pb[0] if not pb.is_empty() else "i6"
	var m := 1.0
	if lay == "v6": m = 0.75 * 1.1
	elif lay == "i3": m = 0.82
	if is_diesel(k): m *= 0.82
	return m

static func length_of(lay: String) -> float:
	return bank_cyl(lay) * PITCH + 0.14 + (PITCH * 0.5 if BLOCKS[lay].banks == 2 else 0.0)

# ------------------------------------------------------------------------------------------------ the meshes
static var _mats := {}
static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	var c: Array = {"iron": [Color(0.2, 0.2, 0.21), 0.5, 0.75], "alloy": [Color(0.62, 0.62, 0.6), 0.7, 0.45], "rust": [Color(0.32, 0.2, 0.13), 0.3, 0.9],
		"black": [Color(0.06, 0.06, 0.06), 0.2, 0.6], "rubber": [Color(0.03, 0.03, 0.03), 0.0, 0.85], "silver": [Color(0.78, 0.79, 0.8), 0.85, 0.3],
		"red": [Color(0.55, 0.08, 0.06), 0.3, 0.5], "blue": [Color(0.12, 0.2, 0.45), 0.3, 0.5], "orange": [Color(0.75, 0.32, 0.06), 0.3, 0.5],
		"brass": [Color(0.7, 0.55, 0.25), 0.8, 0.35], "steel": [Color(0.45, 0.45, 0.46), 0.75, 0.4], "pod": [Color(0.7, 0.1, 0.08), 0.0, 0.8],
		"wire": [Color(0.1, 0.1, 0.1), 0.0, 0.7]}.get(key, [Color(0.5, 0.5, 0.5), 0.3, 0.6])
	m.albedo_color = c[0]; m.metallic = c[1]; m.roughness = c[2]
	_mats[key] = m
	return m

## Collects primitives by material, then one ArrayMesh with a surface per material
class Mk:
	var sts := {}
	func st(m: String) -> SurfaceTool:
		if not sts.has(m):
			var s := SurfaceTool.new(); s.begin(Mesh.PRIMITIVE_TRIANGLES); sts[m] = s
		return sts[m]
	func box(m: String, size: Vector3, at: Vector3, basis := Basis.IDENTITY) -> void:
		var bm := BoxMesh.new(); bm.size = size
		st(m).append_from(bm, 0, Transform3D(basis, at))
	func cyl(m: String, r: float, h: float, at: Vector3, basis := Basis.IDENTITY, r_top := -1.0, segs := 12) -> void:
		## a cylinder along the basis' Y, its middle at `at`
		var cm := CylinderMesh.new(); cm.top_radius = r if r_top < 0.0 else r_top; cm.bottom_radius = r; cm.height = h
		cm.radial_segments = segs; cm.rings = 1
		st(m).append_from(cm, 0, Transform3D(basis, at))
	func pipe(m: String, a: Vector3, b: Vector3, r: float, segs := 8) -> void:
		var d := b - a
		var L := d.length()
		if L < 0.001: return
		var y := d / L
		var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		cyl(m, r, L, (a + b) * 0.5, Basis(x, y, z), -1.0, segs)
	func commit() -> ArrayMesh:
		var am := ArrayMesh.new()
		for m in sts:
			var s: SurfaceTool = sts[m]
			s.generate_normals()
			s.commit(am)
			am.surface_set_material(am.get_surface_count() - 1, EngineKit.mat(m))
		return am

static var _cache := {}

## The whole engine as a node: crank along Z (front, the pulleys, toward +Z), crank centre at the origin
static func build_node(k: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "KitEngine"
	var key := JSON.stringify([k.get("block"), k.get("heads"), k.get("exhaust"), k.get("intake"), k.get("fuel"), k.get("ign"), k.get("alt")])
	var am: ArrayMesh = _cache.get(key)
	if am == null:
		var mk := Mk.new()
		_build(mk, k)
		am = mk.commit()
		if _cache.size() > 64: _cache.clear()
		_cache[key] = am
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.name = "Mesh"
	root.add_child(mi)
	return root

static func _build(mk: Mk, k: Dictionary) -> void:
	var pb := parse_block(str(k.get("block", "")))
	if pb.is_empty(): return
	var lay: String = pb[0]; var big: bool = pb[1]
	var b: Dictionary = BLOCKS[lay]
	var bc := bank_cyl(lay)
	var deck := 0.36 if big else 0.30
	var L := bc * PITCH + 0.14
	var vee := deg_to_rad(float(b.vee))
	var banks := int(b.banks)
	var stagger := PITCH * 0.5 if banks == 2 else 0.0
	var Lb := L + stagger
	var bw := 0.34 if big else 0.30
	# ---- the block: crankcase, skirt, sump, bellhousing flange at the back, timing cover at the front
	mk.box("iron", Vector3(bw if banks == 1 else 0.42, 0.24, Lb), Vector3(0, 0.04, 0))
	mk.box("iron", Vector3((bw + 0.04) if big else bw, 0.16, Lb * 0.9), Vector3(0, -0.15, -0.02))          # sump
	mk.box("black", Vector3(bw * 0.8, 0.05, Lb * 0.7), Vector3(0, -0.24, -0.02))
	mk.cyl("iron", 0.25 if big else 0.22, 0.05, Vector3(0, 0.02, -Lb * 0.5 - 0.02), Basis(Vector3.RIGHT, PI * 0.5))     # bellhousing face
	mk.box("iron", Vector3(0.24, 0.22, 0.03), Vector3(0, 0.05, Lb * 0.5 + 0.015))           # timing cover
	var deck_pts := []          # per bank: [deck centre, bank 'up', bank 'out' (exhaust side), z offset]
	if banks == 1:
		mk.box("iron", Vector3(bw * 0.86, deck - 0.12, L), Vector3(0, 0.12 + (deck - 0.12) * 0.5, 0))
		deck_pts.append([Vector3(0, deck, 0), Vector3.UP, Vector3.RIGHT, 0.0])
	else:
		for s: float in [-1.0, 1.0]:
			var up := Vector3(sin(vee * 0.5) * s, cos(vee * 0.5), 0)
			var out := Vector3(cos(vee * 0.5) * s, -sin(vee * 0.5), 0)
			var zoff := stagger * 0.5 * s
			var dc := up * deck
			var basis := Basis(out * s, up, Vector3(0, 0, 1)) if s > 0 else Basis(-out, up, Vector3(0, 0, 1))
			# the bank: a slab from the crank up to the deck, leaning out
			mk.box("iron", Vector3(0.2, deck - 0.08, L), up * (0.08 + (deck - 0.08) * 0.5) + Vector3(0, 0, zoff), Basis(Vector3.BACK, -vee * 0.5 * s))
			deck_pts.append([dc + Vector3(0, 0, zoff), up, out, zoff])
	# ---- heads, covers and exhaust per bank (the intake side faces the valley on a V, -X on an inline)
	var heads: Array = k.get("heads", [])
	var exs: Array = k.get("exhaust", [])
	var inner_ports := []            # intake port points (world, engine frame) for the intake manifold
	for bi in deck_pts.size():
		var dp: Array = deck_pts[bi]
		var dc: Vector3 = dp[0]; var up: Vector3 = dp[1]; var out: Vector3 = dp[2]
		var into := -out
		var zc: float = dp[3]
		var hid := str(heads[bi]) if bi < heads.size() else ""
		if hid == "": continue
		var ph := parse_head(hid)
		var vt: String = ph[1]
		var bas := Basis(out, up, Vector3(0, 0, 1)).orthonormalized()
		if bas.determinant() < 0.0: bas = Basis(-out, up, Vector3(0, 0, 1)).orthonormalized()
		var hh := 0.07 if vt == "flat" else 0.12
		var hw := 0.25
		mk.box("iron" if vt in ["flat", "push"] else "alloy", Vector3(hw, hh, L - 0.02), dc + up * (hh * 0.5), bas)
		var top := dc + up * hh
		match vt:
			"flat":
				for i in 7:
					mk.box("alloy", Vector3(hw * 0.86, 0.035, 0.012), top + up * 0.017 + Vector3(0, 0, -L * 0.42 + i * L * 0.14), bas)
			"push":
				mk.box("black", Vector3(0.17, 0.07, L - 0.08), top + up * 0.035 - out * 0.02, bas)
				mk.cyl("black", 0.022, 0.04, top + up * 0.085 - out * 0.02 + Vector3(0, 0, L * 0.3), bas)       # oil filler
			"sohc":
				mk.box("red", Vector3(0.16, 0.09, L - 0.06), top + up * 0.045, bas)
				mk.box("red", Vector3(0.06, 0.03, L - 0.1), top + up * 0.1, bas)
			"dohc":
				for s2: float in [-1.0, 1.0]:
					mk.cyl("silver", 0.05, L - 0.06, top + up * 0.05 + out * 0.055 * s2, bas * Basis(Vector3.RIGHT, PI * 0.5))
				mk.box("silver", Vector3(0.22, 0.05, L - 0.05), top + up * 0.025, bas)
				mk.box("black", Vector3(0.05, 0.012, L * 0.5), top + up * 0.105, bas)
		# spark plug leads or injectors along the middle of the head
		for i in bc:
			var z := (i - (bc - 1) * 0.5) * PITCH + zc
			var p: Vector3 = Vector3(top.x, top.y, z) + up * (0.14 if vt != "flat" else 0.04) - out * 0.0
			if is_diesel(k):
				mk.cyl("steel", 0.012, 0.05, p + up * 0.01, bas)
			else:
				mk.cyl("black", 0.009, 0.04, p + into * (0.09 if vt != "dohc" else 0.0) + up * -0.02, bas)
			# ports: exhaust out, intake in
			var py := dc + up * (hh * 0.5)
			var pe := Vector3(py.x, py.y, z) + out * (hw * 0.5)
			var pi := Vector3(py.x, py.y, z) + into * (hw * 0.5)
			inner_ports.append([pi, into, bi])
			if bi < exs.size() and str(exs[bi]) != "":
				# exhaust primary: out from the port, bending down and back to the collector
				var c1 := pe + out * 0.07
				var col := Vector3(pe.x, pe.y, 0) + out * 0.13 - up * 0.16 + Vector3(0, 0, z * 0.25 - L * 0.32)
				mk.pipe("rust", pe, c1, 0.022)
				mk.pipe("rust", c1, col, 0.022)
		if bi < exs.size() and str(exs[bi]) != "":
			var pe0 := Vector3(dc.x, dc.y, zc) + up * (hh * 0.5) + out * (hw * 0.5)
			var colz := Vector3(pe0.x, pe0.y, 0) + out * 0.13 - up * 0.16 + Vector3(0, 0, -L * 0.32)
			mk.box("rust", Vector3(0.025, 0.05, bc * PITCH), Vector3(pe0.x, pe0.y, zc) + out * 0.004, bas)        # flange
			mk.cyl("rust", 0.035, 0.08, colz, Basis.IDENTITY)
			mk.pipe("rust", colz, colz + Vector3(0, -0.22, -0.18), 0.03)
	# ---- intake
	var iid := str(k.get("intake", ""))
	var flange := Vector3(0, deck + 0.14, 0)
	if iid != "":
		if banks == 1:
			var sx := -1.0
			var plen := L - 0.06
			var px := -(0.125 + 0.09)
			mk.box("alloy", Vector3(0.07, 0.07, plen), Vector3(px, deck + 0.04, 0))            # the log
			for ip in inner_ports:
				var p0: Vector3 = ip[0]
				mk.pipe("alloy", p0, Vector3(px + 0.03, deck + 0.04, p0.z), 0.022)
			mk.box("alloy", Vector3(0.1, 0.05, 0.1), Vector3(px, deck + 0.1, 0))
			flange = Vector3(px, deck + 0.125, 0)
		else:
			var top_y := deck * cos(vee * 0.5) + 0.12
			mk.box("alloy", Vector3(0.2, 0.08, L), Vector3(0, top_y, 0))           # valley plenum
			for ip in inner_ports:
				var p0: Vector3 = ip[0]
				mk.pipe("alloy", p0, Vector3(signf(p0.x) * 0.06, top_y - 0.02, p0.z), 0.022)
			mk.box("alloy", Vector3(0.12, 0.04, 0.12), Vector3(0, top_y + 0.06, 0))
			flange = Vector3(0, top_y + 0.08, 0)
	# ---- fuel system
	var fs := str(k.get("fuel", "")).trim_prefix("ef_")
	match fs:
		"carby":
			mk.box("silver", Vector3(0.11, 0.09, 0.11), flange + Vector3(0, 0.045, 0))
			mk.cyl("black", 0.17, 0.07, flange + Vector3(0, 0.125, 0))
			mk.cyl("silver", 0.02, 0.03, flange + Vector3(0, 0.175, 0))
		"tb":
			mk.box("alloy", Vector3(0.09, 0.06, 0.09), flange + Vector3(0, 0.03, 0))
			mk.pipe("silver", flange + Vector3(0, 0.06, 0), flange + Vector3(0, 0.06, 0.1), 0.04)
			mk.cyl("pod", 0.075, 0.16, flange + Vector3(0, 0.06, 0.18), Basis(Vector3.RIGHT, PI * 0.5), 0.05)
		"mech", "epump":
			var side := -0.2 if banks == 1 else 0.0
			var pp := Vector3(side, 0.14 if banks == 1 else deck * cos(vee * 0.5) - 0.02, Lb * 0.18)
			mk.cyl("alloy" if fs == "mech" else "black", 0.05, 0.24, pp, Basis(Vector3.RIGHT, PI * 0.5))
			if fs == "epump": mk.box("black", Vector3(0.07, 0.05, 0.06), pp + Vector3(0, 0.06, 0.06))
			else: mk.box("alloy", Vector3(0.04, 0.08, 0.04), pp + Vector3(0, 0.07, -0.05))
			for dp in deck_pts:
				var up: Vector3 = dp[1]; var dc: Vector3 = dp[0]
				for i in bc:
					var z := (i - (bc - 1) * 0.5) * PITCH + float(dp[3])
					mk.pipe("steel", pp + Vector3(0, 0.04, 0), Vector3(dc.x, dc.y, z) + up * 0.16, 0.005, 5)
			if iid != "":
				mk.box("black", Vector3(0.1, 0.05, 0.1), flange + Vector3(0, 0.025, 0))
				mk.pipe("black", flange + Vector3(0, 0.05, 0), flange + Vector3(0, 0.05, 0.16), 0.045)
	# ---- distributor and coil
	if str(k.get("ign", "")) == "ign_dizzy":
		var dz := Vector3(0.0 if banks == 2 else -0.12, deck + (0.02 if banks == 1 else 0.05), -Lb * 0.5 + 0.06)
		if banks == 2: dz.y = deck * cos(vee * 0.5) + 0.05
		mk.cyl("black", 0.035, 0.12, dz)
		mk.cyl("red", 0.045, 0.04, dz + Vector3(0, 0.07, 0))
		mk.cyl("black", 0.025, 0.1, dz + Vector3(0.1, 0.0, 0.03))
		for dp in deck_pts:
			var dc: Vector3 = dp[0]; var up: Vector3 = dp[1]
			mk.pipe("wire", dz + Vector3(0, 0.08, 0), Vector3(dc.x, dc.y, float(dp[3])) + up * 0.2, 0.006, 5)
	# ---- the front: crank pulley, water pump, alternator, one belt round them
	var zf := Lb * 0.5 + 0.05
	var crank := Vector3(0, 0.0, zf)
	var wp := Vector3(0, 0.2 if banks == 1 else 0.22, zf)
	var alt := Vector3(0.21 if banks == 1 else 0.26, 0.24 if banks == 1 else 0.28, zf)
	var pul := Basis(Vector3.RIGHT, PI * 0.5)
	mk.cyl("steel", 0.085, 0.035, crank, pul)
	mk.cyl("iron", 0.06, 0.06, wp + Vector3(0, 0, -0.03), pul)
	mk.cyl("steel", 0.055, 0.03, wp, pul)
	var pulleys: Array = [[crank, 0.085], [wp, 0.055]]
	if k.get("alt", false):
		mk.cyl("silver", 0.065, 0.13, alt + Vector3(0, 0, -0.08), pul)
		mk.cyl("black", 0.07, 0.02, alt + Vector3(0, 0, -0.02), pul)
		mk.cyl("steel", 0.032, 0.03, alt, pul)
		mk.box("steel", Vector3(0.12, 0.02, 0.02), (alt + wp) * 0.5 + Vector3(0, 0, -0.05))
		pulleys.append([alt, 0.032])
	_belt(mk, pulleys, zf + 0.002)

## A flat belt wrapped round the pulleys (centres in a plane at z = zf), drawn as a band along their hull
static func _belt(mk: Mk, pulleys: Array, zf: float) -> void:
	var pts := PackedVector2Array()
	for p in pulleys:
		var c: Vector3 = p[0]; var r: float = float(p[1]) + 0.004
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(Vector2(c.x + cos(a) * r, c.y + sin(a) * r))
	var hull := Geometry2D.convex_hull(pts)
	var s := mk.st("rubber")
	for i in hull.size() - 1:
		var a := hull[i]; var b := hull[i + 1]
		var n := Vector2(b.y - a.y, a.x - b.x).normalized() * 0.006
		var q: Array[Vector3] = [Vector3(a.x, a.y, zf - 0.011), Vector3(b.x, b.y, zf - 0.011), Vector3(b.x, b.y, zf + 0.011), Vector3(a.x, a.y, zf + 0.011)]
		var o: Array[Vector3] = [Vector3(a.x + n.x, a.y + n.y, zf - 0.011), Vector3(b.x + n.x, b.y + n.y, zf - 0.011), Vector3(b.x + n.x, b.y + n.y, zf + 0.011), Vector3(a.x + n.x, a.y + n.y, zf + 0.011)]
		for v in [o[0], o[1], o[2], o[0], o[2], o[3], q[0], q[2], q[1], q[0], q[3], q[2]]:
			s.add_vertex(v)

## The ECU (a silver box with a plug) and the battery, for the top of the bay
static func ecu_node() -> Node3D:
	var mk := Mk.new()
	mk.box("silver", Vector3(0.2, 0.04, 0.15), Vector3.ZERO)
	mk.box("black", Vector3(0.06, 0.03, 0.03), Vector3(0.05, 0.0, 0.085))
	for i in 5: mk.box("silver", Vector3(0.006, 0.01, 0.15), Vector3(-0.08 + i * 0.03, 0.025, 0))
	var mi := MeshInstance3D.new(); mi.mesh = mk.commit(); mi.name = "ECU"
	return mi

static func battery_node() -> Node3D:
	var mk := Mk.new()
	mk.box("black", Vector3(0.26, 0.2, 0.17), Vector3(0, 0.1, 0))
	mk.cyl("red", 0.012, 0.025, Vector3(0.09, 0.21, 0.05))
	mk.cyl("black", 0.012, 0.025, Vector3(-0.09, 0.21, 0.05))
	var mi := MeshInstance3D.new(); mi.mesh = mk.commit(); mi.name = "Battery"
	return mi

## A loose part on the ground or on a shelf: the same code, just that part
static func part_node(id: String) -> Node3D:
	var d := item_def(id)
	var k := {}
	match str(d.get("part", "")):
		"block":
			k = {"block": id, "heads": [], "exhaust": [], "intake": "", "fuel": "", "ign": "", "alt": false}
		_:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.3, 0.12, 0.2)
			mi.mesh = bm; mi.material_override = mat("alloy" if str(d.get("part", "")) != "ecu" else "silver")
			return mi
	return build_node(k)
