class_name Lamps
## Lamps placed in Body tools (0.2.68): generic round or rectangular headlights to stick on a body that has none,
## and bulbs to light up a housing the model already has (head or tail). Saved with the body's cut as "lights":
## [{t: round|rect|bulb|tail, p: [x, y, z], n: [x, y, z], s: size m, a: aspect (rect), d: depth m}], body frame.
## They glow with the car's lights (L); tail bulbs flare on the brakes. The car's two headlight beams move to the
## outermost headlights placed.

const TYPES := [["round", "Round headlight"], ["rect", "Rectangle headlight"], ["bulb", "Bulb in a housing"], ["tail", "Tail / brake bulb"]]

static var _chrome: StandardMaterial3D

static func chrome() -> StandardMaterial3D:
	if _chrome == null:
		_chrome = StandardMaterial3D.new()
		_chrome.albedo_color = Color(0.8, 0.8, 0.82)
		_chrome.metallic = 1.0
		_chrome.roughness = 0.18
	return _chrome

## A lens material that glows: one per car (head and tail), so the car can turn them on and off
static func lens_mat(tail: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.06, 0.04) if tail else Color(0.86, 0.88, 0.9)
	m.metallic = 0.0
	m.roughness = 0.08
	m.emission_enabled = true
	m.emission = Color(1.0, 0.08, 0.04) if tail else Color(1.0, 0.94, 0.8)
	m.emission_energy_multiplier = 0.0
	return m

static func _basis_for(n: Vector3) -> Basis:
	var y := n.normalized() if n.length_squared() > 1e-6 else Vector3.BACK
	var x := Vector3.UP.cross(y)
	if x.length_squared() < 1e-4: x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)       # the lamp's +Y points out of the panel

## The lamps as a node in the body frame. Returns {node, head: lens material, tail: lens material, glows: [OmniLight3D],
## beams: [Vector3 positions of headlights]}
static func build(list: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = "Lamps"
	var head := lens_mat(false)
	var tail := lens_mat(true)
	var glows: Array = []
	var beams: Array = []
	for e in list:
		var d: Dictionary = e
		var t := str(d.get("t", "round"))
		var p := Vector3(float(d.p[0]), float(d.p[1]), float(d.p[2]))
		var n := Vector3(float(d.n[0]), float(d.n[1]), float(d.n[2]))
		var s := float(d.get("s", 0.18))
		var dep := float(d.get("d", 0.0))
		var lamp := Node3D.new()
		lamp.transform = Transform3D(_basis_for(n), p - n.normalized() * dep)
		root.add_child(lamp)
		match t:
			"round":
				var bz := MeshInstance3D.new()
				var cm := CylinderMesh.new(); cm.top_radius = s * 0.5; cm.bottom_radius = s * 0.5; cm.height = 0.035; cm.radial_segments = 20; cm.rings = 1
				cm.material = chrome()
				bz.mesh = cm; bz.position.y = 0.0
				lamp.add_child(bz)
				var ln := MeshInstance3D.new()
				var sm := SphereMesh.new(); sm.radius = s * 0.43; sm.height = s * 0.2; sm.radial_segments = 20; sm.rings = 4
				sm.material = head
				ln.mesh = sm; ln.position.y = 0.02
				lamp.add_child(ln)
				beams.append(p)
			"rect":
				var a := float(d.get("a", 0.55))
				var bz2 := MeshInstance3D.new()
				var bm := BoxMesh.new(); bm.size = Vector3(s, 0.035, s * a); bm.material = chrome()
				bz2.mesh = bm
				lamp.add_child(bz2)
				var ln2 := MeshInstance3D.new()
				var bm2 := BoxMesh.new(); bm2.size = Vector3(s * 0.88, 0.02, s * a * 0.82); bm2.material = head
				ln2.mesh = bm2; ln2.position.y = 0.02
				lamp.add_child(ln2)
				beams.append(p)
			_:
				var tl := t == "tail"
				var bl := MeshInstance3D.new()
				var bs := SphereMesh.new(); bs.radius = s * 0.12; bs.height = s * 0.24; bs.radial_segments = 10; bs.rings = 5
				bs.material = tail if tl else head
				bl.mesh = bs
				lamp.add_child(bl)
				# a small light inside lights up the model's own housing round it
				var o := OmniLight3D.new()
				o.omni_range = maxf(s * 1.6, 0.25)
				o.light_energy = 1.6 if tl else 2.4
				o.light_color = Color(1.0, 0.12, 0.06) if tl else Color(1.0, 0.93, 0.78)
				o.shadow_enabled = false
				o.position.y = -0.01
				o.visible = false
				o.set_meta("tail", tl)
				lamp.add_child(o)
				glows.append(o)
				if not tl: beams.append(p)
	return {"node": root, "head": head, "tail": tail, "glows": glows, "beams": beams}

## Light them: head on/off, tail at running or brake brightness
static func set_lit(info: Dictionary, lit: bool, braking: bool) -> void:
	if info.is_empty(): return
	(info.head as StandardMaterial3D).emission_energy_multiplier = 4.0 if lit else 0.0
	(info.tail as StandardMaterial3D).emission_energy_multiplier = 5.0 if braking else (1.4 if lit else 0.0)
	for o in info.glows:
		var ol := o as OmniLight3D
		if not is_instance_valid(ol): continue
		var tl: bool = ol.get_meta("tail", false)
		ol.visible = lit or (tl and braking)
		if tl: ol.light_energy = 3.0 if braking else 1.2
