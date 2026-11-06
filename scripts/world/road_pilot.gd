class_name RoadPilot
extends Node3D
## The Road Generator pilot: real OpenStreetMap roads round the pub and down Tweed Valley Way past the gallery,
## built at load by the Road Generator addon (addons/road-generator, MIT) from assets/roads/pilot.json
## (tools/road_pilot.py). Roads are chains of RoadPoints; junctions are the addon's RoadIntersections; the roundabout is
## an intersection with a kerbed, grassed island in the middle. Lanes follow OSM (left-hand traffic: forward lanes on
## the left of the direction of travel); the overtaking lane south of the gallery comes in and out with the addon's
## lane transitions. The old baked road meshes have these stretches cut out (tools/bake_roads.py, pilot_cut.json).

const DATA := "res://assets/roads/pilot.json"
var manager: RoadManager
var container: RoadContainer
var mat: ShaderMaterial

func setup() -> void:
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/road_rg.gdshader")
	var P := "res://assets/ph/tex/"
	mat.set_shader_parameter("marks", load("res://addons/road-generator/resources/road_texture.png"))
	mat.set_shader_parameter("asph_alb", load(P + "asphalt_02/asphalt_02_diffuse.jpg"))
	mat.set_shader_parameter("asph_nrm", load(P + "asphalt_02/asphalt_02_nor_gl.jpg"))
	mat.set_shader_parameter("asph_rgh", load(P + "asphalt_02/asphalt_02_rough.jpg"))
	mat.set_shader_parameter("tyre_alb", load(P + "aerial_asphalt_01/aerial_asphalt_01_diffuse.jpg"))
	mat.set_shader_parameter("dirt_alb", load("res://assets/ground/farm_soil_alb_h.png"))
	mat.set_shader_parameter("grass_alb", load("res://assets/ground/rough_grass_alb_h.png"))
	mat.set_shader_parameter("grass_nrm", load("res://assets/ground/rough_grass_nrm_r.png"))
	manager = RoadManager.new()
	manager.name = "RoadManager"
	add_child(manager)
	container = RoadContainer.new()
	container.name = "Pilot"
	container._auto_refresh = false
	container.material_resource = mat
	container.collider_group_name = "road"          # cars read it as sealed road
	container.flatten_terrain = false
	manager.add_child(container)
	container.setup_road_container()
	container.material_resource = mat

	# junctions first, so roads can join them
	var inters := {}
	var rbs := {}                      # roundabout id -> {"c", "r", "legs": [RoadPoint]}
	for j in d.junctions:
		var c := Vector3(j.pos[0], j.pos[1], j.pos[2])
		if j.kind == "roundabout":
			rbs[j.id] = {"c": c, "r": float(j.r), "legs": []}
			_island(c, float(j.r))
			continue
		var it := RoadIntersection.new()
		it.name = "J_" + str(j.id)
		container.add_child(it)
		it.position = c
		inters[j.id] = it

	var n_pts := 0
	for e in d.edges:
		# Built back to front: the addon puts the first lanes in its list on the side that, this way round, is the
		# left of the original direction of travel, which is where they go with left-hand traffic.
		var pts: Array = (e.pts as Array).duplicate()
		pts.reverse()
		var lanes_at: Array = []
		if e.has("lanes_at"):
			lanes_at = (e.lanes_at as Array).duplicate()
			lanes_at.reverse()
		var ea = e.b
		var eb = e.a
		var rps: Array = []
		for i in pts.size():
			var p := Vector3(pts[i][0], pts[i][1], pts[i][2])
			var a := Vector3(pts[max(i - 1, 0)][0], pts[max(i - 1, 0)][1], pts[max(i - 1, 0)][2])
			var b := Vector3(pts[min(i + 1, pts.size() - 1)][0], pts[min(i + 1, pts.size() - 1)][1], pts[min(i + 1, pts.size() - 1)][2])
			var fwd := (b - a)
			fwd.y *= 0.5
			fwd = fwd.normalized()
			var rp := RoadPoint.new()
			rp.name = "%s_%d" % [str(e.name).replace(" ", ""), n_pts]
			n_pts += 1
			container.add_child(rp)
			rp.transform = Transform3D(Basis.looking_at(-fwd, Vector3.UP), p)
			rp.lane_width = float(e.lane_w)
			rp.shoulder_width_l = 0.6
			rp.shoulder_width_r = 0.6
			rp.gutter_profile = Vector2(0.8, -0.25)
			var nf: int = int(e.fwd)
			var nr: int = int(e.rev)
			if lanes_at.size():
				nf = int(lanes_at[i])
			# Left-hand traffic. The addon lays roads out American style (lanes going your way on the right) and checks
			# for it, so the lanes on our left are labelled its "reverse" lanes: the shape and the painted lines come out
			# Australian (the overtaking lane on the left of southbound traffic), only the addon's own AI labels are
			# mirrored, and we don't use its AI.
			var dirs: Array[RoadPoint.LaneDir] = []
			if nr == 0:
				for _k in nf: dirs.append(RoadPoint.LaneDir.FORWARD)
			else:
				for _k in nf: dirs.append(RoadPoint.LaneDir.REVERSE)
				for _k in nr: dirs.append(RoadPoint.LaneDir.FORWARD)
			rp.traffic_dir = dirs
			rp.auto_lanes = true
			var mag: float = 0.4 * (Vector3(pts[min(i + 1, pts.size() - 1)][0], 0, pts[min(i + 1, pts.size() - 1)][2]) - Vector3(pts[max(i - 1, 0)][0], 0, pts[max(i - 1, 0)][2])).length() * 0.5
			rp.prior_mag = clamp(mag, 2.0, 8.0)
			rp.next_mag = clamp(mag, 2.0, 8.0)
			rps.append(rp)
		for i in rps.size() - 1:
			var ra: RoadPoint = rps[i]
			var rb: RoadPoint = rps[i + 1]
			ra._is_internal_updating = true
			rb._is_internal_updating = true
			ra.next_pt_init = ra.get_path_to(rb)
			rb.prior_pt_init = rb.get_path_to(ra)
			ra._is_internal_updating = false
			rb._is_internal_updating = false
		if ea != null and inters.has(ea):
			(inters[ea] as RoadIntersection).add_branch(rps[0])
		if eb != null and inters.has(eb):
			(inters[eb] as RoadIntersection).add_branch(rps[-1])
		if ea != null and rbs.has(ea): rbs[ea].legs.append(rps[0])
		if eb != null and rbs.has(eb): rbs[eb].legs.append(rps[-1])
	for id in rbs:
		_ring(rbs[id])
	container._auto_refresh = true
	container.rebuild_segments(true)
	for mi in container.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).set_surface_override_material(0, mat)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("ROADPILOT edges ", d.edges.size(), " points ", n_pts, " junctions ", d.junctions.size(),
		" meshes ", container.find_children("*", "MeshInstance3D", true, false).size())

## A roundabout as a real ring: a one-lane loop of RoadPoints running clockwise (left-hand traffic), with a small
## junction on the ring wherever legs come in (legs arriving close together, like a divided road's two halves, share one)
func _ring(rb: Dictionary) -> void:
	var c: Vector3 = rb.c
	var r: float = rb.r
	var groups: Array = []             # [{"ang", "legs": []}]
	for leg: RoadPoint in rb.legs:
		var a := atan2(leg.global_position.z - c.z, leg.global_position.x - c.x)
		var g = null
		for gg in groups:
			if abs(angle_difference(gg.ang, a)) < 0.5: g = gg
		if g == null:
			groups.append({"ang": a, "legs": [leg]})
		else:
			g.legs.append(leg)
			g.ang = lerp_angle(g.ang, a, 1.0 / g.legs.size())
	if groups.is_empty():
		return
	groups.sort_custom(func(x, y): return x.ang < y.ang)
	var nodes: Array = []
	for g in groups:
		var it := RoadIntersection.new()
		it.name = "RB_%d" % nodes.size()
		container.add_child(it)
		it.position = c + Vector3(cos(g.ang), 0, sin(g.ang)) * r
		nodes.append(it)
	var gap := 7.5 / r                 # arc points start this far (radians) from each ring junction
	for i in groups.size():
		var a0: float = groups[i].ang
		var a1: float = groups[(i + 1) % groups.size()].ang
		if a1 <= a0: a1 += TAU
		var span := a1 - a0 - gap * 2.0
		var n := maxi(1, int(ceil(span * r / 9.0)) + 1) if span > 0.05 else 1
		var arc: Array = []
		for k in n:
			var t := 0.5 if n == 1 else float(k) / float(n - 1)
			var a := (a0 + gap + span * t) if span > 0.05 else (a0 + (a1 - a0) * 0.5)
			var rp := RoadPoint.new()
			rp.name = "Ring_%d_%d" % [i, k]
			container.add_child(rp)
			var pos := c + Vector3(cos(a), 0, sin(a)) * r
			var tang := Vector3(-sin(a), 0, cos(a))          # increasing angle = clockwise on the map
			rp.transform = Transform3D(Basis.looking_at(-tang, Vector3.UP), pos)
			rp.lane_width = 5.0
			rp.shoulder_width_l = 0.4
			rp.shoulder_width_r = 0.4
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.auto_lanes = true
			var mag: float = clamp(r * (span / max(n - 1, 1) if n > 1 else 0.3) * 0.36, 1.0, 5.0)
			rp.prior_mag = mag
			rp.next_mag = mag
			arc.append(rp)
		for k in arc.size() - 1:
			arc[k]._is_internal_updating = true
			arc[k + 1]._is_internal_updating = true
			arc[k].next_pt_init = arc[k].get_path_to(arc[k + 1])
			arc[k + 1].prior_pt_init = arc[k + 1].get_path_to(arc[k])
			arc[k]._is_internal_updating = false
			arc[k + 1]._is_internal_updating = false
		(nodes[i] as RoadIntersection).add_branch(arc[0])
		(nodes[(i + 1) % nodes.size()] as RoadIntersection).add_branch(arc[-1])
	for i in groups.size():
		for leg in groups[i].legs:
			(nodes[i] as RoadIntersection).add_branch(leg)

## The roundabout's middle: a mountable concrete kerb ring and a grassed island, leaving a ring road about 7 m wide
func _island(c: Vector3, r: float) -> void:
	var ir: float = max(r - 3.6, 3.0)
	var kerb := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = ir
	km.bottom_radius = ir + 0.15
	km.height = 0.5
	km.radial_segments = 48
	kerb.mesh = km
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.72, 0.7, 0.66)
	cm.roughness = 0.9
	kerb.material_override = cm
	kerb.position = c + Vector3(0, 0.05, 0)
	add_child(kerb)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = ir - 0.35
	tm.bottom_radius = ir - 0.35
	tm.height = 0.52
	tm.radial_segments = 48
	top.mesh = tm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/ground/pasture_alb_h.png")
	gm.albedo_color = Color(0.6, 0.66, 0.48)
	gm.uv1_triplanar = true
	gm.uv1_scale = Vector3.ONE
	gm.roughness = 0.95
	top.material_override = gm
	top.position = c + Vector3(0, 0.08, 0)
	add_child(top)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = ir
	sh.height = 0.5
	cs.shape = sh
	body.add_child(cs)
	body.position = c + Vector3(0, 0.05, 0)
	add_child(body)
