class_name StepUp
extends RefCounted
## move_and_slide that steps up onto things: a slab edge, a doorstep, the bottom tread of a flight, a kerb. When
## walking along the ground into something wall-like, try the move again from a step higher and, if there's floor
## to land on up there, go up onto it. Everyone who walks uses it (you, zombies, scavs).

const MAX_STEP := 0.42

static func slide(body: CharacterBody3D) -> void:
	var hv := Vector3(body.velocity.x, 0, body.velocity.z)
	var was_floor := body.is_on_floor()
	body.move_and_slide()
	if not was_floor or hv.length() < 0.3:
		return
	var blocked := false
	for i in body.get_slide_collision_count():
		if body.get_slide_collision(i).get_normal().y < 0.55:
			blocked = true
			break
	if not blocked:
		return
	var dt := body.get_physics_process_delta_time()
	var fwd := hv.normalized() * maxf(hv.length() * dt, 0.18)
	var xf := body.global_transform
	var up := Vector3(0, MAX_STEP, 0)
	if body.test_move(xf, up):
		return                                        # no headroom
	var xf2 := xf.translated(up)
	if body.test_move(xf2, fwd):
		return                                        # still a wall up there
	var xf3 := xf2.translated(fwd)
	var col := KinematicCollision3D.new()
	if body.test_move(xf3, -up - Vector3(0, 0.05, 0), col) and col.get_normal().y > 0.7:
		body.global_position = xf3.origin + col.get_travel()
		body.velocity.y = 0.0
