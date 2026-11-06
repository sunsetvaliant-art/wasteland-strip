class_name ScavCamps
extends Node3D
## Scav camps: fixed sites (same every game), each on flat dry ground a short walk off a road, built only when
## you're near and torn down when you leave. A camp is a fire in the middle, shelters round it facing in, a ring of
## junk barricade with a gap for the gate, clutter, a wreck, something worth taking, and the scavs who live there:
## a sentry at the gate and the rest about the fire. Kill them and the camp stays empty until you've been away.

const BUILD_R := 360.0
const DROP_R := 480.0
const SHELTERS := ["props:hut", "props:quonset", "props:cont1"]
const BARRICADE := ["props:barrier", "props:tyre", "props:drum1", "props:drum2", "ph:wooden_barrels_01", "ph:Barrel_01", "props:wcrate", "ph:modular_chainlink_fence"]
const CLUTTER := ["props:crate", "props:jerry", "props:boxes", "props:propane", "ph:wooden_crate_01", "ph:wooden_crate_02", "ph:plastic_crate_01",
	"ph:trashbag", "ph:Sofa_01", "ph:old_bed_frame", "ph:plastic_monobloc_chair_01", "ph:wooden_picnic_table", "ph:worn_metal_rack",
	"ph:barrel_stove", "ph:cardboard_box_01", "props:tyre", "props:stove", "ph:steel_frame_shelves_01"]
const LOOT := ["slr", "enfield", "rem870", "dbshotgun", "python", "sawnoff"]

var main
var sites: Array = []                  # [{pos, seed, built: Node3D or null, scavs: Array, cleared: bool}]
var _t := 0.0
static var _scenes := {}

var _picked := false
func setup(m) -> void:
	main = m

## Sites: a seeded walk over the country round the pub, keeping spots that are dry, flat-ish, 25-120 m off a
## road and well apart. The first one is a short walk from the pub so there's always one nearby.
func _pick_sites() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	var want := 14
	var tries := 0
	var centre: Vector3 = main.PUB
	while sites.size() < want and tries < 6000:
		tries += 1
		var r: float = 230.0 if sites.is_empty() and tries < 400 else rng.randf_range(400.0, 5500.0)
		if sites.is_empty() and tries < 400: r += rng.randf_range(0.0, 120.0)
		var a := rng.randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * r
		if not _good_site(p):
			continue
		var far := true
		for s in sites:
			if (s.pos as Vector3).distance_to(p) < 700.0:
				far = false
		if not far:
			continue
		p.y = main.height_at(p.x, p.z)
		sites.append({"pos": p, "seed": rng.randi(), "built": null, "scavs": [], "cleared": false})

func _good_site(p: Vector3) -> bool:
	var h: float = main.height_at(p.x, p.z)
	if h < 2.0:
		return false                       # river, swamp, sea
	var spread := 0.0
	for o in [Vector3(14, 0, 0), Vector3(-14, 0, 0), Vector3(0, 0, 14), Vector3(0, 0, -14)]:
		spread = max(spread, abs(main.height_at(p.x + o.x, p.z + o.z) - h))
	if spread > 3.0:
		return false                       # too steep to camp on
	if main.veg == null:
		return true
	# not on the road, but a road within a couple of minutes' walk (the clearance map only reads ~16 m out)
	if main.veg.road_clearance(p.x, p.z) < 15.0:
		return false
	for r in [40.0, 80.0, 120.0]:
		for i in 8:
			var a := TAU * i / 8.0
			if main.veg.road_clearance(p.x + cos(a) * r, p.z + sin(a) * r) < 4.0:
				return r > 30.0
	return false

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.player == null:
		return
	_t = 1.0
	if not _picked:
		_picked = true
		_pick_sites()
		print("CAMPS %d sites, nearest %.0f m from the pub" % [sites.size(), sites[0].pos.distance_to(main.PUB) if sites.size() else -1.0])
	if OS.get_environment("NPC_OFF") != "":
		return
	var me: Vector3 = main.player.vehicle.global_position if main.player.vehicle else main.player.global_position
	for s in sites:
		var d: float = me.distance_to(s.pos)
		if d < BUILD_R and s.built == null:
			_build(s)
		elif d > DROP_R and s.built != null:
			_teardown(s)

## Where the nearest camp is (for the HUD / debugging)
func nearest(p: Vector3) -> Dictionary:
	var best := {}
	var bd := 1e12
	for s in sites:
		var d: float = p.distance_to(s.pos)
		if d < bd:
			bd = d
			best = s
	return best

# ---------------------------------------------------------------- building a camp
func _build(s: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s.seed
	var root := Node3D.new()
	root.name = "ScavCamp"
	main.add_child(root)
	root.global_position = s.pos
	s.built = root
	var c: Vector3 = s.pos
	var gate_a := rng.randf() * TAU                 # the way in
	# the fire
	_place(root, "ph:stone_fire_pit", c, rng.randf() * TAU, true)
	_fire(root, c)
	# shelters round the fire, doors facing in
	var n_sh := rng.randi_range(2, 4)
	for i in n_sh:
		var a := gate_a + PI * 0.35 + (TAU * 0.65) * (float(i) + 0.5) / n_sh + rng.randf_range(-0.15, 0.15)
		var r := rng.randf_range(8.0, 11.0)
		var p := c + Vector3(cos(a), 0, sin(a)) * r
		_place(root, SHELTERS[rng.randi() % SHELTERS.size()], p, -a + PI * 0.5, true)
	# barricade ring with a gap for the gate
	var ring_r := rng.randf_range(15.0, 18.0)
	var steps := int(TAU * ring_r / 2.4)
	for i in steps:
		var a := TAU * float(i) / steps
		if abs(wrapf(a - gate_a, -PI, PI)) < 0.32:
			continue
		if rng.randf() < 0.22:
			continue                                 # gaps where it's fallen down
		var p := c + Vector3(cos(a), 0, sin(a)) * (ring_r + rng.randf_range(-0.6, 0.6))
		_place(root, BARRICADE[rng.randi() % BARRICADE.size()], p, -a + rng.randf_range(-0.3, 0.3), true)
	# junk lying about
	for i in rng.randi_range(10, 16):
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.5, 13.0)
		_place(root, CLUTTER[rng.randi() % CLUTTER.size()], p, rng.randf() * TAU, false)
	# a wreck dragged in for parts
	var cat: Dictionary = Car.catalog()
	var keys: Array = cat.keys()
	var wk: String = keys[rng.randi() % keys.size()]
	var wa := gate_a + PI + rng.randf_range(-0.6, 0.6)
	var wreck := _wreck(wk, c + Vector3(cos(wa), 0, sin(wa)) * rng.randf_range(5.0, 9.0), rng.randf() * TAU)
	if wreck: root.add_child(wreck)
	# something worth the trouble: a gun and rounds by the fire
	var loot_at := c + Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
	_loot(root, LOOT[rng.randi() % LOOT.size()], loot_at)
	# the people who live here
	if not s.cleared:
		var n := rng.randi_range(3, 5)
		for i in n:
			var npc := NPC.new()
			npc.kind = "scav"
			var p: Vector3
			if i == 0:
				p = c + Vector3(cos(gate_a), 0, sin(gate_a)) * (ring_r + 2.5)      # the sentry, on the gate
			else:
				var a := rng.randf() * TAU
				p = c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(3.0, 7.0)
			p.y = main.ground_at(p.x, p.z) + 0.1
			main.add_child(npc)
			npc.global_position = p
			npc.home = c if i > 0 else p
			npc.goal = p
			npc.patrol_r = 12.0 if i > 0 else 4.0
			npc.face_dir = (p - c).normalized() if i == 0 else (c - p).normalized()
			s.scavs.append(npc)

func _teardown(s: Dictionary) -> void:
	var alive := 0
	for n in s.scavs:
		if is_instance_valid(n):
			if not n.dead: alive += 1
			n.free_body()
	s.cleared = s.scavs.size() > 0 and alive == 0 and false   # they come back once you've been gone
	s.scavs = []
	if is_instance_valid(s.built):
		s.built.queue_free()
	s.built = null

func _scene(spec: String) -> PackedScene:
	if _scenes.has(spec):
		return _scenes[spec]
	var kind := spec.get_slice(":", 0)
	var k := spec.get_slice(":", 1)
	var path := "res://assets/props/%s.glb" % k if kind == "props" else "res://assets/ph/world/%s/%s.gltf" % [k, k]
	var ps: PackedScene = load(path) if ResourceLoader.exists(path) else null
	_scenes[spec] = ps
	return ps

## A prop, sat on the ground, solid. Big ones are static; small ones can be knocked about.
func _place(root: Node3D, spec: String, p: Vector3, yaw: float, fixed: bool) -> void:
	var ps := _scene(spec)
	if ps == null:
		return
	var vis: Node3D = ps.instantiate()
	var bb := Gun._aabb(vis)
	var body: CollisionObject3D = StaticBody3D.new() if fixed or bb.size.length() > 3.0 else RigidBody3D.new()
	body.add_child(vis)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bb.size.max(Vector3(0.05, 0.05, 0.05))
	cs.shape = bs
	cs.position = bb.get_center()
	body.add_child(cs)
	if body is RigidBody3D:
		(body as RigidBody3D).mass = clamp(bb.size.x * bb.size.y * bb.size.z * 150.0, 3.0, 400.0)
		body.add_to_group("physgun")
	root.add_child(body)
	var gy: float = main.ground_at(p.x, p.z)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy - bb.position.y - 0.02, p.z))

func _fire(root: Node3D, c: Vector3) -> void:
	var y: float = main.ground_at(c.x, c.z)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.22)
	l.omni_range = 14.0
	l.light_energy = 2.5
	l.shadow_enabled = OS.get_environment("NO_SHADOW_LIGHTS") == ""
	root.add_child(l)
	l.global_position = Vector3(c.x, y + 0.9, c.z)
	var fl := l.create_tween().set_loops()
	fl.tween_property(l, "light_energy", 1.8, 0.13)
	fl.tween_property(l, "light_energy", 2.9, 0.09)
	fl.tween_property(l, "light_energy", 2.2, 0.17)
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.9
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Gun._flash_tex()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.8, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
	grad.set_color(1, Color(0.6, 0.12, 0.02, 0.0))
	p.color_ramp = grad
	root.add_child(p)
	p.global_position = Vector3(c.x, y + 0.35, c.z)
	var a := AudioStreamPlayer3D.new()
	root.add_child(a)
	a.global_position = Vector3(c.x, y + 0.5, c.z)

func _wreck(kind: String, p: Vector3, yaw: float) -> Node3D:
	var d: Dictionary = Car.catalog().get(kind, {})
	if d.is_empty():
		return null
	var ps: PackedScene = load("res://assets/vehicles/%s.glb" % d.glb)
	if ps == null:
		return null
	var sb := StaticBody3D.new()
	var b: Node3D = ps.instantiate()
	b.rotation_degrees.y = -90
	sb.add_child(b)
	var bb := Gun._aabb(sb)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bb.size
	cs.shape = bs
	cs.position = bb.get_center()
	sb.add_child(cs)
	var gy: float = main.ground_at(p.x, p.z)
	# no wheels, sat on its belly, a bit cocked over
	sb.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, randf_range(-0.06, 0.06)), Vector3(p.x, gy - bb.position.y - 0.25, p.z))
	return sb

func _loot(root: Node3D, gk: String, p: Vector3) -> void:
	var rb := RigidBody3D.new()
	rb.mass = 4.0
	rb.collision_layer = Ragdoll.layer_bits()
	rb.collision_mask = 1
	var g := Gun.new()
	rb.add_child(g)
	g.setup(gk, null)
	g.set_process(false)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.1, 0.15, float(g.def.len))
	cs.shape = bs
	rb.add_child(cs)
	rb.add_to_group("pickups")
	rb.set_meta("gun", gk)
	rb.set_meta("ammo", int(g.def.mag) * 2)
	root.add_child(rb)
	var gy: float = main.ground_at(p.x, p.z)
	rb.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5), Vector3(p.x, gy + 0.3, p.z))
