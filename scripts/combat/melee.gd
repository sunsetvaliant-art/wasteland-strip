class_name Melee
extends Node3D
## Fighting hand to hand, and the body doing it. With no gun up (H puts it away) the left button swings whatever's best
## in your pockets: fists, a knife, a bat, a crowbar, a machete, an axe, a sledgehammer. Q kicks them off you (a
## flying kick off a sprint sends them sprawling), Alt hops out of the way, crouching at a sprint slides, and holding
## jump at a ledge pulls you up it. X throws: a brick, a bottle (they go and look), a petrol bomb, or the weapon itself.
## All of it runs on stamina, and stamina runs on food and water.

const WEAPONS := {
	"fists": {"name": "Fists", "dmg": 12.0, "reach": 1.5, "time": 0.42, "stam": 6.0, "force": 3.0, "blunt": true, "wide": 1},
	"knife": {"name": "Knife", "dmg": 34.0, "reach": 1.5, "time": 0.4, "stam": 6.0, "force": 2.0, "blunt": false, "wide": 1},
	"tyre_iron": {"name": "Tyre iron", "dmg": 42.0, "reach": 1.8, "time": 0.6, "stam": 10.0, "force": 6.0, "blunt": true, "wide": 1},
	"pipe_wrench": {"name": "Pipe wrench", "dmg": 48.0, "reach": 1.8, "time": 0.7, "stam": 12.0, "force": 7.0, "blunt": true, "wide": 1},
	"bat": {"name": "Cricket bat", "dmg": 46.0, "reach": 2.0, "time": 0.65, "stam": 11.0, "force": 9.0, "blunt": true, "wide": 2},
	"crowbar": {"name": "Crowbar", "dmg": 55.0, "reach": 1.9, "time": 0.7, "stam": 12.0, "force": 7.0, "blunt": true, "wide": 1},
	"machete": {"name": "Machete", "dmg": 72.0, "reach": 1.9, "time": 0.55, "stam": 10.0, "force": 4.0, "blunt": false, "wide": 2},
	"hatchet": {"name": "Axe", "dmg": 80.0, "reach": 1.9, "time": 0.8, "stam": 15.0, "force": 7.0, "blunt": false, "wide": 1},
	"sledge": {"name": "Sledgehammer", "dmg": 130.0, "reach": 2.2, "time": 1.25, "stam": 26.0, "force": 16.0, "blunt": true, "wide": 2},
}
const THROWN := {"brick": {"dmg": 45.0, "loud": 22.0}, "bottle": {"dmg": 12.0, "loud": 40.0, "breaks": true}, "molotov": {"dmg": 10.0, "loud": 30.0, "breaks": true, "fire": true}}

var player: Player
var stamina := 100.0
var hunger := 100.0             # 100 full .. 0 starving
var thirst := 100.0
var weapon := "fists"
var swing := -1.0               # seconds into the swing, -1 when not
var _hit_done := false
var cool := 0.0
var rest_t := 0.0               # since the last effort: stamina comes back after a moment
var lock_t := 0.0               # the legs are busy (a slide, a dodge, a climb): no steering
var slide_t := 0.0
var grab_t := 0.0               # a zombie's got hold of you
var kick_t := -1.0
var held: Node3D
var _held_id := ""
var _climb: Array = []          # [from, to, t]
var _need_t := 0.0

func setup(p) -> void:
	player = p
	if OS.get_environment("MELEE_TEST") != "":
		get_tree().create_timer(9.0).timeout.connect(_selftest)

func _selftest() -> void:
	var fwd := (Basis(Vector3.UP, player.yaw) * Vector3(0, 0, -1)).normalized()
	var zs := []
	for i in 3:
		var z := NPC.new()
		z.kind = "zombie"
		player.get_parent().add_child(z)
		z.global_position = player.global_position + fwd * (1.3 + i * 0.1) + Vector3(i * 0.5 - 0.5, 0.1, 0)
		zs.append(z)
	await get_tree().create_timer(1.0).timeout
	print("PROBE melee breeds ", zs.map(func(z): return [z.breed, int(z.hp)]))
	player.pitch = 0.0
	_strike(WEAPONS.machete)
	print("PROBE after machete ", zs.map(func(z): return [z.dead, int(z.hp)] if is_instance_valid(z) else "freed"))
	cool = 0.0
	kick()
	print("PROBE after kick ", zs.map(func(z): return [z.dead, int(z.hp), snappedf(z.stagger, 0.1), z.velocity.round()] if is_instance_valid(z) else "freed"))
	_strike(WEAPONS.sledge)
	print("PROBE after sledge ", zs.map(func(z): return [z.dead, int(z.hp)] if is_instance_valid(z) else "freed"))
	player.inv.add(Items.fresh("brick", 2))
	player.inv.add(Items.fresh("molotov", 1))
	cool = 0.0
	throw()
	cool = 0.0
	throw()
	dodge()
	print("PROBE dodge v ", player.velocity.round(), " stamina ", int(stamina), " weapon ", weapon, " food ", int(hunger), " water ", int(thirst))
	await get_tree().create_timer(2.5).timeout
	print("PROBE thrown left ", get_tree().get_nodes_in_group("pickups").size(), " pickups, mantle ", try_mantle())

func speed_mul() -> float:
	var m := 1.0
	if grab_t > 0.0: m *= 0.25
	if hunger <= 0.0 or thirst <= 0.0: m *= 0.8
	return m

func can_sprint() -> bool:
	return stamina > 1.0 and grab_t <= 0.0

## The best thing to hit with that you're carrying
func _pick() -> String:
	var best := "fists"
	for id in WEAPONS:
		if id != "fists" and player.inv.count(id) > 0 and float(WEAPONS[id].dmg) > float(WEAPONS[best].dmg):
			best = id
	return best

func tick(dt: float) -> void:
	var creative: bool = Settings.creative()
	cool = maxf(cool - dt, 0.0)
	grab_t = maxf(grab_t - dt, 0.0)
	lock_t = maxf(lock_t - dt, 0.0)
	rest_t += dt
	# needs: a day's food in about forty minutes, water in twenty-five
	if not creative:
		hunger = maxf(hunger - dt * 100.0 / 2400.0, 0.0)
		thirst = maxf(thirst - dt * 100.0 / 1500.0, 0.0)
		_need_t -= dt
		if _need_t <= 0.0:
			_need_t = 4.0
			if hunger <= 0.0 or thirst <= 0.0:
				player.take_damage(2.0, player.global_position)
				player._toast("You're starving" if hunger <= 0.0 else "You need water")
	# stamina
	var sprinting: bool = Input.is_action_pressed("sprint") and player.velocity.length() > 4.5 and player.is_on_floor()
	if sprinting and not creative:
		stamina = maxf(stamina - dt * 7.0, 0.0)
		rest_t = 0.0
	elif rest_t > 0.9:
		var rate := 16.0 * (0.45 if (hunger < 20.0 or thirst < 20.0) else 1.0)
		stamina = minf(stamina + dt * rate, 100.0)
	weapon = _pick()
	_show_weapon()
	var free: bool = not player.armed() and player.carried == null and player.vehicle == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not BaseBuild.busy
	if free and Input.is_action_just_pressed("fire") and swing < 0.0 and cool <= 0.0:
		var w: Dictionary = WEAPONS[weapon]
		if stamina >= float(w.stam) * 0.5 or creative:
			swing = 0.0
			_hit_done = false
			_spend(float(w.stam))
			if player.rig.has_clip("Punch_Forward_with_Both_Fists") and weapon == "fists": player.rig.act("Punch_Forward_with_Both_Fists", 1.8)
			_sfx("whoosh", 0.9 + randf() * 0.3)
	if swing >= 0.0:
		var w: Dictionary = WEAPONS[weapon]
		swing += dt
		if not _hit_done and swing >= float(w.time) * 0.38:
			_hit_done = true
			_strike(w)
		if swing >= float(w.time):
			swing = -1.0
			cool = 0.08
	if kick_t >= 0.0:
		kick_t += dt
		if kick_t > 0.45: kick_t = -1.0
	_climb_tick(dt)
	# a slide: low and fast, bowling over what's in the way
	if slide_t > 0.0:
		slide_t -= dt
		for n in get_tree().get_nodes_in_group("zombies"):
			if is_instance_valid(n) and not n.dead and n.global_position.distance_to(player.global_position) < 1.2 and n.stagger < 0.5:
				_shove(n, Vector3(player.velocity.x, 0, player.velocity.z).normalized(), 5.0, 1.6, {"l_shin": 14.0})
		if slide_t <= 0.0: player.crouching = false

func _spend(a: float) -> void:
	if not Settings.creative(): stamina = maxf(stamina - a, 0.0)
	rest_t = 0.0

func _eye() -> Vector3:
	return player.active_camera().global_position if player.first_person else player.head.global_position

func _aim() -> Vector3:
	return -player.active_camera().global_transform.basis.z

## Everything alive in front of you within reach, nearest first
func _targets(reach: float, cone: float) -> Array:
	var out := []
	var eye: Vector3 = player.global_position + Vector3(0, 1.4, 0)
	var dir := _aim()
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	for n in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(n) or n.dead: continue
		var to: Vector3 = n.global_position - player.global_position
		var d := Vector3(to.x, 0, to.z).length()
		if d > reach + 0.35 or absf(to.y) > 1.8: continue
		if d > 0.4 and flat.dot(Vector3(to.x, 0, to.z).normalized()) < cone: continue
		out.append([d, n])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

func _strike(w: Dictionary) -> void:
	var dir := _aim()
	var eye: Vector3 = player.global_position + Vector3(0, 1.5, 0)
	var hit := 0
	for e in _targets(float(w.reach), 0.55):
		var n = e[1]
		# where on them: along the line you're looking, at their distance
		var pt: Vector3 = eye + dir * maxf(float(e[0]), 0.5)
		pt.x = n.global_position.x
		pt.z = n.global_position.z
		pt.y = clampf(pt.y, n.global_position.y + 0.25, n.global_position.y + 1.72)
		var part: String = n.rig.part_at(pt, dir) if n.rig else "chest"
		var dmg := float(w.dmg) * randf_range(0.9, 1.15) * (0.6 if stamina <= 0.5 else 1.0)
		var parts := {}
		if w.blunt:
			# a blunt thing breaks rather than cuts: spread it so limbs stay on (a sledgehammer still takes a head)
			parts[part] = dmg * (0.75 if part != "head" else 1.3) if float(w.dmg) < 100.0 else dmg
			parts["chest" if part != "chest" else "pelvis"] = dmg * 0.25
		else:
			parts[part] = dmg * (1.6 if part == "head" else 1.0)
		var push := Vector3(dir.x, 0.0, dir.z).normalized()
		n.take_hit(parts, push, pt, float(w.force), player)
		if is_instance_valid(n) and not n.dead:
			n.stagger = maxf(n.stagger, 0.35 + float(w.force) * 0.06)
			n.velocity += push * float(w.force) * 0.45
		hit += 1
		if hit >= int(w.wide): break
	if hit > 0:
		_sfx("hit_flesh" if not w.blunt else "hit_blunt", 0.9 + randf() * 0.2)
		player.recoil += 0.012
		Hearing.emit(get_tree(), player.global_position, 9.0, "fight", player)
	else:
		# glass in the way goes
		var t = player.interact_target
		if t is BuildWindow: (t as BuildWindow).glass_hit(t.global_position, dir)

## Q: a boot in the chest. Off a sprint and off the ground it's a flying kick.
func kick() -> void:
	if kick_t >= 0.0 or cool > 0.0 or player.vehicle or player.dead: return
	if stamina < 6.0 and not Settings.creative(): return
	var flying: bool = not player.is_on_floor() and Vector3(player.velocity.x, 0, player.velocity.z).length() > 4.0
	kick_t = 0.0
	cool = 0.35
	_spend(22.0 if flying else 12.0)
	grab_t = 0.0
	_sfx("whoosh", 0.7)
	var dir := Vector3(_aim().x, 0, _aim().z).normalized()
	var n_hit := 0
	for e in _targets(2.4 if flying else 1.9, 0.5):
		var n = e[1]
		_shove(n, dir, 11.0 if flying else 6.5, 2.2 if flying else 1.3, {"chest": 28.0 if flying else 12.0})
		n_hit += 1
		if n_hit >= (3 if flying else 2): break
	if n_hit > 0:
		_sfx("hit_blunt", 0.8)
		if flying:
			player.velocity = -dir * 2.5 + Vector3(0, 2.0, 0)

func _shove(n, dir: Vector3, speed: float, stun: float, parts: Dictionary) -> void:
	n.take_hit(parts, dir, n.global_position + Vector3(0, 1.1, 0), 4.0, player)
	if is_instance_valid(n) and not n.dead:
		n.stagger = maxf(n.stagger, stun)
		n.velocity = dir * speed + Vector3(0, 2.2, 0)
		n.set("knock_t", stun * 0.6)

## Alt: a quick hop the way you're moving (back if you're standing still)
func dodge() -> void:
	if lock_t > 0.0 or not player.is_on_floor() or player.vehicle: return
	if stamina < 14.0 and not Settings.creative(): return
	_spend(14.0)
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if inp.length() < 0.2: inp = Vector2(0, 1)
	var dir := (Basis(Vector3.UP, player.yaw) * Vector3(inp.x, 0, inp.y)).normalized()
	player.velocity = dir * 8.5 + Vector3(0, 1.6, 0)
	lock_t = 0.32
	grab_t = 0.0

## Crouch at a sprint: slide
func try_slide() -> bool:
	if slide_t > 0.0 or not player.is_on_floor() or not Input.is_action_pressed("sprint"): return false
	var hv := Vector3(player.velocity.x, 0, player.velocity.z)
	if hv.length() < 4.8 or (stamina < 10.0 and not Settings.creative()): return false
	_spend(10.0)
	player.velocity = hv.normalized() * 9.0
	player.crouching = true
	slide_t = 0.75
	lock_t = 0.75
	return true

## Jump at a wall with a top you can reach: up you go. true if it's taken the jump.
func try_mantle() -> bool:
	if not _climb.is_empty() or player.vehicle: return false
	var sp := player.get_world_3d().direct_space_state
	var fwd := (Basis(Vector3.UP, player.yaw) * Vector3(0, 0, -1)).normalized()
	var base: Vector3 = player.global_position
	var wall := sp.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.9, 0), base + Vector3(0, 0.9, 0) + fwd * 0.9, 1, [player.get_rid()]))
	if wall.is_empty(): return false
	var top_from: Vector3 = base + fwd * 0.95 + Vector3(0, 2.75, 0)
	var top := sp.intersect_ray(PhysicsRayQueryParameters3D.create(top_from, top_from - Vector3(0, 2.2, 0), 1, [player.get_rid()]))
	if top.is_empty(): return false
	var rise: float = top.position.y - base.y
	if rise < 0.75 or rise > 2.45 or (top.normal as Vector3).y < 0.7: return false
	# room to stand up there?
	var head := sp.intersect_ray(PhysicsRayQueryParameters3D.create(top.position + Vector3(0, 0.1, 0), top.position + Vector3(0, 1.7, 0), 1, [player.get_rid()]))
	if not head.is_empty(): return false
	if stamina < 8.0 and not Settings.creative(): return false
	_spend(8.0 + rise * 4.0)
	_climb = [base, top.position + Vector3(0, 0.05, 0), 0.0, 0.3 + rise * 0.18]
	lock_t = float(_climb[3]) + 0.05
	return true

func _climb_tick(dt: float) -> void:
	if _climb.is_empty(): return
	_climb[2] = float(_climb[2]) + dt
	var k := clampf(float(_climb[2]) / float(_climb[3]), 0.0, 1.0)
	var a: Vector3 = _climb[0]
	var b: Vector3 = _climb[1]
	# up first, then over
	var up := clampf(k / 0.65, 0.0, 1.0)
	var over := clampf((k - 0.45) / 0.55, 0.0, 1.0)
	player.global_position = Vector3(lerpf(a.x, b.x, over), lerpf(a.y, b.y, up), lerpf(a.z, b.z, over))
	player.velocity = Vector3.ZERO
	if k >= 1.0: _climb.clear()

func climbing() -> bool:
	return not _climb.is_empty()

## X: throw something. A brick, a bottle, a petrol bomb; failing those, the weapon in your hand.
func throw() -> void:
	if cool > 0.0 or player.vehicle or player.dead: return
	var id := ""
	for t in ["molotov", "brick", "bottle"]:
		if player.inv.count(t) > 0:
			id = t
			break
	if id == "" and weapon != "fists": id = weapon
	if id == "":
		player._toast("Nothing to throw")
		return
	if player.inv.take(id, 1) < 1 and not Settings.creative(): return
	cool = 0.5
	_spend(6.0)
	_sfx("whoosh", 1.1)
	var dir := _aim()
	var from: Vector3 = player.head.global_position + dir * 0.6
	var rb: RigidBody3D = WorldItem.spawn(player.get_parent(), [Items.fresh(id, 1)], from, dir * 17.0 + Vector3(0, 2.5, 0) + player.velocity * 0.5)
	if rb == null: return
	rb.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-4, 4), randf_range(-8, 8))
	var th := Thrown.new()
	rb.add_child(th)
	var spec: Dictionary = THROWN.get(id, {"dmg": float(WEAPONS.get(id, {"dmg": 20.0}).dmg) * 1.3, "loud": 14.0, "blade": WEAPONS.has(id) and not WEAPONS[id].blunt})
	th.arm(rb, player, spec)

## A zombie's got you: you can barely move until you kick it off
func grabbed(by) -> void:
	if lock_t > 0.0: return
	grab_t = 1.6
	player._toast("It's got hold of you: Q to kick it off")

# ------------------------------------------------------------------------------------------------ what's in the hand
const MODELS := {"machete": "res://assets/ph/weapons/machete/machete.gltf", "crowbar": "res://assets/ph/weapons/crowbar_01/crowbar_01.gltf",
	"sledge": "res://assets/ph/weapons/sledgehammer_01/sledgehammer_01.gltf", "hatchet": "res://assets/ph/weapons/wooden_axe/wooden_axe.gltf",
	"pipe_wrench": "res://assets/ph/tools/pipe_wrench/pipe_wrench.gltf"}
const LEN := {"knife": 0.3, "tyre_iron": 0.5, "pipe_wrench": 0.45, "bat": 0.85, "crowbar": 0.7, "machete": 0.6, "hatchet": 0.7, "sledge": 0.95}

func _show_weapon() -> void:
	var want: String = weapon if (not player.armed() and player.carried == null and player.vehicle == null and not player.dead and weapon != "fists") else ""
	if want != _held_id:
		_held_id = want
		if held:
			held.queue_free()
			held = null
		if want != "":
			held = _model(want)
			player.head.add_child(held)
	if held == null: return
	# at rest low on the right; a swing comes across from up on the right to down on the left
	var w: Dictionary = WEAPONS[weapon]
	var k := clampf(swing / float(w.time), 0.0, 1.0) if swing >= 0.0 else 0.0
	var rest := Transform3D(Basis.from_euler(Vector3(-0.5, 0.25, -0.15)), Vector3(0.3, -0.34, -0.45))
	if swing < 0.0:
		held.transform = held.transform.interpolate_with(rest, 0.25)
	else:
		var a := sin(k * PI)                 # out and back
		var sw := lerpf(-0.9, 1.3, smoothstep(0.1, 0.6, k))
		held.transform = Transform3D(Basis.from_euler(Vector3(-0.3 - 1.1 * smoothstep(0.15, 0.55, k) + 0.9 * (1.0 - a) * 0.0, sw * 0.9, -sw * 0.8)),
			Vector3(0.3 - 0.45 * smoothstep(0.1, 0.6, k), -0.18 - 0.1 * k, -0.5 - 0.25 * a))

func _model(id: String) -> Node3D:
	var root := Node3D.new()
	var L: float = LEN.get(id, 0.5)
	if MODELS.has(id) and ResourceLoader.exists(MODELS[id]):
		var raw: Node3D = (load(MODELS[id]) as PackedScene).instantiate()
		var bb := WorldItem._aabb(raw)
		var longest := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		var k := L / maxf(longest, 0.01)
		# stand it along -z (pointing away), held near one end
		var piv := Node3D.new()
		if bb.size.x >= bb.size.y and bb.size.x >= bb.size.z: piv.rotation.y = PI / 2
		elif bb.size.y >= bb.size.z: piv.rotation.x = -PI / 2
		raw.scale = Vector3.ONE * k
		raw.position = -bb.get_center() * k
		piv.add_child(raw)
		piv.position = Vector3(0, 0, -L * 0.35)
		root.add_child(piv)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09 if id == "bat" else 0.03, 0.03, L)
		mi.mesh = bm
		mi.position = Vector3(0, 0, -L * 0.35)
		mi.material_override = BuildGen.mat("timber" if id == "bat" else "steel")
		root.add_child(mi)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

func _sfx(n: String, pitch := 1.0) -> void:
	if n == "hit_blunt":
		n = "splat"
		pitch *= 0.7
	if not ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % n): return
	var st: AudioStream = Gun.sfx(n)
	var a := AudioStreamPlayer3D.new()
	a.stream = st
	a.pitch_scale = pitch
	a.volume_db = -4.0
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

func state() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst, "stamina": stamina}

func take_state(d: Dictionary) -> void:
	hunger = float(d.get("hunger", 100.0))
	thirst = float(d.get("thirst", 100.0))
	stamina = float(d.get("stamina", 100.0))
