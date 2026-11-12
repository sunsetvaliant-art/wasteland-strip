class_name Forge
extends Node3D
## Forge mode (O): fly as the Oracle and build the world.
##   Tab        palette (vehicles, props, plants, NPCs and spawns)       1 Place   2 Phys gun   3 Delete   4 Terrain
##   WASD fly · Space up · Ctrl down · Shift fast · - / = speed           F inspect what you're looking at · P drop the player here
##   Place:    LMB place · wheel or R rotate · G toggle snap-to-ground
##   Phys gun: hold LMB to grab · wheel pull / push · hold E + mouse rotate · RMB freeze where it is · R unfreeze what you aim at
##   Terrain:  LMB raise · RMB lower · Shift+LMB smooth · Ctrl+LMB flatten · wheel brush size · [ ] strength
##   Ctrl+S save layout (and terrain) · Ctrl+Z undo · Esc closes the palette, then the pause menu

const LAYOUT := "user://forge/layout.json"
const SHIPPED := "res://forge/layout.json"
## Models you can walk into or drive under: their collision follows the mesh (a static trimesh), not a hull round it
const WALK_IN := ["village_hq", "servo_canopy"]
const BIG_PROPS := ["village_hq", "servo_canopy", "hut", "quonset", "boxes", "cont1", "bridge", "cliff1", "cliff2", "bould1", "bould2", "bould3", "rface1", "rface2", "trunk2", "bench"]
const MARKERS := {"scav": Color(0.9, 0.35, 0.2), "zombie": Color(0.45, 0.75, 0.3), "loot": Color(0.95, 0.8, 0.25), "player_spawn": Color(0.3, 0.6, 1.0), "vehicle_spawn": Color(0.7, 0.4, 0.95)}
const TOOLS := ["Place", "Phys gun", "Delete", "Terrain"]

var main
var active := false
var palette_open := false
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var speed := 25.0
var tool := 0
var selected := {}            # {"type": "vehicle"/"prop"/"plant"/"marker", "key": ...}
var place_yaw := 0.0
var ghost: Node3D
var snap_ground := true
var objects: Array = []       # everything the Forge placed (saved to the layout)
var undo: Array = []
# phys gun
var held: Node3D = null
var held_dist := 5.0
var held_local := Vector3.ZERO
var held_rot := false
var beam: MeshInstance3D
var beam_mesh: ImmediateMesh
# terrain
var brush := 12.0
var strength := 0.6
var flatten_h := 0.0
var terrain_dirty := false
var edit_t := 0.0
# ui
var ui: CanvasLayer
var hud: Label
var xhair: Label
var palette: PanelContainer
var inspector: PanelContainer
var inspect_target: Node3D

func setup(m) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_PAUSABLE
	cam = Camera3D.new()
	cam.far = 32000
	cam.near = 0.05
	cam.fov = 75
	cam.add_to_group("cameras")
	add_child(cam)
	beam_mesh = ImmediateMesh.new()
	beam = MeshInstance3D.new()
	beam.mesh = beam_mesh
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.35, 0.75, 1.0)
	bm.emission_enabled = true
	bm.emission = Color(0.3, 0.7, 1.0)
	bm.emission_energy_multiplier = 3.0
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	_build_ui()
	load_layout()

# ---------------------------------------------------------------- on / off
func toggle() -> void:
	active = not active
	var p: Player = main.player
	if active:
		if p.vehicle: p._get_out()
		p.active = false
		cam.global_position = p.head.global_position + Vector3(0, 1.0, 0)
		yaw = p.yaw
		pitch = p.pitch
		cam.current = true
		main.terrain.set_camera(cam)
		main.terrain.set_collision_target(cam)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_release()
		_set_palette(false)
		inspector.visible = false
		if ghost: ghost.queue_free(); ghost = null
		# drop the human under the Oracle
		var hit := _ray(cam.global_position, Vector3.DOWN, 3000.0)
		var pos: Vector3 = hit.position if hit else cam.global_position
		p.global_position = pos + Vector3(0, 0.2, 0)
		p.velocity = Vector3.ZERO
		p.yaw = yaw
		p.active = true
		p._apply_camera()
		main.terrain.set_collision_target(p)
	ui.visible = active
	beam.visible = false

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("forge") and not get_tree().paused:
		if not Settings.creative() and not active:
			_toast_world("Forge is off in survival mode  ·  Esc  ->  Mode to switch to creative")
			return
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active or get_tree().paused:
		return
	if e.is_action_pressed("forge_menu"):
		_set_palette(not palette_open)
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("menu") and (palette_open or inspector.visible):
		_set_palette(false)
		inspector.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if palette_open or inspector.visible:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = 0.0022 * float(Settings.get_v("motion_sensitivity"))
		if held and held_rot:
			# rotate the held object around the camera's up and right axes (GMod's E + mouse)
			var b := held.global_transform.basis
			b = b.rotated(cam.global_transform.basis.y, e.relative.x * 0.01)
			b = b.rotated(cam.global_transform.basis.x, e.relative.y * 0.01)
			held.global_transform.basis = b.orthonormalized()
			if held is RigidBody3D: (held as RigidBody3D).angular_velocity = Vector3.ZERO
		else:
			yaw -= e.relative.x * sens
			pitch = clamp(pitch - e.relative.y * sens, -1.5, 1.5)
	if e is InputEventKey and e.pressed and not e.echo:
		var k: Key = e.physical_keycode
		if k >= KEY_1 and k <= KEY_4:
			_set_tool(k - KEY_1)
		elif k == KEY_MINUS: speed = max(2.0, speed / 1.5)
		elif k == KEY_EQUAL: speed = min(2000.0, speed * 1.5)
		elif k == KEY_S and e.ctrl_pressed: save_layout()
		elif k == KEY_Z and e.ctrl_pressed: _undo()
		elif k == KEY_F: _inspect()
		elif k == KEY_P: _drop_player()
		elif k == KEY_G and tool == 0: snap_ground = not snap_ground
		elif k == KEY_R:
			if tool == 0: place_yaw += PI / 12
			elif tool == 1: _unfreeze_aimed()
		elif k == KEY_E and tool == 1 and held: held_rot = true
		elif k == KEY_BRACKETLEFT and tool == 3: strength = max(0.1, strength - 0.1)
		elif k == KEY_BRACKETRIGHT and tool == 3: strength = min(3.0, strength + 0.1)
	if e is InputEventKey and not e.pressed and e.physical_keycode == KEY_E:
		held_rot = false
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var d := 1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				if tool == 0: place_yaw += d * PI / 24
				elif tool == 1 and held: held_dist = clamp(held_dist + d * max(0.5, held_dist * 0.1), 1.5, 400.0)
				elif tool == 3: brush = clamp(brush + d * 2.0, 3.0, 120.0)
				else: speed = clamp(speed * (1.2 if d > 0 else 1 / 1.2), 2.0, 2000.0)
			MOUSE_BUTTON_LEFT:
				if tool == 0: _place()
				elif tool == 1: _grab()
				elif tool == 2: _delete_aimed()
				elif tool == 3: flatten_h = _aim_point().y if _aim() else 0.0
			MOUSE_BUTTON_RIGHT:
				if tool == 1 and held: _freeze_held()
	if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and tool == 1:
		_release()

# ---------------------------------------------------------------- per frame
func _process(dt: float) -> void:
	if not active:
		return
	cam.rotation = Vector3(pitch, yaw, 0)
	if not palette_open and not inspector.visible:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var up := (1.0 if Input.is_key_pressed(KEY_SPACE) else 0.0) - (1.0 if Input.is_key_pressed(KEY_CTRL) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0)
		var v := cam.global_transform.basis * Vector3(inp.x, 0, inp.y) + Vector3(0, up, 0)
		var sp := speed * (4.0 if Input.is_key_pressed(KEY_SHIFT) and tool != 3 else 1.0)
		cam.global_position += v * sp * dt
		var gh: float = main.height_at(cam.global_position.x, cam.global_position.z)
		cam.global_position.y = max(cam.global_position.y, gh + 0.6)
	_update_ghost()
	_update_beam()
	if tool == 3 and not palette_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		edit_t += dt
		if edit_t > 0.05 and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			_sculpt(edit_t)
			edit_t = 0.0
	var aimed := _aim()
	var aim_txt := ""
	if aimed and aimed.collider and _owner(aimed.collider):
		aim_txt = "  ·  aiming at: " + _label(_owner(aimed.collider))
	var tool_txt: String = TOOLS[tool]
	match tool:
		0: tool_txt += "  ·  " + (selected.get("name", "pick something with Tab")) + ("  ·  snap" if snap_ground else "")
		1: tool_txt += ("  ·  holding %s %.0f m" % [_label(held), held_dist]) if held else ""
		3: tool_txt += "  ·  brush %.0f m  ·  strength %.1f" % [brush, strength]
	hud.text = "FORGE  ·  %s  ·  fly %d m/s%s\n1 Place  2 Phys gun  3 Delete  4 Terrain  ·  Tab palette  ·  F inspect  ·  P drop player  ·  Ctrl+S save  ·  Ctrl+Z undo  ·  O back to human" % [tool_txt, speed, aim_txt]

func _physics_process(_dt: float) -> void:
	if not active or held == null:
		return
	if not is_instance_valid(held):
		held = null
		return
	var target := cam.global_position + -cam.global_transform.basis.z * held_dist
	var grab_world := held.global_transform * held_local
	if held is RigidBody3D:
		var rb := held as RigidBody3D
		rb.linear_velocity = (target - grab_world) * 14.0
		rb.angular_velocity *= 0.85
		if held_rot: rb.angular_velocity = Vector3.ZERO
	else:
		held.global_position += target - grab_world

# ---------------------------------------------------------------- aiming
func _ray(from: Vector3, dir: Vector3, length: float, exclude: Array = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length)
	q.exclude = exclude
	q.collide_with_areas = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r

func _aim() -> Dictionary:
	var ex := []
	if held and held is CollisionObject3D: ex.append((held as CollisionObject3D).get_rid())
	return _ray(cam.global_position, -cam.global_transform.basis.z, 3000.0, ex)

func _aim_point() -> Vector3:
	var r := _aim()
	if r: return r.position
	return cam.global_position - cam.global_transform.basis.z * 20.0

## The Forge object a collider belongs to (props, vehicles, markers, plants), or null
func _owner(n: Object) -> Node3D:
	var x := n as Node
	while x and x != main:
		if x.has_meta("forge") or x.is_in_group("vehicles"):
			return x as Node3D
		x = x.get_parent()
	return null

func _label(n: Node3D) -> String:
	if n == null: return ""
	if n.has_meta("forge"): return str(n.get_meta("forge").get("name", n.name))
	if n is Car: return (n as Car).def.get("name", n.name)
	return n.name

# ---------------------------------------------------------------- place
func _update_ghost() -> void:
	if tool != 0 or selected.is_empty() or palette_open:
		if ghost: ghost.visible = false
		return
	if ghost == null or ghost.get_meta("key", "") != selected.key:
		if ghost: ghost.queue_free()
		ghost = _make_visual(selected)
		ghost.set_meta("key", selected.key)
		_ghostify(ghost)
		add_child(ghost)
	ghost.visible = true
	ghost.global_transform = _place_xform()

func _place_xform() -> Transform3D:
	var r := _aim()
	var p: Vector3 = r.position if r else cam.global_position - cam.global_transform.basis.z * 15.0
	var lift := 0.0
	if selected.get("type") == "vehicle": lift = 1.1
	if not snap_ground and not r: lift = 0.0
	return Transform3D(Basis(Vector3.UP, yaw + place_yaw + PI), p + Vector3(0, lift, 0))

func _place() -> void:
	if selected.is_empty():
		_set_palette(true)
		return
	var n := spawn(selected, _place_xform())
	if n: undo.append({"op": "add", "node": n})

## Makes one Forge object from a palette entry. Used by placing and by loading a saved layout.
func spawn(entry: Dictionary, xf: Transform3D, frozen := false) -> Node3D:
	var n: Node3D
	match entry.type:
		"vehicle":
			var c: Car = main.spawn_vehicle(entry.key, xf.origin, 0.0, entry.get("design", {}))
			c.global_transform = xf
			n = c
		"prop" when entry.key in WALK_IN:
			var sb := StaticBody3D.new()
			var vis2 := _make_visual(entry)
			sb.add_child(vis2)
			for mi: MeshInstance3D in vis2.find_children("*", "MeshInstance3D", true, false):
				var cs3 := CollisionShape3D.new()
				cs3.shape = mi.mesh.create_trimesh_shape()
				var xf3 := Transform3D()
				var nn: Node = mi
				while nn and nn != vis2:
					if nn is Node3D: xf3 = (nn as Node3D).transform * xf3
					nn = nn.get_parent()
				cs3.transform = xf3
				sb.add_child(cs3)
			sb.add_to_group("physgun")
			main.add_child(sb)
			sb.global_transform = xf
			n = sb
		"prop":
			var rb := RigidBody3D.new()
			var vis := _make_visual(entry)
			rb.add_child(vis)
			var aabb := _aabb(vis)
			var cs := CollisionShape3D.new()
			var hull := _convex(vis)
			if hull:
				cs.shape = hull
			else:
				var b := BoxShape3D.new(); b.size = aabb.size; cs.shape = b; cs.position = aabb.get_center()
			rb.add_child(cs)
			var vol: float = max(0.001, aabb.size.x * aabb.size.y * aabb.size.z)
			rb.mass = clamp(vol * 180.0, 2.0, 8000.0)
			rb.add_to_group("physgun")
			main.add_child(rb)
			rb.global_transform = xf
			if entry.key in BIG_PROPS or frozen:
				rb.freeze = true
			n = rb
		"plant":
			var sb := StaticBody3D.new()
			var mi := MeshInstance3D.new()
			mi.mesh = main.veg.meshes[entry.key]
			sb.add_child(mi)
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			var big: bool = entry.key in Vegetation.TREES
			cyl.radius = 0.35 if big else 0.25
			cyl.height = 4.0 if big else 1.0
			cs.shape = cyl
			cs.position.y = cyl.height * 0.5
			sb.add_child(cs)
			main.add_child(sb)
			sb.global_transform = xf
			n = sb
		"marker":
			n = _make_marker(entry.key)
			main.add_child(n)
			n.global_transform = xf
	if n == null:
		return null
	n.set_meta("forge", entry)
	objects.append(n)
	return n

func _make_visual(entry: Dictionary) -> Node3D:
	match entry.type:
		"vehicle":
			var d: Dictionary = Car.catalog()[entry.key]
			var b: Node3D = load("res://assets/vehicles/%s.glb" % d.glb).instantiate()
			var holder := Node3D.new()
			b.rotation_degrees.y = -90
			holder.add_child(b)
			return holder
		"prop":
			var path: String = entry.get("path", "res://assets/props/%s.glb" % entry.key)
			return load(path).instantiate()
		"plant":
			var mi := MeshInstance3D.new()
			mi.mesh = main.veg.meshes[entry.key]
			return mi
		"marker":
			return _make_marker(entry.key)
	return Node3D.new()

func _make_marker(kind: String) -> Node3D:
	# Area3D so the Forge can aim at it; invisible to bullets and cars, hidden outside the Forge
	var a := Area3D.new()
	a.add_to_group("forge_markers")
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.8
	mi.mesh = cm
	mi.position.y = 0.9
	var m := StandardMaterial3D.new()
	m.albedo_color = MARKERS.get(kind, Color.WHITE)
	m.albedo_color.a = 0.7
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = MARKERS.get(kind, Color.WHITE) * 0.4
	mi.material_override = m
	a.add_child(mi)
	var l := Label3D.new()
	l.text = kind.replace("_", " ").to_upper()
	l.position.y = 2.2
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.outline_size = 10
	a.add_child(l)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	a.add_child(cs)
	return a

## one convex hull around every mesh in a model (thinned to ~1500 points), in the model's own space
func _convex(vis: Node3D) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	var inv := vis.global_transform.affine_inverse() if vis.is_inside_tree() else Transform3D()
	for mi: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n and n != vis:        # the mesh's transform relative to the model root
			if n is Node3D: xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for sidx in mi.mesh.get_surface_count():
			var a: PackedVector3Array = mi.mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]
			var stp := maxi(1, a.size() / 1500)
			for i in range(0, a.size(), stp):
				pts.append(xf * a[i])
	if pts.size() < 4:
		return null
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	return sh

func _old_prop_group(k: String) -> String:
	if k in ["hpistol", "hmachete", "hcrowbar", "hhatchet", "hsledge", "ammo"]: return "Weapons"
	if k in ["axle", "alt", "carb", "inj", "blower", "airf", "tbar", "droptank", "rim", "globe", "tyre", "jerry"]: return "Car parts"
	if k in ["toolbox", "htoolbox", "bench"]: return "Tools"
	if k in ["pack", "goggA", "goggW", "propane", "stove"]: return "Survival"
	if k.begins_with("bould") or k.begins_with("cliff") or k.begins_with("rface") or k in ["rocks1", "stones", "trunk2", "dbranch", "shrub3", "shrub2", "cactus"]: return "Nature"
	return "World"

func _pretty(id: String) -> String:
	var fixed := {"bolt_action_rifle_7_62": "Bolt-action rifle .303 (7.62)", "service_pistol": "Service pistol", "stick_grenade": "Stick grenade",
		"picke_dirty_01": "Pick", "old_military_crate": "Military crate", "wooden_military_crate": "Military crate (wood)",
		"engine_holden_202": "Engine: Holden 202 red six", "engine_toyota_22r": "Engine: Toyota 22R", "engine_ford_351": "Engine: Ford 351 Cleveland V8",
		"engine_jeep_40": "Engine: Jeep 4.0 six", "engine_blown_v8": "Engine: blown big-block V8", "engine_hemi_426": "Engine: 426 Hemi and 4-speed",
		"engine_pickup_v8": "Engine: Ford 400 V8 ('79 pickup)", "alternator_202": "Alternator (Holden)", "alternator_22r": "Alternator (Toyota)",
		"alternator_351": "Alternator (Ford)", "alternator_40": "Alternator (Jeep)", "aircleaner_202": "Air cleaner (Holden)",
		"old_tyre": "Old tyre", "covered_car": "Car under a tarp", "Lantern_01": "Lantern", "Barrel_01": "Barrel", "Barrel_02": "Barrel (rusty)",
		"Sofa_01": "Sofa", "Television_01": "Old telly", "overhead_crane": "Engine crane", "tire_pump": "Tyre pump"}
	if fixed.has(id): return fixed[id]
	var s := id.replace("_", " ")
	for d in [" 01", " 02", " 03", " 04"]:
		s = s.trim_suffix(d)
	return s.capitalize()

func _ghostify(n: Node) -> void:
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).transparency = 0.55
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.find_children("*", "CollisionObject3D", true, false):
		(c as CollisionObject3D).collision_layer = 0
		(c as CollisionObject3D).collision_mask = 0
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0

func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

# ---------------------------------------------------------------- phys gun
func _grab() -> void:
	var r := _aim()
	if not r or r.collider == null:
		return
	var o := _owner(r.collider)
	if o == null and r.collider is RigidBody3D:
		o = r.collider
	if o == null:
		return
	held = o
	held_dist = cam.global_position.distance_to(r.position)
	held_local = held.global_transform.affine_inverse() * r.position
	undo.append({"op": "move", "node": held, "xf": held.global_transform, "frozen": held is RigidBody3D and (held as RigidBody3D).freeze})
	if held is RigidBody3D:
		(held as RigidBody3D).freeze = false
		(held as RigidBody3D).sleeping = false
	beam.visible = true

func _release() -> void:
	held = null
	held_rot = false
	beam.visible = false

func _freeze_held() -> void:
	if held is RigidBody3D:
		var rb := held as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.freeze = true
		rb.set_meta("auto_frozen", false)
	_release()

func _unfreeze_aimed() -> void:
	var r := _aim()
	if r and r.collider:
		var o := _owner(r.collider)
		if o is RigidBody3D:
			(o as RigidBody3D).freeze = false
			(o as RigidBody3D).sleeping = false

func _update_beam() -> void:
	beam_mesh.clear_surfaces()
	if held == null or not is_instance_valid(held):
		return
	var a := cam.global_position + cam.global_transform.basis * Vector3(0.25, -0.2, -0.4)
	var b := held.global_transform * held_local
	beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var mid := a.lerp(cam.global_position - cam.global_transform.basis.z * held_dist, 0.5)
	var prev := a
	for i in range(1, 17):
		var t := i / 16.0
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)     # bends towards the object like the GMod beam
		beam_mesh.surface_add_vertex(prev)
		beam_mesh.surface_add_vertex(p)
		prev = p
	beam_mesh.surface_end()

# ---------------------------------------------------------------- delete / inspect / player
func _delete_aimed() -> void:
	var r := _aim()
	if not r or r.collider == null:
		return
	var o := _owner(r.collider)
	if o == null or o == main.player:
		return
	if o is Car and (o as Car).driver:
		return
	var entry: Dictionary = o.get_meta("forge") if o.has_meta("forge") else {"type": "vehicle", "key": (o as Car).kind}
	undo.append({"op": "del", "entry": entry, "xf": o.global_transform})
	objects.erase(o)
	o.queue_free()

func _drop_player() -> void:
	var p: Player = main.player
	# wherever you're looking, however far: the ground only has collision near the player, so past that walk the
	# line of sight along the height map
	var r := _aim()
	var at: Vector3
	if r:
		at = r.position
	else:
		var o := cam.global_position
		var d := -cam.global_transform.basis.z
		at = Vector3(o.x, main.height_at(o.x, o.z), o.z)
		var t := 2.0
		while t < 30000.0:
			var q := o + d * t
			if q.y <= main.height_at(q.x, q.z):
				at = Vector3(q.x, main.height_at(q.x, q.z), q.z)
				break
			t += maxf(2.0, t * 0.01)
	if main.buildings: main.buildings.build_near_now(at, 30.0)
	p.global_position = at + Vector3(0, 0.5, 0)
	p.velocity = Vector3.ZERO

func _undo() -> void:
	if undo.is_empty():
		return
	var u: Dictionary = undo.pop_back()
	match u.op:
		"add":
			if is_instance_valid(u.node):
				objects.erase(u.node)
				u.node.queue_free()
		"del":
			spawn(u.entry, u.xf)
		"move":
			if is_instance_valid(u.node):
				u.node.global_transform = u.xf
				if u.node is RigidBody3D:
					(u.node as RigidBody3D).linear_velocity = Vector3.ZERO
					(u.node as RigidBody3D).freeze = u.frozen

func _inspect() -> void:
	var r := _aim()
	if not r or r.collider == null:
		return
	var o := _owner(r.collider)
	if o == null:
		return
	inspect_target = o
	for c in inspector.get_children(): c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	inspector.add_child(v)
	var t := Label.new()
	t.text = _label(o)
	t.add_theme_font_size_override("font_size", 22)
	v.add_child(t)
	var pos := Label.new()
	pos.text = "x %.1f  y %.1f  z %.1f" % [o.global_position.x, o.global_position.y, o.global_position.z]
	pos.modulate = Color(1, 1, 1, 0.7)
	v.add_child(pos)
	if o is RigidBody3D:
		var rb := o as RigidBody3D
		var fz := CheckButton.new()
		fz.text = "Frozen"
		fz.button_pressed = rb.freeze
		fz.toggled.connect(func(on): rb.freeze = on)
		v.add_child(fz)
		var mrow := HBoxContainer.new()
		var ml := Label.new(); ml.text = "Mass"; ml.custom_minimum_size.x = 80
		var ms := SpinBox.new(); ms.min_value = 1; ms.max_value = 40000; ms.value = rb.mass; ms.suffix = "kg"
		ms.value_changed.connect(func(x): rb.mass = x)
		mrow.add_child(ml); mrow.add_child(ms); v.add_child(mrow)
	if o is Car:
		var car := o as Car
		var body := OptionButton.new()
		var keys := Car.catalog().keys()
		for k in keys: body.add_item(Car.catalog()[k].name)
		body.select(keys.find(car.kind))
		body.item_selected.connect(func(i):
			var xf := car.global_transform
			objects.erase(car)
			car.queue_free()
			var n := spawn({"type": "vehicle", "key": keys[i], "name": Car.catalog()[keys[i]].name}, xf)
			inspector.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
		v.add_child(body)
		var drive := Button.new()
		drive.text = "Drive it"
		drive.pressed.connect(func():
			inspector.visible = false
			toggle()
			main.player.global_position = car.global_position + Vector3(0, 2, 0)
			main.player._try_get_in())
		v.add_child(drive)
	var flip := Button.new()
	flip.text = "Set upright"
	flip.pressed.connect(func():
		o.global_transform.basis = Basis(Vector3.UP, o.global_rotation.y)
		o.global_position.y += 0.6)
	v.add_child(flip)
	var dup := Button.new()
	dup.text = "Duplicate"
	dup.pressed.connect(func():
		var e: Dictionary = o.get_meta("forge") if o.has_meta("forge") else {"type": "vehicle", "key": (o as Car).kind, "name": _label(o)}
		var xf := o.global_transform
		xf.origin += cam.global_transform.basis.x * 3.0
		var n := spawn(e, xf)
		if n: undo.append({"op": "add", "node": n}))
	v.add_child(dup)
	var del := Button.new()
	del.text = "Delete"
	del.pressed.connect(func():
		objects.erase(o)
		o.queue_free()
		inspector.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	v.add_child(del)
	var close := Button.new()
	close.text = "Close (Esc)"
	close.pressed.connect(func(): inspector.visible = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	v.add_child(close)
	inspector.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ---------------------------------------------------------------- terrain sculpt
func _sculpt(dt: float) -> void:
	var r := _aim()
	if not r:
		return
	var c: Vector3 = r.position
	var data: Terrain3DData = main.terrain.data
	var sp := 5.0
	var raise := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var smooth := Input.is_key_pressed(KEY_SHIFT)
	var flatten := Input.is_key_pressed(KEY_CTRL)
	var n := ceili(brush / sp)
	var amt := strength * dt * 8.0 * (1.0 if raise else -1.0)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var p := Vector3(roundf(c.x / sp) * sp + i * sp, 0, roundf(c.z / sp) * sp + j * sp)
			var d := Vector2(p.x - c.x, p.z - c.z).length() / brush
			if d > 1.0:
				continue
			var w := 0.5 + 0.5 * cos(d * PI)       # soft falloff
			var h := data.get_height(p)
			if is_nan(h):
				continue
			var nh := h
			if smooth:
				var avg := (data.get_height(p + Vector3(sp, 0, 0)) + data.get_height(p - Vector3(sp, 0, 0)) + data.get_height(p + Vector3(0, 0, sp)) + data.get_height(p - Vector3(0, 0, sp))) * 0.25
				if not is_nan(avg): nh = lerp(h, avg, w * min(1.0, strength * dt * 10.0))
			elif flatten:
				nh = lerp(h, flatten_h, w * min(1.0, strength * dt * 6.0))
			else:
				nh = h + amt * w
			data.set_height(p, nh)
	data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	main.terrain.collision.update()
	main.veg.refresh_area(c, brush + 10.0)
	terrain_dirty = true

# ---------------------------------------------------------------- save / load
func save_layout() -> void:
	var out := []
	for n in objects:
		if not is_instance_valid(n):
			continue
		var e: Dictionary = n.get_meta("forge").duplicate()
		var xf: Transform3D = n.global_transform
		e["xf"] = [xf.basis.x.x, xf.basis.x.y, xf.basis.x.z, xf.basis.y.x, xf.basis.y.y, xf.basis.y.z, xf.basis.z.x, xf.basis.z.y, xf.basis.z.z, xf.origin.x, xf.origin.y, xf.origin.z]
		e["frozen"] = n is RigidBody3D and (n as RigidBody3D).freeze
		out.append(e)
	DirAccess.make_dir_recursive_absolute("user://forge")
	var f := FileAccess.open(LAYOUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "objects": out}, " "))
	f.close()
	var msg := "Saved %d objects" % out.size()
	if terrain_dirty:
		DirAccess.make_dir_recursive_absolute("user://terrain")
		main.terrain.data.save_directory("user://terrain")
		terrain_dirty = false
		msg += " and the terrain"
	_toast(msg + "  ·  " + ProjectSettings.globalize_path("user://forge"))

func load_layout() -> void:
	var path := LAYOUT if FileAccess.file_exists(LAYOUT) else SHIPPED
	if not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		return
	for e in d.get("objects", []):
		var a: Array = e.xf
		var xf := Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))
		var entry: Dictionary = e.duplicate()
		entry.erase("xf"); entry.erase("frozen")
		spawn(entry, xf, e.get("frozen", false))

# ---------------------------------------------------------------- ui
func _set_tool(t: int) -> void:
	tool = t
	_release()

func _set_palette(on: bool) -> void:
	palette_open = on
	palette.visible = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

## a message even when the Forge UI isn't up
func _toast_world(t: String) -> void:
	ui.visible = true
	hud.text = ""
	_toast(t)
	get_tree().create_timer(3.5).timeout.connect(func(): if not active: ui.visible = false)

func _toast(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(20, 120)
	ui.add_child(l)
	get_tree().create_timer(3.5).timeout.connect(l.queue_free)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	ui.visible = false
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(20, 44)
	hud.add_theme_font_size_override("font_size", 16)
	hud.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_theme_constant_override("outline_size", 5)
	ui.add_child(hud)
	xhair = Label.new()
	xhair.text = "+"
	xhair.add_theme_font_size_override("font_size", 26)
	xhair.set_anchors_preset(Control.PRESET_CENTER)
	xhair.position -= Vector2(7, 18)
	ui.add_child(xhair)
	var theme := Theme.new()
	theme.default_font_size = 16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.1, 0.9)
	sb.border_color = Color(0.4, 0.7, 1.0, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	theme.set_stylebox("panel", "PanelContainer", sb)
	palette = PanelContainer.new()
	palette.theme = theme
	palette.position = Vector2(20, 110)
	palette.custom_minimum_size = Vector2(560, 860)
	palette.visible = false
	ui.add_child(palette)
	var tabs := TabContainer.new()
	palette.add_child(tabs)
	var cat := Car.catalog()
	var veh := []
	var builds := Garage.saved_designs()
	for b in builds: veh.append({"type": "vehicle", "key": builds[b].cab, "name": "★ " + b + " (your build)", "design": builds[b]})
	for k in cat: veh.append({"type": "vehicle", "key": k, "name": cat[k].name})
	_palette_page(tabs, "Vehicles", veh)
	# every placeable model, sorted into tabs: the browser build's scans, Poly Haven (CC0) and the engines
	var groups := {"Weapons": [], "Car parts": [], "Tools": [], "Survival": [], "World": [], "Nature": []}
	for f in DirAccess.get_files_at("res://assets/props"):
		var fn := f.trim_suffix(".import").trim_suffix(".remap")
		if not fn.ends_with(".glb"): continue
		var k := fn.get_basename()
		var g := _old_prop_group(k)
		if not groups[g].any(func(x): return x.key == k):
			groups[g].append({"type": "prop", "key": k, "name": _prop_name(k) + " (old scan)", "path": "res://assets/props/%s.glb" % k})
	for f in DirAccess.get_files_at("res://assets/engines"):
		var fn := f.trim_suffix(".import").trim_suffix(".remap")
		if fn.ends_with(".glb") and not groups["Car parts"].any(func(x): return x.key == fn.get_basename()):
			groups["Car parts"].append({"type": "prop", "key": fn.get_basename(), "name": _pretty(fn.get_basename()), "path": "res://assets/engines/" + fn})
	# models made in Meshy (assets/meshy, put at real size by tools/glb_place.py)
	# (the Meshy engines live in assets/engines and the guns in assets/guns, so they show up there)
	const MESHY_TAB := {"oil_cans": "Car parts", "village_hq": "World", "servo_canopy": "World"}
	const MESHY_NAME := {"oil_cans": "Vintage oil cans", "village_hq": "Old two-storey house", "servo_canopy": "Servo canopy and pumps"}
	for f in DirAccess.get_files_at("res://assets/meshy"):
		var fn := f.trim_suffix(".import").trim_suffix(".remap")
		if not fn.ends_with(".glb"): continue
		var k := fn.get_basename()
		var g: String = MESHY_TAB.get(k, "World")
		if not groups[g].any(func(x): return x.key == k):
			groups[g].append({"type": "prop", "key": k, "name": MESHY_NAME.get(k, _pretty(k)), "path": "res://assets/meshy/" + fn})
	var ph_tab := {"weapons": "Weapons", "carparts": "Car parts", "tools": "Tools", "survival": "Survival", "world": "World", "nature": "Nature"}
	for d in ph_tab:
		var base: String = "res://assets/ph/" + d
		if not DirAccess.dir_exists_absolute(base): continue
		for id in DirAccess.get_directories_at(base):
			groups[ph_tab[d]].append({"type": "prop", "key": id, "name": _pretty(id), "path": "%s/%s/%s.gltf" % [base, id, id]})
	for g in groups:
		groups[g].sort_custom(func(a, b): return a.name < b.name)
	for g in ["Weapons", "Car parts", "Tools", "Survival", "World", "Nature"]:
		var items: Array = groups[g]
		if g == "Nature":
			for k in Vegetation.DEF: items.append({"type": "plant", "key": k, "name": k.capitalize() + " (plant)"})
		_palette_page(tabs, g, items)
	var mk := []
	for k in MARKERS: mk.append({"type": "marker", "key": k, "name": k.replace("_", " ").capitalize() + (" spawn" if not k.ends_with("spawn") else "")})
	_palette_page(tabs, "NPCs & spawns", mk)
	_world_page(tabs)
	inspector = PanelContainer.new()
	inspector.theme = theme
	inspector.position = Vector2(1460, 110)
	inspector.custom_minimum_size = Vector2(380, 0)
	inspector.visible = false
	ui.add_child(inspector)

## Fly speed, the time of day and the weather
func _world_page(tabs: TabContainer) -> void:
	var vb := VBoxContainer.new()
	vb.name = "World"
	tabs.add_child(vb)
	var row := func(label: String) -> HBoxContainer:
		var hb := HBoxContainer.new()
		var l := Label.new()
		l.text = label
		l.custom_minimum_size = Vector2(170, 40)
		hb.add_child(l)
		vb.add_child(hb)
		return hb
	var r1: HBoxContainer = row.call("Fly speed (m/s)")
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 5000
	sp.step = 1
	sp.value = speed
	sp.custom_minimum_size = Vector2(160, 40)
	sp.value_changed.connect(func(v): speed = v)
	r1.add_child(sp)
	for v in [5, 25, 100, 400, 1500]:
		var b := Button.new()
		b.text = str(v)
		b.custom_minimum_size = Vector2(60, 40)
		b.pressed.connect(func():
			speed = float(v)
			sp.set_value_no_signal(v))
		r1.add_child(b)
	var r2: HBoxContainer = row.call("Time of day")
	var tl := Label.new()
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 23.95
	sl.step = 0.05
	sl.value = SkyCycle.inst.tod if SkyCycle.inst else 12.0
	sl.custom_minimum_size = Vector2(280, 40)
	tl.text = "%02d:%02d" % [int(sl.value), int(fmod(sl.value, 1.0) * 60.0)]
	sl.value_changed.connect(func(v):
		if SkyCycle.inst: SkyCycle.inst.tod = v
		tl.text = "%02d:%02d" % [int(v), int(fmod(v, 1.0) * 60.0)])
	r2.add_child(sl)
	r2.add_child(tl)
	var r3: HBoxContainer = row.call("Weather")
	for w in ["clear", "cloudy", "rain", "storm", "fog"]:
		var b := Button.new()
		b.text = w.capitalize()
		b.custom_minimum_size = Vector2(72, 40)
		b.pressed.connect(func():
			if SkyCycle.inst: SkyCycle.inst.set_weather(w, 1800.0))
		r3.add_child(b)
	var note := Label.new()
	note.text = "The weather you pick holds for half an hour. P drops the player wherever you're looking, any distance."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(520, 60)
	vb.add_child(note)

func _palette_page(tabs: TabContainer, title: String, items: Array) -> void:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	for it in items:
		var b := Button.new()
		b.text = it.name
		b.custom_minimum_size = Vector2(260, 40)
		b.clip_text = true
		b.pressed.connect(func():
			selected = it
			place_yaw = 0.0
			_set_tool(0)
			_set_palette(false))
		g.add_child(b)
	tabs.add_child(sc)

func _prop_name(k: String) -> String:
	var names := {"airf": "Air filter", "alt": "Alternator", "ammo": "Ammo box", "axle": "Axle", "barrier": "Road barrier", "bench": "Work bench",
		"blower": "Supercharger", "boom": "Boom gate", "boxes": "Shipping containers", "bridge": "Footbridge", "cabinet": "Filing cabinet",
		"cactus": "Cactus", "carb": "Carburettor", "cliff1": "Cliff face", "cliff2": "Cliff face (big)", "cont1": "Container", "crate": "Crate",
		"dbranch": "Dead branch", "droptank": "Drop tank", "drum1": "Fuel drum", "drum2": "Fuel drum (rusty)", "globe": "Globe mag wheel",
		"goggA": "Goggles", "goggW": "Welding goggles", "hcrowbar": "Crowbar", "hhatchet": "Hatchet", "hmachete": "Machete", "hpistol": "Pistol",
		"hsledge": "Sledgehammer", "htoolbox": "Toolbox (small)", "hut": "Tin hut", "inj": "Fuel injectors", "jerry": "Jerry can",
		"mcrate": "Metal crate", "pack": "Backpack", "propane": "Gas bottle", "quonset": "Quonset hut", "rim": "Steel rim", "rocks1": "Rocks",
		"shrub3": "Dry shrub", "stones": "Stones", "stove": "Pot-belly stove", "tbar": "Torsion bar", "toolbox": "Toolbox", "trunk2": "Fallen log",
		"tyre": "Tyre", "wcrate": "Wooden crate"}
	if names.has(k): return names[k]
	if k.begins_with("bould"): return "Boulder " + k.substr(5)
	return k.capitalize()
