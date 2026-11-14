class_name BasePiece
extends StaticBody3D
## One piece of something you built: a floor, a wall, a doorway, a window wall, a half wall, stairs, a storage crate.
## Wood, tin or brick. Zombies beat on it until it gives way.

const KINDS := ["wall", "doorway", "window", "half", "floor", "stairs", "crate", "bench", "fire", "garden"]
## pieces that come in one material only, with their own cost (the work stations and the crate)
const FIXED := {"crate": {"plank": 4, "nails": 1}, "bench": {"plank": 4, "nails": 1, "scrap": 2}, "fire": {"rock": 6}, "garden": {"plank": 3, "nails": 1}}
const FIRE_BURN := 480.0        # seconds a fire burns on one lot of wood
const GROW := 1200.0            # seconds from seed to vegies
const NAMES := {"wall": "Wall", "doorway": "Doorway", "window": "Window wall", "half": "Half wall", "floor": "Floor / roof", "stairs": "Stairs", "crate": "Storage crate", "bench": "Workbench", "fire": "Campfire", "garden": "Vegie garden"}
const TIERS := ["wood", "tin", "brick"]
const HP := {"wood": 250.0, "tin": 500.0, "brick": 1000.0}
const MAT := {"wood": "timber", "tin": "tin:grey", "brick": "brick"}
const BASE_COST := {"wood": {"plank": 3, "nails": 1}, "tin": {"tin_sheet": 2, "plank": 1, "nails": 1}, "brick": {"brick": 6}}
const SCALE := {"wall": 1.0, "doorway": 1.0, "window": 1.0, "half": 0.5, "floor": 1.0, "stairs": 2.0, "crate": 1.0, "bench": 1.0, "fire": 1.0, "garden": 1.0}

var kind := "wall"
var tier := "wood"
var hp := 250.0

static func cost(k: String, t: String) -> Dictionary:
	if FIXED.has(k): return FIXED[k]
	var out := {}
	for id in BASE_COST[t]:
		out[id] = maxi(1, int(ceil(float(BASE_COST[t][id]) * float(SCALE[k]))))
	return out

## The boxes a piece is made of: [centre, size, basis]
static func boxes(k: String) -> Array:
	var I := Basis.IDENTITY
	match k:
		"wall": return [[Vector3(0, 1.4, 0), Vector3(3.0, 2.8, 0.15), I]]
		"half": return [[Vector3(0, 0.55, 0), Vector3(3.0, 1.1, 0.15), I]]
		"doorway": return [[Vector3(-1.0, 1.4, 0), Vector3(1.0, 2.8, 0.15), I], [Vector3(1.0, 1.4, 0), Vector3(1.0, 2.8, 0.15), I], [Vector3(0, 2.45, 0), Vector3(1.0, 0.7, 0.15), I]]
		"window": return [[Vector3(0, 0.5, 0), Vector3(3.0, 1.0, 0.15), I], [Vector3(0, 2.4, 0), Vector3(3.0, 0.8, 0.15), I], [Vector3(-1.05, 1.5, 0), Vector3(0.9, 1.0, 0.15), I], [Vector3(1.05, 1.5, 0), Vector3(0.9, 1.0, 0.15), I]]
		"floor": return [[Vector3(0, -0.1, 0), Vector3(3.0, 0.2, 3.0), I]]
		"stairs":
			var ang := atan2(2.8, 6.0)
			return [[Vector3(0, 1.4 - 0.07, 0), Vector3(3.0, 0.14, sqrt(36.0 + 7.84)), Basis(Vector3.RIGHT, -ang)]]
		"crate": return [[Vector3(0, 0.35, 0), Vector3(1.1, 0.7, 0.7), I]]
		"bench": return [[Vector3(0, 0.86, 0), Vector3(1.8, 0.08, 0.75), I], [Vector3(0, 0.42, 0), Vector3(1.7, 0.8, 0.65), I]]
		"fire": return [[Vector3(0, 0.1, 0), Vector3(1.1, 0.2, 1.1), I]]
		"garden": return [[Vector3(0, 0.2, 0), Vector3(2.4, 0.4, 1.2), I]]
	return []

func setup(k: String, t: String, ghost := false) -> void:
	kind = k
	tier = "wood" if FIXED.has(k) else t
	hp = HP[tier]
	collision_layer = 0 if ghost else 1
	collision_mask = 0
	var mat: Material = BuildGen.mat(MAT[tier])
	if k == "fire": mat = BuildGen.mat("concrete_worn")
	if k == "garden": mat = BuildGen.mat("timber")
	for b in boxes(k):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		mi.mesh = bm
		mi.transform = Transform3D(b[2], b[0])
		mi.material_override = mat
		mi.visibility_range_end = 260.0
		add_child(mi)
		if ghost: continue
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		cs.transform = mi.transform
		add_child(cs)
	if ghost: return
	add_to_group("base_pieces")
	if k in ["bench", "fire", "garden"]:
		add_to_group("stations")
		if not has_meta("st"): set_meta("st", {})
		_dress()
	if k == "crate":
		if not has_meta("inv"): set_meta("inv", Items.new_grid(8, 5))
		set_meta("container", "crate")
		set_meta("empty", true)

func tint(c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ch in get_children():
		if ch is MeshInstance3D: ch.material_override = m

func hint() -> String:
	return "%s (%s) %d%%" % [NAMES[kind], tier, int(100.0 * hp / HP[tier])]

## A zombie beating on it
func hit(dmg: float) -> void:
	hp -= dmg
	if hp <= 0.0:
		var a := AudioStreamPlayer3D.new()
		a.stream = Gun.sfx("hammer_nails")
		a.pitch_scale = 0.5
		get_parent().add_child(a)
		a.global_position = global_position
		a.play()
		a.finished.connect(a.queue_free)
		queue_free()

# ---------------------------------------------------------------- work stations
## A station of this kind within r metres of p (craft recipes ask for one)
static func near(tree: SceneTree, kind: String, p: Vector3, r := 3.5) -> BasePiece:
	for b in tree.get_nodes_in_group("stations"):
		if b is BasePiece and (b as BasePiece).kind == kind and (b as BasePiece).global_position.distance_to(p) < r:
			if kind == "fire" and not (b as BasePiece).lit(): continue
			return b
	return null

var _flame: Node3D
var _crop: Node3D

func st() -> Dictionary:
	return get_meta("st", {})

func lit() -> bool:
	return kind == "fire" and float(st().get("lit_until", 0.0)) > Time.get_unix_time_from_system()

## the look of it beyond its boxes: tools on the bench, stones and logs in the fire, soil in the bed
func _dress() -> void:
	match kind:
		"bench":
			for q in [[Vector3(-0.5, 0.95, 0.0), Vector3(0.3, 0.1, 0.2), "steel"], [Vector3(0.4, 0.94, 0.1), Vector3(0.5, 0.08, 0.12), "timber"], [Vector3(0.75, 1.15, -0.3), Vector3(0.08, 0.5, 0.08), "steel"]]:
				_box(q[0], q[1], q[2])
		"fire":
			for i in 9:
				var a := TAU * i / 9.0
				_box(Vector3(cos(a) * 0.48, 0.12, sin(a) * 0.48), Vector3(0.22, 0.2, 0.2), "concrete_worn", a)
			_box(Vector3(0, 0.22, 0), Vector3(0.7, 0.12, 0.12), "timber", 0.6)
			_box(Vector3(0, 0.26, 0), Vector3(0.7, 0.12, 0.12), "timber", -0.7)
		"garden":
			_box(Vector3(0, 0.41, 0), Vector3(2.25, 0.04, 1.05), "dark")
	_refresh()

func _box(p: Vector3, size: Vector3, m: String, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), p)
	mi.material_override = BuildGen.mat(m)
	mi.visibility_range_end = 200.0
	add_child(mi)
	return mi

## flames on or off, crop grown to where it's up to
func _refresh() -> void:
	if kind == "fire":
		var on := lit()
		if on and _flame == null:
			_flame = Node3D.new()
			add_child(_flame)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.6, 0.25)
			l.light_energy = 2.2
			l.omni_range = 9.0
			l.position = Vector3(0, 0.7, 0)
			_flame.add_child(l)
			var pt := CPUParticles3D.new()
			pt.amount = 40
			pt.lifetime = 0.7
			pt.position = Vector3(0, 0.3, 0)
			pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			pt.emission_sphere_radius = 0.18
			pt.direction = Vector3.UP
			pt.spread = 12.0
			pt.gravity = Vector3(0, 1.5, 0)
			pt.initial_velocity_min = 0.6
			pt.initial_velocity_max = 1.4
			pt.scale_amount_min = 0.6
			pt.scale_amount_max = 1.2
			var qm := QuadMesh.new()
			qm.size = Vector2(0.22, 0.3)
			var fm := StandardMaterial3D.new()
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fm.vertex_color_use_as_albedo = true
			qm.material = fm
			pt.mesh = qm
			var g := Gradient.new()
			g.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
			g.set_color(1, Color(0.8, 0.15, 0.02, 0.0))
			pt.color_ramp = g
			_flame.add_child(pt)
		elif not on and _flame != null:
			_flame.queue_free()
			_flame = null
	elif kind == "garden":
		var pl := float(st().get("planted", 0.0))
		if pl <= 0.0:
			if _crop:
				_crop.queue_free()
				_crop = null
			return
		var k := clampf((Time.get_unix_time_from_system() - pl) / GROW, 0.05, 1.0)
		if _crop == null:
			_crop = Node3D.new()
			add_child(_crop)
			for i in 8:
				var mi := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.02; cm.bottom_radius = 0.16; cm.height = 0.5
				mi.mesh = cm
				var gm := StandardMaterial3D.new()
				gm.albedo_color = Color(0.25, 0.5, 0.15)
				mi.material_override = gm
				mi.position = Vector3(-0.85 + (i % 4) * 0.57, 0.43, -0.25 + (i / 4) * 0.5)
				_crop.add_child(mi)
		_crop.scale = Vector3(k, k, k)
		_crop.position.y = 0.43 * (1.0 - k)

func _process(_dt: float) -> void:
	if kind == "fire" or kind == "garden":
		if Engine.get_process_frames() % 30 == 0: _refresh()

## What the look-at menu offers on this station: [label, callable, ok, why]
func menu(p) -> Array:
	var out := []
	match kind:
		"bench":
			out.append(["Use workbench", func(): _craft(p), true, ""])
		"fire":
			if lit():
				out.append(["Cook", func(): _craft(p), true, ""])
				out.append(["Add firewood", func(): _feed(p), p.inv.count("wood") > 0, "You need firewood (chop a tree with an axe)"])
				out.append(["Put it out", func(): _douse(), true, ""])
			else:
				var tool: bool = p.inv.count("lighter") > 0 or p.inv.count("flint") > 0
				out.append(["Light fire", func(): _light(p), tool and p.inv.count("wood") >= 2, "To light it: 2 firewood and a lighter or flint and steel"])
		"garden":
			var pl := float(st().get("planted", 0.0))
			if pl <= 0.0:
				out.append(["Plant seeds", func(): _plant(p), p.inv.count("seeds") > 0, "You need vegie seeds (hardware shops, sheds)"])
			elif Time.get_unix_time_from_system() - pl >= GROW:
				out.append(["Harvest", func(): _harvest(p), true, ""])
			else:
				var left := int((GROW - (Time.get_unix_time_from_system() - pl)) / 60.0) + 1
				out.append(["Growing (%d min)" % left, func(): pass, false, "Not ready yet"])
	return out

func _craft(p) -> void:
	var cu = p.get_tree().current_scene.get("craft_ui")
	if cu: cu.toggle()

func _light(p) -> void:
	if not Settings.creative(): p.inv.take("wood", 2)
	st()["lit_until"] = Time.get_unix_time_from_system() + FIRE_BURN
	_refresh()
	Hearing.emit(get_tree(), global_position, 6.0, "fire", p)

func _feed(p) -> void:
	if not Settings.creative(): p.inv.take("wood", 1)
	st()["lit_until"] = maxf(float(st().get("lit_until", 0.0)), Time.get_unix_time_from_system()) + FIRE_BURN * 0.5

func _douse() -> void:
	st()["lit_until"] = 0.0
	_refresh()

func _plant(p) -> void:
	if not Settings.creative(): p.inv.take("seeds", 1)
	st()["planted"] = Time.get_unix_time_from_system()
	_refresh()

func _harvest(p) -> void:
	st()["planted"] = 0.0
	var left: int = p.inv.add(Items.fresh("veg", randi_range(3, 5)))
	p.inv.add(Items.fresh("seeds", randi_range(1, 2)))
	if left > 0: p._toast("No room for all of it")
	_refresh()
