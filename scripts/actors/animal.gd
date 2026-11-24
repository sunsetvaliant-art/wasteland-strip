class_name Animal
extends CharacterBody3D
## Wild animals to hunt (0.2.74): fallow deer in the paddocks and at the bush edge, feral pigs in the scrub and the
## wet, rabbits on the grass (no roos yet: no decent free animated one). They graze and wander, lift their heads at a noise, and bolt from you
## (crouching and coming slowly gets you closer; a gunshot clears the paddock). A pig that's hit may turn and come at
## you. Shot, it drops where it is and stays; F with a blade (knife, machete, axe) butchers it for raw meat, which
## cooks at a fire.

const LAYER := 1 << 2
const SPECIES := {
	# glb, length (m, nose to tail; the model's scaled to it), hp, walk / run (m/s), clips: names tried in turn
	# (any part of the clip's name), meat (pieces), hear: how far a shot carries to it, wary: how near you can come
	"deer": {"glb": "res://assets/animals/deer.glb", "len": 1.9, "yaw": 0.0, "hp": 95.0, "walk": 1.3, "run": 11.0, "meat": [5, 8],
		"idle": ["Grazing", "Idle", "idleEarFlik"], "walk_c": ["WalkForward"], "run_c": ["Gallop", "Trot"], "wary": 45.0, "turn": 3.5},
	"pig": {"glb": "res://assets/animals/boar.glb", "len": 1.4, "yaw": PI, "hp": 120.0, "walk": 1.0, "run": 7.5, "meat": [4, 6],
		"idle": ["idle_eat_grazing_01", "idle_eat_look_around_01", "idle_smell_01"], "walk_c": ["walk_fwd_01", "trot_fwd_01"],
		"run_c": ["run_fwd_01", "sprint_fwd"], "attack": ["attack_02", "attack"], "wary": 26.0, "turn": 3.0, "charges": true,
		"tint": Color(0.15, 0.12, 0.1)},
	"rabbit": {"glb": "res://assets/animals/rabbit.glb", "len": 0.42, "yaw": PI, "hp": 12.0, "walk": 0.6, "run": 7.0, "meat": [1, 1],
		"idle": ["Take 001"], "walk_c": ["Take 001"], "run_c": ["Take 001"], "anim_idle_speed": 0.0, "wary": 14.0, "turn": 6.0},
}
const BLADES := ["knife", "machete", "hatchet"]

var species := "deer"
var spec: Dictionary
var hp := 50.0
var dead := false
var stagger := 0.0
var rig = null                    # guns and melee ask for it: animals have no hit zones, so they hit the chest
var state := "graze"              # graze / walk / alert / flee / charge
var state_t := 0.0
var goal := Vector3.ZERO
var threat := Vector3.ZERO
var model: Node3D
var ap: AnimationPlayer
var clips := {}                   # role -> clip name
var _cur := ""
var _yaw := 0.0
var _hit_by: Node = null
var butchered := false
var main

static var _scenes := {}

func setup(m, sp: String) -> void:
	main = m
	species = sp
	spec = SPECIES[sp]
	hp = float(spec.hp)

func _ready() -> void:
	add_to_group("animals")
	collision_layer = LAYER
	collision_mask = 1
	var L := float(spec.len)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(L * 0.32, L * 0.5, L * 0.75)
	cs.shape = bx
	cs.position = Vector3(0, L * 0.27, 0)
	add_child(cs)
	_yaw = randf() * TAU
	_load_model()
	state_t = randf_range(2.0, 8.0)
	goal = global_position

func _load_model() -> void:
	var path := str(spec.glb)
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scenes[path]
	if ps == null: return
	model = ps.instantiate()
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# untextured downloads (the pig's coloured by vertex; the roo is flat colours): give them a hide
		if spec.has("tint") and m.mesh:
			for si in m.mesh.get_surface_count():
				var src: Material = m.mesh.surface_get_material(si)
				if src is StandardMaterial3D and (src as StandardMaterial3D).albedo_texture == null:
					var nm := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					nm.albedo_color = spec.tint
					nm.roughness = 0.9
					m.set_surface_override_material(si, nm)
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] if aps.size() else null
	if ap:
		for role in ["idle", "walk_c", "run_c", "attack"]:
			for want in spec.get(role, []):
				for c in ap.get_animation_list():
					var short := c.get_slice("|", c.get_slice_count("|") - 1).to_lower()
					if short.contains(str(want).to_lower()) and not short.contains("_to_"):
						clips[role] = c
						break
				if clips.has(role): break
		for c in clips.values():
			var a := ap.get_animation(c)
			if a: a.loop_mode = Animation.LOOP_LINEAR
	# scale to its real size and stand it on the ground, nose along -z (the way it walks), off the posed skeleton
	# (skinned meshes' boxes are their rest data, often Z-up or lying down)
	if ap and clips.has("idle"):
		ap.play(clips.idle)
		ap.advance(0.0)
	var bb := bone_box(model)
	if bb.size == Vector3.ZERO: bb = _aabb(model)
	var longest := maxf(bb.size.x, bb.size.z)
	if longest > 0.001:
		var k := float(spec.len) / longest
		model.scale = Vector3.ONE * k
		model.rotation.y = float(spec.get("yaw", 0.0)) + (PI / 2 if bb.size.x > bb.size.z else 0.0)
		model.position.y = -bb.position.y * k

## The posed skeleton's box in n's own space (skinned meshes' AABBs are their rest data, often lying down or Z-up)
static func bone_box(n: Node3D) -> AABB:
	var ab := AABB()
	var first := true
	for sk in n.find_children("*", "Skeleton3D", true, false):
		var s3 := sk as Skeleton3D
		var to_n := _rel(n, s3) if not n.is_inside_tree() else n.global_transform.affine_inverse() * s3.global_transform
		for b in s3.get_bone_count():
			var p := to_n * s3.get_bone_global_pose(b).origin
			if first: ab = AABB(p, Vector3.ZERO); first = false
			else: ab = ab.expand(p)
	return ab

static func _aabb(n: Node3D) -> AABB:
	var ab := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := n.global_transform.affine_inverse() * m.global_transform if n.is_inside_tree() else _rel(n, m)
		var b := xf * m.get_aabb()
		if first: ab = b; first = false
		else: ab = ab.merge(b)
	return ab

static func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D()
	var p: Node = n
	while p != null and p != root:
		if p is Node3D: xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return root.transform * xf

func _play(role: String, speed := 1.0) -> void:
	if ap == null or not clips.has(role): return
	var c: String = clips[role]
	if c != _cur:
		ap.play(c, 0.3)
		_cur = c
	ap.speed_scale = speed

# ---------------------------------------------------------------- living
func _physics_process(dt: float) -> void:
	if dead:
		if not is_on_floor():
			velocity.y -= 9.8 * dt
			move_and_slide()
		return
	stagger = maxf(stagger - dt, 0.0)
	state_t -= dt
	var me := global_position
	var p: Node3D = null
	if main and main.player and not main.player.dead:
		p = main.player.vehicle if main.player.vehicle else main.player
	var pd := me.distance_to(p.global_position) if p else 1e9
	# how near it lets you come: crouched and slow you get closer, in a car or running you don't
	var wary := float(spec.wary)
	if p != null and p == main.player:
		if main.player.crouching: wary *= 0.45
		if main.player.velocity.length() > 4.0: wary *= 1.4
	elif p: wary *= 1.6
	if state != "flee" and state != "charge" and pd < wary:
		_spook(p.global_position)
	var spd := 0.0
	match state:
		"graze":
			_play("idle", 1.0)
			if state_t <= 0.0:
				state = "walk"
				state_t = randf_range(3.0, 9.0)
				goal = me + Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))
		"walk":
			spd = float(spec.walk)
			_play("walk_c", 1.0)
			if state_t <= 0.0 or Vector2(goal.x - me.x, goal.z - me.z).length() < 1.0:
				state = "graze"
				state_t = randf_range(4.0, 14.0)
		"alert":
			_play("idle", 0.5)
			_face(threat, dt)
			if state_t <= 0.0: state = "graze"; state_t = randf_range(3.0, 8.0)
		"flee":
			spd = float(spec.run)
			_play("run_c", 1.0)
			goal = me + (me - threat).normalized() * 30.0
			if state_t <= 0.0 and pd > wary * 2.0:
				state = "walk"
				state_t = randf_range(2.0, 5.0)
				goal = me + (me - threat).normalized() * 12.0
		"charge":
			spd = float(spec.run) * 0.85
			_play("run_c", 1.0)
			if p:
				goal = p.global_position
				if pd < 1.6 and state_t <= 0.0:
					_gore(p)
					state_t = 1.2
			if pd > 40.0 or randf() < dt * 0.05:
				state = "flee"; state_t = 6.0
	var to := Vector3(goal.x - me.x, 0, goal.z - me.z)
	if spd > 0.0 and to.length() > 0.3:
		var want := atan2(-to.x, -to.z)
		_yaw = lerp_angle(_yaw, want, clampf(dt * float(spec.turn), 0.0, 1.0))
	rotation.y = _yaw
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	if stagger > 0.0: spd *= 0.3
	# water and town: turn back
	if spd > 0.0 and main and main.has_method("height_at"):
		var ahead := me + fwd * 3.0
		if float(main.height_at(ahead.x, ahead.z)) < 0.15:
			goal = me - fwd * 15.0                 # water ahead: back the way it came
			if state == "flee": threat = me + fwd * 10.0
	velocity.x = fwd.x * spd
	velocity.z = fwd.z * spd
	velocity.y = velocity.y - 9.8 * dt if not is_on_floor() else -0.5
	move_and_slide()
	if ap: ap.speed_scale = ap.speed_scale if spd > 0.0 or state != "graze" else 1.0

func _face(at: Vector3, dt: float) -> void:
	var to := at - global_position
	_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), clampf(dt * 3.0, 0.0, 1.0))

func _spook(from: Vector3) -> void:
	threat = from
	state = "flee"
	state_t = randf_range(5.0, 9.0)

## a noise: a shot clears the paddock; something quieter makes it look up
func hear(pos: Vector3, loud: float, kind: String, _src: Node) -> void:
	if dead: return
	if kind in ["gunshot", "shot", "explosion"] or loud > 0.55:
		_spook(pos)
	elif state in ["graze", "walk"] and loud > 0.2:
		threat = pos
		state = "alert"
		state_t = randf_range(2.0, 4.0)

func _gore(p: Node3D) -> void:
	if p != null and p == main.player and p.has_method("take_damage"):
		p.take_damage(18.0, global_position, (p.global_position - global_position).normalized() * 3.0)
	_play("attack", 1.0)

# ---------------------------------------------------------------- hurt and dead
func take_hit(parts: Dictionary, dir: Vector3, _point: Vector3, force: float, attacker: Node) -> void:
	if dead: return
	var total := 0.0
	for k in parts: total += float(parts[k])
	hp -= total
	stagger = 0.4
	if hp <= 0.0:
		_die(dir, force)
		return
	_hit_by = attacker
	if spec.get("charges", false) and attacker and randf() < 0.55:
		state = "charge"
		state_t = 0.6
	else:
		_spook(global_position - dir * 5.0)

func _die(dir: Vector3, force: float) -> void:
	dead = true
	state = "dead"
	if ap: ap.pause()
	remove_from_group("animals")
	add_to_group("carcasses")
	velocity = dir * minf(force * 0.1, 2.0)
	# it goes down on its side
	var tw := create_tween()
	var side := 1.0 if randf() < 0.5 else -1.0
	tw.tween_property(model, "rotation:z", side * PI * 0.5, 0.45).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", model.position.y + float(spec.len) * 0.12, 0.45)
	# the body stays put (and in the look ray for F)
	collision_mask = 1

func hint() -> String:
	return "F  Butcher the %s" % _name() if not butchered else ""

func _name() -> String:
	return {"deer": "deer", "pig": "pig", "rabbit": "rabbit"}.get(species, species)

func butcher(p: Node) -> void:
	if butchered: return
	var blade := ""
	for b in BLADES:
		if p.inv.count(b) > 0: blade = b; break
	if blade == "":
		p._toast("You need a knife (or a machete or an axe) to butcher it")
		return
	butchered = true
	var n := randi_range(int(spec.meat[0]), int(spec.meat[1]))
	var left: int = p.inv.add(Items.fresh("meat_raw", n))
	if left > 0: WorldItem.spawn(get_parent(), [Items.fresh("meat_raw", left)], global_position + Vector3(0, 0.5, 0))
	p._toast("%d pieces of raw meat off the %s. Cook it at a fire." % [n, _name()])
	Gore.spray(get_parent(), global_position + Vector3(0, 0.3, 0), Vector3.UP, 0.8)
	var tw := create_tween()
	tw.tween_interval(20.0)
	tw.tween_callback(queue_free)
