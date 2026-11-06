class_name Hearing
extends RefCounted
## Sound the AI can hear. Anything that makes a racket calls emit(); every NPC in range gets hear() with how loud it
## was where they stand (1 = right next to it, 0 = edge of hearing).

static func emit(tree: SceneTree, pos: Vector3, radius: float, kind: String, source: Node = null) -> void:
	if tree == null or radius <= 0.0:
		return
	for n in tree.get_nodes_in_group("npcs"):
		if n == source or not is_instance_valid(n):
			continue
		var d: float = (n as Node3D).global_position.distance_to(pos)
		if d < radius:
			n.hear(pos, 1.0 - d / radius, kind, source)
