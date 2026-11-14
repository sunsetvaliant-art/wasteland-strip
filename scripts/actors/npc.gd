class_name NPC
extends CharacterBody3D
## Zombies and scavs.
##   Zombie: slow, tanky, arms out, shambling. Wanders until it sees you or hears something (gunfire, engines,
##           running), then comes for you and swings. Headshots drop it; anything less and it keeps coming, minus bits.
##   Scav:   armed and wary. Patrols its camp. Seeing you fills a suspicion meter (crouching, distance and cover slow it):
##           "?" it stops and stares, then comes to look; "!" it blows the whistle, every scav in earshot comes running,
##           and they fight: keep their distance, shoot in bursts, close in with shotguns, hunt where you were last seen.
## Both ragdoll when they die, lose limbs to big hits, and turn to paste under a car.

const ZOMBIE_MODELS := ["zombie_hollow"]      # the Meshy walker only (the Sketchfab ones brought hidden collision with them)
const ZOMBIE_SETS := ["zombie_a", "zombie_b", "zombie_c"]
const SCAV_MODELS := ["scav_hooded", "scav_2"]
const SCAV_GUNS := ["slr", "enfield", "rem870", "python", "dbshotgun", "sawnoff", "hunter", "magnum45"]
const LAYER := 1 << 2

var kind := "zombie"
var model_key := ""
var rig: Rig
var shape: CollisionShape3D
var hp := 160.0
var dead := false
var state := "idle"
var home := Vector3.ZERO
var goal := Vector3.ZERO
var goal_t := 0.0
var face_dir := Vector3.FORWARD
var move_speed := 0.0
var last_seen := Vector3.ZERO
var lost_t := 0.0
var suspicion := 0.0
var vis := 0.0
var see_t := 0.0
var react_t := 0.0
var attack_t := 0.0
var swing_t := -1.0
var stagger := 0.0
var _mask0 := 1 | (1 << 2)
var knock_t := 0.0             # kicked: flying backwards, not walking
var breed := "walker"          # walker, runner (quick and frail), brute (slow, huge, hits like a truck)
var hit_dmg := 1.0
var groan_t := 3.0
var avoid := Vector3.ZERO
var avoid_t := 0.0
var limp := 0.0
var gait := 1.0
var gun: Gun
var anim_set := "unarmed"
var swing_len := 1.2
var burst := 0
var pausing := false
var patrol_r := 22.0
var look_turn := 0.0
var burst_t := 0.0
var ragdoll: Ragdoll
var label: Label3D
var voice: AudioStreamPlayer3D
var reach_l: Node3D
var reach_r: Node3D
var corpse_dmg := {}
var main
var player                 # the nearest player (you, or someone on the LAN when you're hosting)
var puppet := false        # LAN client: a copy of the host's NPC that follows its snapshots
var net_id := 0
var puppet_gun := ""
var _net_pos := Vector3.ZERO
var _net_vel := Vector3.ZERO
var _net_yaw := 0.0
var _pick_t := 0.0

func _ready() -> void:
	main = get_tree().current_scene
	player = main.player if main and "player" in main else null
	add_to_group("npcs")
	add_to_group(kind + "s")
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	floor_max_angle = deg_to_rad(55)
	floor_snap_length = 0.5
	shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.875
	add_child(shape)
	rig = Rig.new()
	add_child(rig)
	if model_key == "":
		model_key = (ZOMBIE_MODELS if kind == "zombie" else SCAV_MODELS).pick_random()
	rig.load_model(model_key)
	voice = AudioStreamPlayer3D.new()
	voice.position.y = 1.6
	voice.unit_size = 5.0
	voice.max_distance = 70.0
	if kind == "zombie":
		# zombies were far too loud: quieter, shorter reach, and the groans a bit less often
		voice.unit_size = 2.2
		voice.volume_db = -9.0
		voice.max_distance = 35.0
	add_child(voice)
	home = global_position
	goal = home
	face_dir = -global_transform.basis.z
	if kind == "zombie":
		_setup_zombie()
	else:
		_setup_scav()

func _setup_zombie() -> void:
	hp = randf_range(150.0, 210.0)
	anim_set = ZOMBIE_SETS.pick_random()
	# a little grey-green on the real zombie skins; a lot on a survivor who's turned
	var strong: bool = not model_key.begins_with("zombie")
	rig.tint(Color(0.74, 0.82, 0.68) if strong else Color(0.92, 0.95, 0.9), 0.95)
	rig.mods.head_tilt = Vector2(randf_range(-0.2, 0.2), randf_range(-0.12, 0.12))
	gait = randf_range(0.8, 1.15)
	limp = randf_range(0.0, 0.4)
	var roll := randf()
	if roll < 0.14:
		breed = "runner"
		anim_set = "zombie_c"
		hp *= 0.6
		gait = randf_range(1.15, 1.35)
		limp = 0.0
	elif roll < 0.2:
		breed = "brute"
		anim_set = "zombie_a"
		hp *= 2.6
		gait = 0.8
		hit_dmg = 1.9
		scale = Vector3.ONE * 1.16
	rig.anim.speed_scale = 1.0

func _setup_scav() -> void:
	hp = 100.0
	gun = Gun.new()
	add_child(gun)
	gun.setup(puppet_gun if puppet_gun != "" else SCAV_GUNS.pick_random(), self)
	gun.reserve = 9999
	gun.excludes = [get_rid()]
	gun.top_level = true
	label = Label3D.new()
	label.position.y = 2.15
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 72
	label.outline_size = 14
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0009
	add_child(label)
	state = "patrol"

# ---------------------------------------------------------------- brain
func _physics_process(dt: float) -> void:
	if dead:
		return
	if down_t > 0.0:
		_down_tick(dt)
		return
	if rise_t > 0.0:
		# coming back up off the floor: stiff as a board, then it's after you again
		rise_t -= dt
		rig.rotation.x = -PI / 2 * smoothstep(0.0, 1.0, clampf(rise_t / 0.9, 0.0, 1.0))
		velocity = Vector3.ZERO
		if rise_t <= 0.0:
			rig.rotation.x = 0.0
			stagger = 0.4
		return
	if puppet:
		_puppet_step(dt)
		return
	_pick_t -= dt
	if _pick_t <= 0.0 and main and main.net and main.net.online():
		_pick_t = 0.5
		var best = main.player
		var bd := 1e12
		for pl in main.net.all_players():
			if is_instance_valid(pl) and not pl.dead:
				var dd := global_position.distance_squared_to(pl.global_position)
				if dd < bd:
					bd = dd
					best = pl
		player = best
	var far: bool = player == null or global_position.distance_to(player.global_position) > 160.0
	_check_cars()
	if dead:
		return
	if not far:
		_perceive(dt)
	_think(dt)
	_move(dt)
	_animate(dt)

## What can it see of you right now (0..1)
func _perceive(dt: float) -> void:
	see_t -= dt
	if see_t > 0.0:
		return
	see_t = 0.15
	vis = 0.0
	var p = player
	if p == null or p.dead:
		return
	var tgt: Vector3 = p.global_position + Vector3(0, 1.2 if not p.crouching else 0.8, 0)
	var in_car: bool = p.vehicle != null
	if in_car:
		tgt = p.vehicle.global_position + Vector3(0, 1.0, 0)
	var eye := global_position + Vector3(0, 1.6, 0)
	var to := tgt - eye
	var d := to.length()
	var rng := 32.0 if kind == "zombie" else 75.0
	if in_car: rng *= 2.0
	if d > rng:
		return
	var fwd := face_dir.normalized()
	var ang := rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z).normalized()))
	var fov := 140.0 if kind == "zombie" else 150.0
	var close := d < 3.5
	if ang > fov * 0.5 and not close:
		return
	var ex: Array = [get_rid(), p.get_rid()]
	if in_car: ex.append(p.vehicle.get_rid())
	var q := PhysicsRayQueryParameters3D.create(eye, tgt, 1, ex)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	var stance := 1.0
	if p.crouching: stance = 0.38
	elif Input.is_action_pressed("sprint") and p.velocity.length() > 3.0: stance = 1.35
	if in_car: stance = 2.2
	if p.velocity.length() < 0.3 and not in_car: stance *= 0.7      # keeping still helps
	var periph: float = 1.0 if ang < fov * 0.3 else 0.55
	vis = clamp(pow(1.0 - d / rng, 0.6) * stance * periph, 0.0, 1.0)
	if close: vis = max(vis, 0.8)

func hear(pos: Vector3, loud: float, what: String, source: Node) -> void:
	if dead:
		return
	if kind == "zombie":
		if state != "chase" and loud > 0.05:
			state = "investigate"
			goal = pos + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			goal_t = 25.0
	else:
		if what == "alarm" or (what == "gunshot" and source is NPC and source.kind == "scav"):
			# a mate's in a fight: go help
			if state != "combat":
				suspicion = max(suspicion, 0.85)
				last_seen = pos
				state = "search"
				lost_t = 0.0
				goal = pos
				goal_t = 30.0
		elif what == "gunshot" or loud > 0.4:
			suspicion = max(suspicion, 0.4 + loud * 0.5)
			if state in ["patrol", "suspicious"]:
				state = "search"
				goal = pos
				goal_t = 20.0
				last_seen = pos
		elif loud > 0.15 and state == "patrol":
			suspicion = max(suspicion, 0.36)
			last_seen = pos
			state = "suspicious"

func _think(dt: float) -> void:
	attack_t = max(attack_t - dt, 0.0)
	stagger = max(stagger - dt, 0.0)
	goal_t -= dt
	if kind == "zombie":
		_think_zombie(dt)
	else:
		_think_scav(dt)

func _target_pos() -> Vector3:
	if player == null:
		return global_position
	return player.vehicle.global_position if player.vehicle else player.global_position

func _think_zombie(dt: float) -> void:
	groan_t -= dt
	if groan_t <= 0.0:
		groan_t = randf_range(7.0, 16.0) if state != "chase" else randf_range(3.5, 7.0)
		_say("zgroan_%d" % (randi() % 4))
	if vis > 0.12 and player and not player.dead:
		if state != "chase" and randf() < 0.6:
			rig.act(Rig.SETS[anim_set].get("spot", ""), 1.2)
			stagger = 1.2
			_say("zattack")
			# the scream brings the others
			for n in get_tree().get_nodes_in_group("zombies"):
				if n != self and is_instance_valid(n) and not n.dead and n.state != "chase" and n.global_position.distance_to(global_position) < 28.0:
					n.state = "investigate"
					n.goal = _target_pos() + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
					n.goal_t = 25.0
		state = "chase"
		last_seen = _target_pos()
		lost_t = 0.0
	match state:
		"idle":
			move_speed = 0.0
			if goal_t <= 0.0:
				state = "wander"
				goal = home + Vector3(randf_range(-18, 18), 0, randf_range(-18, 18))
				goal_t = randf_range(8.0, 20.0)
		"wander", "investigate":
			var zs: Dictionary = Rig.SETS[anim_set]
			move_speed = float(zs.get("wander_speed", 0.55)) * gait if state == "wander" else float(zs.get("wander_speed", 0.55)) * 1.4 * gait
			if _flat_dist(goal) < 1.5 or goal_t <= 0.0:
				state = "idle"
				goal_t = randf_range(3.0, 9.0)
		"chase":
			var tp := _target_pos()
			# you went into a building it was chasing you to: it knows where you went and follows you in, through
			# the doors and up the stairs (Buildings.route), for a good while before it gives up
			var inside := Buildings.inst != null and Buildings.inst.lot_at(tp, 0.5) >= 0
			if vis > 0.0:
				last_seen = tp
				lost_t = 0.0
			else:
				lost_t += dt
				if inside and _flat_dist(tp) < 45.0 and lost_t < 40.0:
					last_seen = tp
			goal = last_seen
			var d := _flat_dist(tp)
			var reach := 2.4 if (player and player.vehicle) else 1.35
			if d < reach and vis > 0.0:
				move_speed = 0.0
				face_dir = (tp - global_position).normalized()
				if attack_t <= 0.0:
					var clip: String = Rig.SETS[anim_set].get("attack", "Punch_Forward_with_Both_Fists")
					swing_len = rig.act(clip, 1.3)
					attack_t = max(swing_len, 1.2) + 0.3
					swing_t = 0.0
					_say("zattack")
			else:
				var zs: Dictionary = Rig.SETS[anim_set]
				move_speed = float(zs.get("chase_speed", 1.25)) * gait
				if d < 6.0 and zs.has("close_speed"):
					move_speed = float(zs.close_speed) * gait      # the last few metres at a run
				# after dark they're quicker and they don't give up
				if SkyCycle.inst and SkyCycle.inst.night > 0.5:
					move_speed *= 1.3
				if lost_t > (40.0 if inside else 12.0):
					state = "wander"
					goal_t = 15.0
	# the swing lands partway through the punch
	if swing_t >= 0.0:
		swing_t += dt
		if swing_t > swing_len * 0.45:
			swing_t = -1.0
			if player and not player.dead and _flat_dist(_target_pos()) < 2.0 and player.vehicle == null:
				player.take_damage(randf_range(14.0, 22.0) * hit_dmg, global_position)
				# sometimes it gets hold of you
				if player.get("melee") and randf() < (0.5 if breed == "brute" else 0.22): player.melee.grabbed(self)
			elif player and player.vehicle and _flat_dist(_target_pos()) < 3.0:
				_say("hit_metal")
				player.vehicle.apply_central_impulse((player.vehicle.global_position - global_position).normalized() * 120.0)

func _think_scav(dt: float) -> void:
	# suspicion: seeing you fills it, losing you drains it
	if vis > 0.0:
		suspicion = min(suspicion + vis * (1.7 if state in ["search", "combat"] else 1.1) * dt, 1.2)
		last_seen = _target_pos()
	else:
		suspicion = max(suspicion - dt * (0.06 if state == "combat" else 0.12), 0.0)
	if suspicion >= 1.0 and state != "combat":
		_alert()
	match state:
		"patrol":
			# walk to a spot round the camp, or stop a while and have a look about
			if goal_t <= 0.0 or (not pausing and _flat_dist(goal) < 1.2):
				pausing = randf() < 0.45
				if pausing:
					goal = global_position
					goal_t = randf_range(3.0, 9.0)
					look_turn = randf_range(-1.2, 1.2)
				else:
					goal = home + Vector3(randf_range(-patrol_r, patrol_r), 0, randf_range(-patrol_r, patrol_r))
					goal_t = randf_range(10.0, 25.0)
			move_speed = 0.0 if pausing else 1.3
			if pausing:
				face_dir = Basis(Vector3.UP, look_turn * dt * 0.4) * face_dir
			if suspicion > 0.35:
				state = "suspicious"
				goal_t = 4.0
				rig.act("Alert_Quick_Turn_Right", 1.4)
		"suspicious":
			move_speed = 0.0
			face_dir = (last_seen - global_position).normalized()
			if goal_t <= 0.0:
				if suspicion > 0.45:
					state = "search"
					goal = last_seen
					goal_t = 20.0
				elif suspicion < 0.15:
					state = "patrol"
		"search":
			move_speed = 2.0 if suspicion > 0.6 else 1.3
			if _flat_dist(goal) < 2.0:
				move_speed = 0.0
				face_dir = Basis(Vector3.UP, sin(Time.get_ticks_msec() * 0.0012) * 1.6) * face_dir
			if goal_t <= 0.0:
				state = "patrol"
				suspicion = min(suspicion, 0.5)
				goal = home
		"combat":
			_combat(dt)
	if label:
		if state == "combat":
			label.text = "!"
			label.modulate = Color(1, 0.2, 0.15)
		elif suspicion > 0.12:
			label.text = "?"
			label.modulate = Color(1, 0.85, 0.2, clamp(suspicion * 1.5, 0.3, 1.0))
		else:
			label.text = ""

func _alert() -> void:
	state = "combat"
	react_t = randf_range(0.5, 0.9)
	suspicion = 1.0
	lost_t = 0.0
	# blow the whistle: everyone in earshot comes
	voice.stream = Gun.sfx("whistle")
	voice.unit_size = 25.0
	voice.max_distance = 300.0
	voice.play()
	Hearing.emit(get_tree(), global_position, 140.0, "alarm", self)

func _combat(dt: float) -> void:
	var tp := _target_pos()
	var d := _flat_dist(tp)
	var aim_pt: Vector3 = tp + Vector3(0, 1.25 if player and not player.crouching else 0.85, 0)
	if player and player.vehicle: aim_pt = player.vehicle.global_position + Vector3(0, 1.1, 0)
	if vis > 0.0:
		lost_t = 0.0
		last_seen = tp
		face_dir = (tp - global_position).normalized()
		var want_lo := 8.0 if gun.def.pellets == 1 else 3.0
		var want_hi: float = min(float(gun.def.range) * 0.6, 45.0)
		if d > want_hi:
			goal = tp
			move_speed = 2.4
		elif d < want_lo:
			goal = global_position + (global_position - tp).normalized() * 4.0
			move_speed = 1.6
		else:
			# side-step every so often so it's not a shooting gallery
			if goal_t <= 0.0:
				var side := face_dir.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				goal = global_position + side * randf_range(2.0, 5.0)
				goal_t = randf_range(2.0, 4.0)
			move_speed = 1.2 if _flat_dist(goal) > 0.8 else 0.0
		react_t -= dt
		if react_t <= 0.0 and d < float(gun.def.range) * 0.9:
			_shoot(aim_pt, d)
	else:
		lost_t += dt
		goal = last_seen
		move_speed = 2.2
		if lost_t > 7.0:
			state = "search"
			goal_t = 18.0
			suspicion = 0.8
	if gun.ammo <= 0 and gun.reloading <= 0.0:
		gun.start_reload()

func _shoot(aim_pt: Vector3, d: float) -> void:
	burst_t -= get_physics_process_delta_time()
	if burst_t > 0.0:
		return
	var semi: bool = gun.def.action in ["semi", "revolver"]
	var pspeed: float = player.velocity.length() if player else 0.0
	var spread := 0.014 + d * 0.00035 + pspeed * 0.004
	if player and player.crouching: spread *= 1.2
	var o: Vector3 = gun.muzzle.global_position
	if gun.fire(o, (aim_pt - o).normalized(), spread):
		burst += 1
		if semi and burst < randi_range(2, 4):
			burst_t = float(gun.def.interval) + randf_range(0.1, 0.35)
		else:
			burst = 0
			burst_t = randf_range(0.9, 2.2)

# ---------------------------------------------------------------- moving
func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()

var _route: Array = []
var _route_t := 0.0
var _stuck_t := 0.0

## Can we walk straight to q (nothing solid at knee height in between; doors count as clear, they push open)?
func _clear_to(q: Vector3) -> bool:
	# a metre up at both ends: clears beds and chairs, and runs parallel to a flight of stairs, but not a wall
	var o := global_position + Vector3(0, 1.0, 0)
	var t := q + Vector3(0, 1.0, 0)
	var rq := PhysicsRayQueryParameters3D.create(o, t, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(rq)
	return hit.is_empty() or hit.collider is BuildDoor

func _move(dt: float) -> void:
	# through a building's doors and up its stairs, when you're inside one (or it is)
	var g := goal
	if Buildings.inst and state in ["chase", "investigate", "combat"]:
		_route_t -= dt
		if _route_t <= 0.0:
			_route_t = 0.6
			_route = Buildings.inst.route(global_position, goal)
			# a fresh route starts back at the first door: skip what's already behind us (up to the waypoint we're
			# nearest, and that one too if we're on it), so we don't turn round to touch it again
			var near_i := -1; var near_d := 1e9
			for k in _route.size():
				var q: Vector3 = _route[k]
				var dd := Vector2(q.x - global_position.x, q.z - global_position.z).length() + absf(q.y - global_position.y) * 0.5
				if dd < near_d: near_d = dd; near_i = k
			# ... but only one we can actually walk straight to (the nearest can be on the other side of a wall)
			if near_i > 0 and (not _clear_to(_route[near_i]) or absf((_route[near_i] as Vector3).y - global_position.y) > 0.6): near_i = 0; near_d = 1e9
			if near_i > 0 or (near_i == 0 and near_d < 1.0):
				_route = _route.slice(near_i + (1 if near_d < 1.0 else 0))
		while not _route.is_empty():
			var q: Vector3 = _route[0]
			var here := Vector2(global_position.x, global_position.z)
			var qa := Vector2(q.x, q.z)
			var passed := false
			if _route.size() > 1:
				# already between this waypoint and the next (on the stairs past the bottom step, through the door)
				var qb := Vector2((_route[1] as Vector3).x, (_route[1] as Vector3).z)
				var seg := qb - qa
				var tt := clampf((here - qa).dot(seg) / maxf(seg.length_squared(), 0.01), 0.0, 1.0)
				var want_y := lerpf(q.y, (_route[1] as Vector3).y, tt)      # on a flight we should have climbed this far
				passed = seg.length() > 0.3 and (here - qa).dot(seg) > 0.0 and here.distance_to(qa) < seg.length() + 0.5 \
					and global_position.y > want_y - 0.8 and absf(seg.normalized().cross(here - qa)) < 0.9 and _clear_to(_route[1])
			if (here.distance_to(qa) < 0.9 and absf(q.y - global_position.y) < 1.6) or passed:
				_route.remove_at(0)
			else:
				break
		if not _route.is_empty():
			g = _route[0]
	var to := g - global_position
	to.y = 0.0
	var spd := move_speed
	if stagger > 0.0 or swing_t >= 0.0: spd = 0.0
	knock_t = maxf(knock_t - dt, 0.0)
	if gun and gun.reloading > 0.0: spd = min(spd, 1.0)
	var dir := Vector3.ZERO
	# wanting to move but not getting anywhere (a chair, a bed, the corner of a wall): steer round it for a bit
	if spd > 0.0 and to.length() > 0.4 and Vector2(velocity.x, velocity.z).length() < spd * 0.25:
		_stuck_t += dt
	else:
		_stuck_t = maxf(_stuck_t - dt * 2.0, 0.0)
	# a doorstep or the bottom of a flight of stairs left up off the ground on a slope: clamber up onto it
	var indoors := state == "chase" and Buildings.inst != null and Buildings.inst.lot_at(global_position, 0.3) >= 0
	if _stuck_t > 0.4 and (not _route.is_empty() or indoors):
		var q: Vector3 = _route[0] if not _route.is_empty() else g
		var dy := q.y - global_position.y
		if dy > 0.25 and dy < 2.2 and Vector2(q.x - global_position.x, q.z - global_position.z).length() < 1.8 and _clear_to(q):
			var fl := Vector3(q.x - global_position.x, 0, q.z - global_position.z)
			global_position += fl.limit_length(0.6)
			global_position.y = q.y + 0.08
			velocity = Vector3.ZERO
			_stuck_t = 0.0
		# wedged on furniture in a hall (the way's clear above waist height, so it isn't a wall): shove past it
		elif _stuck_t > 1.5 and _clear_to(q) and absf(dy) < 0.5:
			var fl := Vector3(q.x - global_position.x, 0, q.z - global_position.z)
			global_position += fl.limit_length(0.35)
			_stuck_t = 1.0
	if spd > 0.0 and to.length() > 0.4:
		dir = to.normalized()
		dir = _steer(dir, dt, to.length() if not _route.is_empty() and _stuck_t < 0.6 else -1.0)
		if kind == "zombie" or state != "combat" or vis <= 0.0:
			face_dir = face_dir.slerp(dir, clamp(dt * 3.0, 0.0, 1.0)) if face_dir.length() > 0.1 else dir
	if kind == "zombie" and limp > 0.0:
		spd *= 1.0 - limp * 0.5 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006 * gait))
	var grip := 1.5 if knock_t > 0.0 else 8.0
	velocity.x = move_toward(velocity.x, dir.x * spd, grip * dt)
	velocity.z = move_toward(velocity.z, dir.z * spd, grip * dt)
	# is there ground under it (terrain collision only exists near you)? if not, walk on the heightmap
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.DOWN * 3.0, 1, [get_rid()])
	if space.intersect_ray(q).is_empty() and main and main.has_method("height_at"):
		global_position.x += velocity.x * dt
		global_position.z += velocity.z * dt
		global_position.y = main.height_at(global_position.x, global_position.z)
		velocity.y = 0.0
	else:
		if not is_on_floor():
			velocity.y -= 9.8 * dt
		StepUp.slide(self)
		# leaning on a shut door pushes it open
		for ci in get_slide_collision_count():
			var col := get_slide_collision(ci).get_collider()
			if col is BuildDoor:
				(col as BuildDoor).push_open(global_position)
			elif col is Boards and kind == "zombie":
				(col as Boards).hit(dt * 9.0)          # beating on the planks
			elif col is BasePiece and kind == "zombie":
				(col as BasePiece).hit(dt * 9.0)       # ... or on what you built
	if face_dir.length() > 0.1:
		var yaw := atan2(-face_dir.x, -face_dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, clamp(dt * 6.0, 0.0, 1.0))

## Whiskers: if something's in the way, pick the clearer side and hold it for a moment
## to_wp >= 0: following a building route, the next waypoint is that far: only look that far ahead (a doorway's
## frame and the walls beyond it aren't in the way), and walk into a shut door rather than round it (it pushes open)
func _steer(dir: Vector3, dt: float, to_wp := -1.0) -> Vector3:
	avoid_t -= dt
	if to_wp >= 0.0:
		avoid_t = 0.0
	if avoid_t > 0.0:
		return (dir + avoid * 1.5).normalized()
	var space := get_world_3d().direct_space_state
	var o := global_position + Vector3(0, 0.6, 0)
	var look := 1.6 if to_wp < 0.0 else clampf(to_wp - 0.1, 0.2, 1.6)
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * look, 1 | LAYER, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (player and hit.collider == player) or hit.collider is BuildDoor or hit.collider is Boards:
		return dir
	if to_wp >= 0.0:
		return dir          # on a route the waypoints already go round things; sliding along the wall does the rest
	for a in [0.9, -0.9, 1.6, -1.6]:
		var d2 := dir.rotated(Vector3.UP, a)
		var q2 := PhysicsRayQueryParameters3D.create(o, o + d2 * 1.8, 1 | LAYER, [get_rid()])
		if space.intersect_ray(q2).is_empty():
			avoid = d2
			avoid_t = 0.8
			return d2
	return dir

var ready_t := 0.0
func _animate(dt: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var lv := global_transform.basis.inverse() * hv
	var ang := atan2(-lv.x, -lv.z)
	var spd := hv.length()
	if kind == "zombie":
		rig.locomote(anim_set, spd, false, ang * 0.3)
		return
	# scavs: rifle set when they've got a long gun, and the gun in their hands the same way you hold yours
	var pistol: bool = gun != null and gun.def.get("pistol", false)
	rig.locomote("unarmed" if (pistol or gun == null) else "rifle", spd, false, ang)
	if gun == null:
		return
	var up := state == "combat" or (state == "suspicious" and suspicion > 0.6)
	ready_t = move_toward(ready_t, 1.0 if up else 0.0, dt * 3.0)
	var eye := rig.head_position() + global_transform.basis * Vector3(0, 0.07, -0.08)
	var look := global_transform.basis
	if player and state in ["combat", "suspicious", "search"]:
		var tp := _target_pos() + Vector3(0, 1.2 if not (player and player.crouching) else 0.8, 0)
		if player.vehicle: tp = player.vehicle.global_position + Vector3(0, 1.0, 0)
		var to := (tp - eye)
		var local := global_transform.basis.inverse() * to
		var yaw_off: float = clamp(atan2(-local.x, -local.z), -0.9, 0.9)
		var pit: float = clamp(atan2(local.y, Vector2(local.x, local.z).length()), -0.8, 0.8)
		rig.mods.look_yaw = lerpf(rig.mods.look_yaw, yaw_off, dt * 6.0)
		rig.mods.look_pitch = lerpf(rig.mods.look_pitch, pit * 0.85, dt * 6.0)
		look = global_transform.basis * Basis(Vector3.UP, yaw_off) * Basis(Vector3.RIGHT, pit)
	else:
		rig.mods.look_yaw = lerpf(rig.mods.look_yaw, 0.0, dt * 3.0)
		rig.mods.look_pitch = lerpf(rig.mods.look_pitch, -0.1, dt * 3.0)
	gun.global_transform = WeaponHold.place(gun, Transform3D(look.orthonormalized(), eye), {"low": 1.0 - ready_t, "reload": gun.reload_phase(), "ads": 0.0})
	WeaponHold.hands(rig, gun, global_transform.basis)

func _say(n: String) -> void:
	if voice.playing and n.begins_with("zgroan"):
		return
	voice.stream = Gun.sfx(n)
	voice.pitch_scale = randf_range(0.85, 1.12)
	voice.play()

# ---------------------------------------------------------------- getting hurt
const SEVER_AT := {"head": 95.0, "l_upperarm": 42.0, "r_upperarm": 42.0, "l_forearm": 32.0, "r_forearm": 32.0,
	"l_thigh": 55.0, "r_thigh": 55.0, "l_shin": 42.0, "r_shin": 42.0}

## LAN client: where the host says this one is
func net_target(pos: Vector3, yaw: float, vel: Vector3, action: String) -> void:
	_net_pos = pos
	_net_yaw = yaw
	_net_vel = vel
	if action != "" and rig.action == "":
		rig.act(action, 1.2 if kind == "zombie" else 1.0)

func _puppet_step(dt: float) -> void:
	if _net_pos == Vector3.ZERO:
		return
	if global_position.distance_to(_net_pos) > 8.0:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos + _net_vel * 0.05, clamp(dt * 8.0, 0.0, 1.0))
	velocity = _net_vel
	face_dir = Vector3(sin(_net_yaw), 0, cos(_net_yaw))
	rotation.y = lerp_angle(rotation.y, atan2(-face_dir.x, -face_dir.z), clamp(dt * 8.0, 0.0, 1.0))
	_animate(dt)

func take_hit(parts: Dictionary, dir: Vector3, point: Vector3, force: float, attacker: Node) -> void:
	if dead:
		return
	if puppet:
		# the host does the damage; here it just flinches
		if main and main.net: main.net.hit_npc(self, parts, dir, point, force)
		stagger = 0.2
		return
	var total := 0.0
	var cuts: Array = []
	var killing := false
	for part in parts:
		var dmg: float = parts[part]
		total += dmg
		var need: float = SEVER_AT.get(part, 1e9)
		if kind == "zombie" and part == "head": need = 70.0
		if dmg >= need and not rig.mods.crushed.has(rig.bone(Rig.HIT_BONES[part])):
			cuts.append(part)
		if part == "head" and dmg >= (60.0 if kind == "zombie" else 40.0):
			killing = true
	hp -= total
	var main_part: String = parts.keys()[0]
	for c in cuts:
		if c == "head" or c.ends_with("thigh") or c.ends_with("shin"):
			killing = true
	if hp <= 0.0 or killing:
		die(dir * force * 12.0, point, main_part, cuts)
		return
	# still up: a zombie loses an arm and keeps walking
	for c in cuts:
		if rig.sever(c):
			Gore.sever_live(rig, c, dir * force * 3.0 + Vector3.UP * 2.0, get_parent())
			if rig.mods.ik.has("L") and c.begins_with("l_"): rig.mods.ik["L"].w = 0.0
			if rig.mods.ik.has("R") and c.begins_with("r_"): rig.mods.ik["R"].w = 0.0
	stagger = 0.25 if kind == "zombie" else 0.4
	velocity += dir * force * 0.08
	if kind == "scav":
		suspicion = 1.0
		if attacker:
			last_seen = (attacker as Node3D).global_position
		if state != "combat":
			_alert()
	elif state != "chase" and attacker:
		state = "chase"
		last_seen = (attacker as Node3D).global_position

var down_t := 0.0              # knocked off its feet: a ragdoll for this long, then it gets up
var rise_t := 0.0

## Knocked flat: the body goes limp and tumbles, and after a while it picks itself up where it ended
func knock_down(vel: Vector3, secs: float) -> void:
	if dead or puppet or down_t > 0.0: return
	if rise_t > 0.0:
		rise_t = 0.0
		rig.rotation.x = 0.0
	down_t = secs
	velocity = vel
	collision_layer = 0
	collision_mask = 0
	shape.disabled = true
	rig.frozen = true
	rig.mods.ik.clear()
	ragdoll = Ragdoll.new()
	ragdoll.name = "Ragdoll"
	get_parent().add_child(ragdoll)
	ragdoll.owner_actor = self
	ragdoll.build(rig, vel)
	rig.mods.ragdoll = ragdoll
	ragdoll.push("chest" if ragdoll.bodies.has("chest") else "pelvis", vel * 14.0, global_position + Vector3(0, 1.2, 0))
	_say("zattack")

func _down_tick(dt: float) -> void:
	down_t -= dt
	if not (ragdoll and is_instance_valid(ragdoll) and ragdoll.bodies.has("pelvis")):
		down_t = 0.0
		_stand_up(global_position, face_dir)
		return
	var pel: RigidBody3D = ragdoll.bodies["pelvis"]
	global_position = Vector3(pel.global_position.x, global_position.y, pel.global_position.z)      # so a boot or a blade can find it
	# stay down while it's still rolling
	if down_t <= 0.0 and pel.linear_velocity.length() > 1.2 and down_t > -3.0:
		return
	if down_t <= 0.0:
		var head_p: Vector3 = (ragdoll.bodies["head"] as Node3D).global_position if ragdoll.bodies.has("head") and is_instance_valid(ragdoll.bodies["head"]) else pel.global_position + Vector3(0, 0, -0.6)
		var lie := head_p - pel.global_position
		lie.y = 0.0
		lie = lie.normalized() if lie.length() > 0.05 else Vector3(0, 0, -1)
		_stand_up(pel.global_position - lie * 0.9, lie)

func _stand_up(at: Vector3, lie: Vector3) -> void:
	down_t = 0.0
	if ragdoll and is_instance_valid(ragdoll): ragdoll.queue_free()
	ragdoll = null
	rig.mods.ragdoll = null
	rig.frozen = false
	var gy: float = main.height_at(at.x, at.z) if main and main.has_method("height_at") else at.y
	global_position = Vector3(at.x, maxf(at.y - 0.25, gy) if absf(at.y - gy) > 0.6 else gy, at.z)
	face_dir = lie
	rotation.y = atan2(-lie.x, -lie.z)
	rig.rotation.x = -PI / 2
	rise_t = 0.9
	velocity = Vector3.ZERO
	collision_layer = LAYER
	collision_mask = _mask0
	shape.disabled = false
	state = "chase"

func die(impulse: Vector3, point: Vector3, part: String, cuts: Array, launch := Vector3.ZERO) -> void:
	if dead:
		return
	if down_t > 0.0 and ragdoll and is_instance_valid(ragdoll):
		# killed on the floor: the heap it already is stays where it is
		down_t = 0.0
		dead = true
		if not puppet and main and main.net: main.net.npc_died(self, impulse, point, part, cuts)
		remove_from_group("npcs")
		if label: label.text = ""
		_say("zdie" if kind == "zombie" else "hit_flesh")
		ragdoll.push(part if ragdoll.bodies.has(part) else "chest", impulse, point)
		for c in cuts:
			_cut_corpse(c, impulse * 0.08 + Vector3.UP * 3.0)
		add_to_group("corpses")
		_cull_corpses()
		return
	if rise_t > 0.0:
		rise_t = 0.0
		rig.rotation.x = 0.0
	if launch != Vector3.ZERO:
		velocity = launch
	if not puppet and main and main.net: main.net.npc_died(self, impulse, point, part, cuts)
	dead = true
	remove_from_group("npcs")
	collision_layer = 0
	collision_mask = 0
	shape.disabled = true
	if label: label.text = ""
	_say("zdie" if kind == "zombie" else "hit_flesh")
	rig.frozen = true
	rig.mods.ik.clear()
	rig.mods.look_yaw = 0.0
	rig.mods.look_pitch = 0.0
	ragdoll = Ragdoll.new()
	ragdoll.name = "Ragdoll"
	get_parent().add_child(ragdoll)
	ragdoll.owner_actor = self
	ragdoll.build(rig, velocity)
	rig.mods.ragdoll = ragdoll
	ragdoll.push(part if ragdoll.bodies.has(part) else "chest", impulse, point)
	for c in cuts:
		_cut_corpse(c, impulse * 0.08 + Vector3.UP * 3.0)
	if gun:
		_drop_gun()
	add_to_group("corpses")
	_cull_corpses()

func _cut_corpse(part: String, imp: Vector3) -> void:
	if ragdoll == null or ragdoll.cut.has(part):
		return
	if rig.sever(part):
		ragdoll.sever(part, imp)
		Gore.spray(get_parent(), rig.bone_pos(Rig.HIT_BONES[part]), imp.normalized() + Vector3.UP, 2.0)

## Shooting a body that's already down: it moves, and enough of it comes apart
func corpse_hit(part: String, dmg: float, dir: Vector3) -> void:
	if not dead and down_t > 0.0:
		# hit while it's on the floor: it's still alive and it still hurts
		take_hit({part: dmg}, dir, global_position, 2.0, null)
		return
	corpse_dmg[part] = float(corpse_dmg.get(part, 0.0)) + dmg
	if SEVER_AT.has(part) and corpse_dmg[part] >= float(SEVER_AT[part]) * 0.8:
		_cut_corpse(part, dir * 5.0 + Vector3.UP * 2.0)
	if part == "chest" and corpse_dmg[part] > 160.0:
		for p in ["head", "l_upperarm", "r_upperarm"]:
			_cut_corpse(p, (dir + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1))).normalized() * 6.0)
		corpse_dmg[part] = -9999.0

func _drop_gun() -> void:
	var rb := RigidBody3D.new()
	rb.mass = 4.0
	rb.collision_layer = Ragdoll.layer_bits()
	rb.collision_mask = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.08, 0.15, float(gun.def.len))
	cs.shape = bs
	rb.add_child(cs)
	get_parent().add_child(rb)
	rb.global_transform = gun.global_transform
	gun.top_level = false
	gun.reparent(rb, true)
	gun.excludes = []
	rb.linear_velocity = velocity + Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1))
	rb.add_to_group("pickups")
	var gs := Items.stack("gun_" + gun.key, 1, {"ammo": gun.ammo})
	var items: Array = [gs]
	var aid: String = Items.GUN_AMMO.get(gun.key, "")
	if aid != "": items.append(Items.stack(aid, randi_range(4, 14)))
	if randf() < 0.35: items.append(Items.fresh(["bandage", "food_can", "shirt_flanno", "pants_cargo"][randi() % 4], 1 + randi() % 2))
	rb.set_meta("items", items)
	gun.set_process(false)
	gun = null

## Keep the dead from piling up forever
func _cull_corpses() -> void:
	var c := get_tree().get_nodes_in_group("corpses")
	if c.size() > 24:
		var old = c[0]
		if is_instance_valid(old) and old != self:
			old.free_body()

func free_body() -> void:
	if ragdoll and is_instance_valid(ragdoll):
		ragdoll.queue_free()
	queue_free()

## Cars: anything faster than a walk knocks it down, fast enough and it comes apart
func _check_cars() -> void:
	for c in get_tree().get_nodes_in_group("vehicles"):
		var car := c as RigidBody3D
		if car.global_position.distance_squared_to(global_position) > 49.0:
			continue
		var d: Dictionary = car.def
		var mn: Array = d.min
		var ex: Array = d.ext
		var hit := false
		for h in [0.35, 1.1]:
			var lp := car.to_local(global_position + Vector3(0, h, 0))
			if abs(lp.x) < float(ex[2]) * 0.5 + 0.3 and lp.z > float(mn[0]) - 0.3 and lp.z < float(mn[0]) + float(ex[0]) + 0.3 and lp.y > float(mn[1]) - 0.2 and lp.y < float(mn[1]) + float(ex[1]):
				hit = true
		if not hit:
			continue
		var rel: Vector3 = car.linear_velocity - velocity
		var v := rel.length()
		if v < 3.0:
			# just leaning on you: get shoved out of the way
			var away := global_position - car.global_position
			away.y = 0
			velocity += away.normalized() * 2.0
			continue
		var cuts: Array = []
		if v > 10.0:
			var limbs := ["l_upperarm", "r_upperarm", "l_thigh", "r_thigh", "l_forearm", "r_shin", "head"]
			limbs.shuffle()
			cuts = limbs.slice(0, randi_range(1, 3 if v < 20.0 else 5))
		hp -= v * v * 3.0
		Gore.spray(get_parent(), global_position + Vector3(0, 1.0, 0), rel.normalized() + Vector3.UP * 0.6, 3.0)
		var a := AudioStreamPlayer3D.new()
		a.stream = Gun.sfx("splat")
		get_parent().add_child(a)
		a.global_position = global_position
		a.play()
		a.finished.connect(a.queue_free)
		car.apply_central_impulse(-rel.normalized() * min(v, 16.0) * 25.0)
		if hp <= 0.0 or v > 6.0:
			die(rel * 6.0, global_position + Vector3(0, 0.9, 0), "pelvis", cuts, car.linear_velocity * 0.85 + Vector3.UP * min(v * 0.3, 5.0))
		else:
			stagger = 1.0
			velocity = rel * 0.6
		return
