class_name SkidMarks
extends MultiMeshInstance3D
## Every car's rubber marks, one multimesh of thin dark quads laid on the ground. A ring buffer: the oldest go first.

const MAX := 6000
var next := 0

func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.03)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.6
	m.render_priority = -1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = q
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true

func add(a: Vector3, b: Vector3, n: Vector3, width: float, strength: float) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.01:
		return
	var z := d / L
	var x := n.cross(z).normalized()
	var y := z.cross(x).normalized()
	var basis := Basis(x * width, y, z * (L + 0.02))
	multimesh.set_instance_transform(next, Transform3D(basis, (a + b) * 0.5))
	multimesh.set_instance_color(next, Color(0.02, 0.02, 0.02, strength))
	next = (next + 1) % MAX
	multimesh.visible_instance_count = max(multimesh.visible_instance_count, next if multimesh.visible_instance_count < MAX else MAX)
	# the multimesh's bounds grow to cover wherever marks have been laid
	custom_aabb = custom_aabb.merge(AABB(a - Vector3.ONE, Vector3.ONE * 2.0)) if custom_aabb.size != Vector3.ZERO else AABB(a - Vector3.ONE * 2.0, Vector3.ONE * 4.0)
