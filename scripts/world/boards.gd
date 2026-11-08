class_name Boards
extends StaticBody3D
## Planks nailed across a doorway or window. Shuts it for good until they're prised off (F with a hammer: you get
## the planks back) or a zombie beats them in (it takes a while: each plank gives way in turn).

const HP_PER := 45.0
var host: Node3D                 # the door or window they're on
var planks: Array = []
var hp := 0.0
var key := ""                    # remembered by Buildings

## w x h opening in the parent's frame (centre at (cx, cy), wall plane z = 0); on the side `side` (+1 / -1 in z)
func setup(w: float, h: float, cx: float, cy: float, side: float, n: int) -> void:
	add_to_group("boards")
	collision_layer = 1
	var mat: Material = BuildGen.mat("timber")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for k in n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w + 0.3, 0.15, 0.025)
		mi.mesh = bm
		mi.material_override = mat
		var y := cy - h * 0.38 + h * 0.76 * (float(k) / maxf(n - 1, 1))
		mi.position = Vector3(cx, y, side * 0.07)
		mi.rotation.z = rng.randf_range(-0.22, 0.22)
		add_child(mi)
		planks.append(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w + 0.1, h, 0.06)
	cs.shape = bs
	cs.position = Vector3(cx, cy, side * 0.07)
	add_child(cs)
	hp = n * HP_PER

func hint() -> String:
	return "Boarded up (%d planks) · F prise off with a hammer" % planks.size()

## A zombie beating on it
func hit(dmg: float) -> void:
	hp -= dmg
	while planks.size() > 0 and hp < (planks.size() - 1) * HP_PER:
		var p: MeshInstance3D = planks.pop_back()
		p.queue_free()
		_thud()
	if planks.is_empty():
		_gone()

func _thud() -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = Gun.sfx("hammer_nails")
	a.pitch_scale = 0.6
	add_child(a)
	a.play()

func _gone() -> void:
	if Buildings.inst and key != "":
		Buildings.inst.boards.erase(key)
	if host and is_instance_valid(host) and "boards" in host:
		host.boards = null
	queue_free()

## Prised off by you: how many planks come back
func pry() -> int:
	var n := planks.size()
	planks.clear()
	_gone()
	return n
