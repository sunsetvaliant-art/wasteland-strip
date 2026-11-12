class_name Fire
extends Node3D
## A pool of burning petrol: eight seconds of it. The dead walk straight through and burn.

var t := 8.0
var tick := 0.0
var who

static func light(parent: Node, pos: Vector3, thrower) -> void:
	var f := Fire.new()
	f.who = thrower
	parent.add_child(f)
	f.global_position = pos

func _ready() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 3.0
	l.omni_range = 9.0
	l.position.y = 0.6
	add_child(l)
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.6
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 3.0, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	var qm := QuadMesh.new()
	qm.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.5, 0.12, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = m
	p.mesh = qm
	add_child(p)
	Hearing.emit(get_tree(), global_position, 45.0, "fire", who)

func _process(dt: float) -> void:
	t -= dt
	tick -= dt
	if tick <= 0.0:
		tick = 0.5
		for n in get_tree().get_nodes_in_group("npcs"):
			if is_instance_valid(n) and not n.dead and n.global_position.distance_to(global_position) < 2.6:
				n.take_hit({"chest": 22.0}, Vector3.UP, n.global_position + Vector3(0, 1, 0), 0.5, who)
		if who and is_instance_valid(who) and not who.dead and who.global_position.distance_to(global_position) < 2.0:
			who.take_damage(7.0, global_position)
	if t <= 0.0: queue_free()
