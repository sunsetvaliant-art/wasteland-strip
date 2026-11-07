class_name ZombieDirector
extends Node
## Keeps the country populated with the dead without filling the whole map: a handful of zombies always somewhere
## round you, more along the roads (that's where people were when it happened), in small groups, appearing out of
## sight 70-180 m off and quietly removed once they're well behind you. Never in water, never in a scav camp.

const NEAR := 70.0
const FAR := 180.0
const DROP := 270.0
var target_count := 12
var main
var live: Array = []
var _t := 2.0
var rng := RandomNumberGenerator.new()

func setup(m) -> void:
	main = m
	rng.randomize()

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.player == null:
		return
	_t = 2.0
	if OS.get_environment("NPC_OFF") != "" or (main.forge and main.forge.active):
		return
	if main.net and not main.net.runs_world():
		return                     # on a LAN client the host's zombies come over the network
	# on the host they gather round everyone: spawn round one player at a time, drop only when far from all of them
	var who: Array = main.net.all_players() if main.net and main.net.online() else [main.player]
	var pick = who[rng.randi() % who.size()]
	var me: Vector3 = pick.vehicle.global_position if pick.vehicle else pick.global_position
	live = live.filter(func(n): return is_instance_valid(n))
	var alive := 0
	for n in live:
		var d := 1e9
		for pl in who:
			if is_instance_valid(pl): d = min(d, n.global_position.distance_to(pl.global_position))
		if d > DROP and not n.dead:
			n.free_body()
		elif not n.dead:
			alive += 1
	# more of them about at night
	var want := target_count * (1.0 + 1.2 * (SkyCycle.inst.night if SkyCycle.inst else 0.0))
	if alive >= int(want) * who.size():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	for attempt in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(NEAR, FAR)
		var p := me + Vector3(cos(a), 0, sin(a)) * r
		if not _good(p, cam):
			continue
		var group := rng.randi_range(1, 3)
		for i in group:
			var q := p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
			if Buildings.blocked(q.x, q.z, 0.5): q = p
			q.y = main.ground_at(q.x, q.z) + 0.1
			var z := NPC.new()
			z.kind = "zombie"
			main.add_child(z)
			z.global_position = q
			z.rotation.y = rng.randf() * TAU
			z.home = q
			z.goal = q
			live.append(z)
		return

func _good(p: Vector3, cam: Camera3D) -> bool:
	var h: float = main.height_at(p.x, p.z)
	if h < 1.5:
		return false
	if Buildings.blocked(p.x, p.z, 4.5):
		return false                       # not in someone's walls
	# along the roads mostly, sometimes out in the scrub
	var rc: float = main.veg.road_clearance(p.x, p.z) if main.veg else 10.0
	if rc > 12.0 and rng.randf() < 0.7:
		return false
	if main.camps:
		var c: Dictionary = main.camps.nearest(p)
		if not c.is_empty() and (c.pos as Vector3).distance_to(p) < 70.0:
			return false
	# not where you're looking
	if cam:
		var to := (p + Vector3(0, 1, 0)) - cam.global_position
		if (-cam.global_transform.basis.z).dot(to.normalized()) > 0.35 and to.length() < 150.0:
			return false
	return true
