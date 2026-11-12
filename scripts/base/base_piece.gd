class_name BasePiece
extends StaticBody3D
## One piece of something you built: a floor, a wall, a doorway, a window wall, a half wall, stairs, a storage crate.
## Wood, tin or brick. Zombies beat on it until it gives way.

const KINDS := ["wall", "doorway", "window", "half", "floor", "stairs", "crate"]
const NAMES := {"wall": "Wall", "doorway": "Doorway", "window": "Window wall", "half": "Half wall", "floor": "Floor / roof", "stairs": "Stairs", "crate": "Storage crate"}
const TIERS := ["wood", "tin", "brick"]
const HP := {"wood": 250.0, "tin": 500.0, "brick": 1000.0}
const MAT := {"wood": "timber", "tin": "tin:grey", "brick": "brick"}
const BASE_COST := {"wood": {"plank": 3, "nails": 1}, "tin": {"tin_sheet": 2, "plank": 1, "nails": 1}, "brick": {"brick": 6}}
const SCALE := {"wall": 1.0, "doorway": 1.0, "window": 1.0, "half": 0.5, "floor": 1.0, "stairs": 2.0, "crate": 1.0}

var kind := "wall"
var tier := "wood"
var hp := 250.0

static func cost(k: String, t: String) -> Dictionary:
	if k == "crate": return {"plank": 4, "nails": 1}
	var out := {}
	for id in BASE_COST[t]:
		out[id] = maxi(1, int(ceil(float(BASE_COST[t][id]) * float(SCALE[k]))))
	return out

## The boxes a piece is made of: [centre, size, basis]
static func boxes(k: String) -> Array:
	var I := Basis.IDENTITY
	match k:
		"wall": return [[Vector3(0, 1.4, 0), Vector3(3.0, 2.8, 0.15), I]]
		"half": return [[Vector3(0, 0.55, 0), Vector3(3.0, 1.1, 0.15), I]]
		"doorway": return [[Vector3(-1.0, 1.4, 0), Vector3(1.0, 2.8, 0.15), I], [Vector3(1.0, 1.4, 0), Vector3(1.0, 2.8, 0.15), I], [Vector3(0, 2.45, 0), Vector3(1.0, 0.7, 0.15), I]]
		"window": return [[Vector3(0, 0.5, 0), Vector3(3.0, 1.0, 0.15), I], [Vector3(0, 2.4, 0), Vector3(3.0, 0.8, 0.15), I], [Vector3(-1.05, 1.5, 0), Vector3(0.9, 1.0, 0.15), I], [Vector3(1.05, 1.5, 0), Vector3(0.9, 1.0, 0.15), I]]
		"floor": return [[Vector3(0, -0.1, 0), Vector3(3.0, 0.2, 3.0), I]]
		"stairs":
			var ang := atan2(2.8, 6.0)
			return [[Vector3(0, 1.4 - 0.07, 0), Vector3(3.0, 0.14, sqrt(36.0 + 7.84)), Basis(Vector3.RIGHT, -ang)]]
		"crate": return [[Vector3(0, 0.35, 0), Vector3(1.1, 0.7, 0.7), I]]
	return []

func setup(k: String, t: String, ghost := false) -> void:
	kind = k
	tier = "wood" if k == "crate" else t
	hp = HP[tier]
	collision_layer = 0 if ghost else 1
	collision_mask = 0
	var mat: Material = BuildGen.mat(MAT[tier])
	for b in boxes(k):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		mi.mesh = bm
		mi.transform = Transform3D(b[2], b[0])
		mi.material_override = mat
		mi.visibility_range_end = 260.0
		add_child(mi)
		if ghost: continue
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		cs.transform = mi.transform
		add_child(cs)
	if ghost: return
	add_to_group("base_pieces")
	if k == "crate":
		if not has_meta("inv"): set_meta("inv", Items.new_grid(8, 5))
		set_meta("container", "crate")
		set_meta("empty", true)

func tint(c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for ch in get_children():
		if ch is MeshInstance3D: ch.material_override = m

func hint() -> String:
	return "%s (%s) %d%%" % [NAMES[kind], tier, int(100.0 * hp / HP[tier])]

## A zombie beating on it
func hit(dmg: float) -> void:
	hp -= dmg
	if hp <= 0.0:
		var a := AudioStreamPlayer3D.new()
		a.stream = Gun.sfx("hammer_nails")
		a.pitch_scale = 0.5
		get_parent().add_child(a)
		a.global_position = global_position
		a.play()
		a.finished.connect(a.queue_free)
		queue_free()
