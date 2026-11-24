class_name AnimalDirector
extends Node
## 0.2.74: the wildlife round you. Fallow deer on the paddocks and at the edge of the bush, pigs in the scrub and
## the wet, rabbits on the short grass: put down 130-320 m off and out of sight, never in town, on a road
## or in water, and taken away again when you're well past. Carcasses stay a while for butchering.

const NEAR := 130.0
const FAR := 320.0
const DROP := 480.0
const WANT := 9
var main
var live: Array = []
var _t := 3.0
var rng := RandomNumberGenerator.new()

func setup(m) -> void:
	main = m
	rng.randomize()

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.player == null or main.veg == null:
		return
	_t = 3.0
	if OS.get_environment("NPC_OFF") != "" or OS.get_environment("ANIMALS_OFF") != "" or (main.forge and main.forge.active):
		return
	if main.net and main.net.online():
		return                     # not shared over LAN yet: keep the world the same for everyone
	var me: Vector3 = main.player.vehicle.global_position if main.player.vehicle else main.player.global_position
	live = live.filter(func(n): return is_instance_valid(n))
	var alive := 0
	for n in live:
		var d: float = (n as Node3D).global_position.distance_to(me)
		if d > DROP or ((n as Animal).dead and d > 300.0):
			(n as Node).queue_free()
		elif not (n as Animal).dead:
			alive += 1
	if alive >= WANT:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	for attempt in 10:
		var a := rng.randf() * TAU
		var p := me + Vector3(cos(a), 0, sin(a)) * rng.randf_range(NEAR, FAR)
		var sp := _species_at(p, cam)
		if sp == "": continue
		var mob: int = {"deer": rng.randi_range(1, 4), "pig": rng.randi_range(2, 4), "rabbit": rng.randi_range(1, 2)}[sp]
		for i in mob:
			var q := p + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-7, 7))
			if Buildings.blocked(q.x, q.z, 1.0): q = p
			q.y = float(main.ground_at(q.x, q.z)) + 0.2
			var an := Animal.new()
			an.setup(main, sp)
			an.name = "%s_%d" % [sp, rng.randi()]
			main.add_child(an)
			an.global_position = q
			live.append(an)
		return

## What lives here (or "" for nothing / not here)
func _species_at(p: Vector3, cam: Camera3D) -> String:
	var h: float = main.height_at(p.x, p.z)
	if is_nan(h) or h < 1.0: return ""
	if Buildings.blocked(p.x, p.z, 6.0): return ""
	if main.veg.road_clearance(p.x, p.z) < 8.0: return ""
	var m: Color = main.veg.sample(p.x, p.z)          # r canopy, g sand, b town, a wet
	var m2: Color = main.veg.sample2(p.x, p.z)        # r short grass, g cane, b water
	if m.b > 0.15 or m2.b > 0.3 or m.g > 0.5: return ""
	if cam:
		var to := (p + Vector3(0, 1, 0)) - cam.global_position
		if (-cam.global_transform.basis.z).dot(to.normalized()) > 0.5 and to.length() < 200.0: return ""
	var w := {"deer": (1.0 - m.r) * (1.0 - m2.g) * 0.7 + m.r * (1.0 - m.r) * 2.4, "pig": m.r * 0.6 + m.a * 0.9,
		"rabbit": m2.r * (1.0 - m.r) * 0.6}
	var tot := 0.0
	for k in w: tot += float(w[k])
	if tot < 0.15: return ""
	var r := rng.randf() * tot
	for k in w:
		r -= float(w[k])
		if r <= 0.0: return k
	return "deer"
