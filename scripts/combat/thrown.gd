class_name Thrown
extends Node
## Rides on something you've thrown until it hits: hurts who it hits, makes the noise the dead come to, breaks if it's
## glass, bursts into flame if it's a petrol bomb. What's left is an ordinary thing on the ground to pick up again.

var rb: RigidBody3D
var who
var spec: Dictionary
var done := false
var life := 0.0

func arm(body: RigidBody3D, thrower, s: Dictionary) -> void:
	rb = body
	who = thrower
	spec = s
	rb.contact_monitor = true
	rb.max_contacts_reported = 3
	rb.collision_mask = 1 | NPC.LAYER
	rb.body_entered.connect(_hit)

func _process(dt: float) -> void:
	life += dt
	if life > 6.0 and not done: _land(null)

func _hit(body: Node) -> void:
	if done or body == who: return
	_land(body)

func _land(body) -> void:
	done = true
	var pos := rb.global_position
	var dir := rb.linear_velocity.normalized()
	if body is NPC and not body.dead:
		var part: String = body.rig.part_at(pos, dir) if body.rig else "chest"
		var dmg := float(spec.get("dmg", 20.0))
		body.take_hit({part: dmg * (1.5 if part == "head" and spec.get("blade", false) else 1.0)}, dir, pos, 5.0, who)
		if is_instance_valid(body) and not body.dead: body.stagger = maxf(body.stagger, 0.6)
	Hearing.emit(get_tree(), pos, float(spec.get("loud", 12.0)), "thump", who)
	rb.collision_mask = 1
	if spec.get("fire", false):
		Fire.light(rb.get_parent(), pos, who)
	if spec.get("breaks", false):
		rb.queue_free()
	else:
		queue_free()
