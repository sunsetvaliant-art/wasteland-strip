class_name Roadside
extends Node3D
## 0.2.74: the small stuff along the roads, cheap: one multimesh per kind per 128 m tile, no collision, drawn only up
## close, built a tile a frame.
##   Guide posts: the white posts with a red reflector both sides of every country road, about 50 m apart (none in
##     town, where the kerbs and street lights are), set back off the seal.
##   Letterboxes: one at the front of every house lot, at the boundary on the road side (a brick pier or a box on a
##     post), and on bin night a red-lid and a yellow-lid wheelie bin out on the verge in front of about a third.

const TILE := 128.0
const R := 300.0
const DROP := 380.0
const HOUSES := ["qlder", "cottage", "brick", "two_storey"]
var main
var tiles := {}          # Vector2i -> Node3D
var _meshes := {}
var _mat: StandardMaterial3D
var _t := 0.0

func setup(m) -> void:
	main = m
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.75
	_meshes["guide"] = _guide_mesh()
	_meshes["lb_pier"] = _pier_mesh()
	_meshes["lb_post"] = _post_box_mesh()
	_meshes["bin_red"] = _bin_mesh(Color(0.72, 0.1, 0.08))
	_meshes["bin_yel"] = _bin_mesh(Color(0.9, 0.72, 0.1))

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.player == null or Roads.inst == null: return
	_t = 0.25
	if OS.get_environment("ROADSIDE_OFF") != "": return
	var me: Vector3 = main.player.vehicle.global_position if main.player.vehicle else main.player.global_position
	if main.forge and main.forge.active: me = main.forge.cam.global_position
	for k in tiles.keys():
		var c := Vector2((k.x + 0.5) * TILE, (k.y + 0.5) * TILE)
		if c.distance_to(Vector2(me.x, me.z)) > DROP:
			if tiles[k]: (tiles[k] as Node).queue_free()
			tiles.erase(k)
	# one new tile a pass, nearest first
	var mc := Vector2i(floori(me.x / TILE), floori(me.z / TILE))
	var n := int(ceil(R / TILE))
	var best := Vector2i(1 << 30, 0)
	var bd := INF
	for gx in range(mc.x - n, mc.x + n + 1):
		for gz in range(mc.y - n, mc.y + n + 1):
			var k := Vector2i(gx, gz)
			if tiles.has(k): continue
			var d := Vector2((gx + 0.5) * TILE, (gz + 0.5) * TILE).distance_to(Vector2(me.x, me.z))
			if d < R and d < bd:
				bd = d
				best = k
	if bd < INF:
		tiles[best] = _build(best)

func _build(k: Vector2i) -> Node3D:
	var x0 := k.x * TILE
	var z0 := k.y * TILE
	var org := Vector3(x0, 0, z0)
	var put := {}         # kind -> [Transform3D]
	_guides(x0, z0, put)
	_letterboxes(x0, z0, put)
	var root := Node3D.new()
	root.name = "Roadside_%d_%d" % [k.x, k.y]
	add_child(root)
	root.position = org
	for kind in put:
		var xfs: Array = put[kind]
		if xfs.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[kind]
		mm.instance_count = xfs.size()
		for i in xfs.size(): mm.set_instance_transform(i, Transform3D((xfs[i] as Transform3D).basis, (xfs[i] as Transform3D).origin - org))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 170.0 if kind == "guide" else 120.0
		root.add_child(mmi)
	return root

## posts along the country roads: walk each road segment in the tile, both sides, every 50 m of road
func _guides(x0: float, z0: float, put: Dictionary) -> void:
	var seen := {}
	var out: Array = []
	for gx in range(floori(x0 / 32.0), floori((x0 + TILE) / 32.0)):
		for gz in range(floori(z0 / 32.0), floori((z0 + TILE) / 32.0)):
			var a: PackedFloat32Array = Roads.inst._seg.get(Vector2i(gx, gz), PackedFloat32Array())
			for i in range(0, a.size(), 5):
				var key := Vector4(a[i], a[i + 1], a[i + 2], a[i + 3])
				if seen.has(key): continue
				seen[key] = true
				var hs := a[i + 4]
				if hs < 2.6: continue                 # driveways and farm tracks
				var A := Vector2(a[i], a[i + 1]); var B := Vector2(a[i + 2], a[i + 3])
				var L := A.distance_to(B)
				if L < 1.0: continue
				var dir := (B - A) / L
				var nrm := Vector2(-dir.y, dir.x)
				# posts at fixed spacing along the road from a world-anchored phase, so neighbouring segments line up
				var s0 := fposmod(-(A.dot(dir)), 50.0)
				var s := s0
				while s < L:
					var p := A + dir * s
					s += 50.0
					if p.x < x0 or p.x >= x0 + TILE or p.y < z0 or p.y >= z0 + TILE: continue
					for side in [-1.0, 1.0]:
						var q: Vector2 = p + nrm * side * (hs + 1.4)
						if main.veg:
							var m: Color = main.veg.sample(q.x, q.y)
							if m.b > 0.12: continue          # town
							var m2: Color = main.veg.sample2(q.x, q.y)
							if m2.b > 0.4: continue          # over water (a bridge)
						if Roads.inst.edge_dist(q.x, q.y) < 0.9: continue     # another road's here (a junction)
						if Buildings.blocked(q.x, q.y, 0.3): continue
						var y: float = main.height_at(q.x, q.y)
						if is_nan(y): continue
						# the reflector faces the traffic coming on that side
						var face := atan2(dir.x * side, dir.y * side)
						out.append(Transform3D(Basis(Vector3.UP, face), Vector3(q.x, y, q.y)))
	put["guide"] = out

func _letterboxes(x0: float, z0: float, put: Dictionary) -> void:
	var b: Buildings = Buildings.inst
	if b == null: return
	var piers: Array = []; var posts: Array = []; var reds: Array = []; var yels: Array = []
	var cell := Vector2i(floori((x0 + TILE * 0.5) / Buildings.CELL), floori((z0 + TILE * 0.5) / Buildings.CELL))
	for gx in range(cell.x - 1, cell.x + 2):
		for gz in range(cell.y - 1, cell.y + 2):
			for i in b.cells.get(Vector2i(gx, gz), []):
				var l: Array = b.lots[i]
				var x := float(l[1]); var z := float(l[2])
				if x < x0 or x >= x0 + TILE or z < z0 or z >= z0 + TILE: continue
				if not str(l[0]) in HOUSES: continue
				var basis := Basis(Vector3.UP, float(l[3]))
				var w := float(l[4]); var d := float(l[5])
				# the side facing the road: the one whose middle is nearest a road's edge
				var best := -1; var bd := 1e9
				var sides := [[Vector3(0, 0, 1), d * 0.5, w], [Vector3(0, 0, -1), d * 0.5, w], [Vector3(1, 0, 0), w * 0.5, d], [Vector3(-1, 0, 0), w * 0.5, d]]
				for si in sides.size():
					var dv: Vector3 = basis * (sides[si][0] as Vector3)
					var mid := Vector3(x, 0, z) + dv * (float(sides[si][1]) + 2.0)
					var ed: float = Roads.inst.edge_dist(mid.x, mid.z)
					if ed < bd: bd = ed; best = si
				if best < 0 or bd > 14.0: continue
				var dvb: Vector3 = basis * (sides[best][0] as Vector3)
				var along: Vector3 = basis * Vector3(sides[best][0].z, 0, -sides[best][0].x)
				var rng := RandomNumberGenerator.new()
				rng.seed = int(l[6]) * 31 + 7
				# along to one side of the front (the driveway's the other), out to just short of the road
				var lat := float(sides[best][2]) * rng.randf_range(0.25, 0.42) * (1.0 if rng.randf() < 0.5 else -1.0)
				var p := Vector3(x, 0, z) + dvb * float(sides[best][1]) + along * lat
				var ok := false
				for step in 40:
					p += dvb * 0.5
					var ed2: float = Roads.inst.edge_dist(p.x, p.z)
					if ed2 < 2.2:
						ok = ed2 > 0.6
						break
				if not ok: continue
				# a full house build sits its own letterbox? no: these are the only ones
				var y: float = main.height_at(p.x, p.z)
				var face := atan2(dvb.x, dvb.z)
				var xf := Transform3D(Basis(Vector3.UP, face), Vector3(p.x, y, p.z))
				if str(l[0]) == "brick" or rng.randf() < 0.35: piers.append(xf)
				else: posts.append(xf)
				# bins out on the verge, between the letterbox and the road
				if rng.randf() < 0.33:
					var bp := p + along * (1.1 if lat > 0.0 else -1.1) + dvb * 0.3
					var by: float = main.height_at(bp.x, bp.z)
					reds.append(Transform3D(Basis(Vector3.UP, face + rng.randf_range(-0.2, 0.2)), Vector3(bp.x, by, bp.z)))
					var bp2 := bp + along * (0.75 if lat > 0.0 else -0.75)
					yels.append(Transform3D(Basis(Vector3.UP, face + rng.randf_range(-0.2, 0.2)), Vector3(bp2.x, main.height_at(bp2.x, bp2.z), bp2.z)))
	put["lb_pier"] = piers
	put["lb_post"] = posts
	put["bin_red"] = reds
	put["bin_yel"] = yels

# ---------------------------------------------------------------- the meshes (vertex coloured boxes)
static func _box(st: SurfaceTool, size: Vector3, c: Vector3, col: Color, rot := 0.0) -> void:
	var bm := BoxMesh.new(); bm.size = size
	var arr := bm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var b := Basis(Vector3.RIGHT, rot)
	for i in idx:
		st.set_color(col)
		st.set_normal(b * n[i])
		st.add_vertex(b * v[i] + c)

static func _commit(st: SurfaceTool) -> ArrayMesh:
	return st.commit()

func _guide_mesh() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.1, 1.0, 0.06), Vector3(0, 0.5, 0), Color(0.92, 0.92, 0.9))
	_box(st, Vector3(0.102, 0.18, 0.062), Vector3(0, 0.82, 0), Color(0.05, 0.05, 0.05))
	_box(st, Vector3(0.05, 0.1, 0.01), Vector3(0, 0.82, 0.035), Color(0.85, 0.05, 0.04))
	return _commit(st)

func _pier_mesh() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var brick := Color(0.55, 0.27, 0.18)
	_box(st, Vector3(0.45, 1.15, 0.45), Vector3(0, 0.575, 0), brick)
	_box(st, Vector3(0.52, 0.06, 0.52), Vector3(0, 1.18, 0), Color(0.6, 0.58, 0.55))
	_box(st, Vector3(0.24, 0.07, 0.02), Vector3(0, 0.95, 0.23), Color(0.12, 0.12, 0.12))      # the slot
	_box(st, Vector3(0.2, 0.08, 0.01), Vector3(0, 0.7, 0.23), Color(0.75, 0.65, 0.3))        # the number plate
	return _commit(st)

func _post_box_mesh() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0.09, 1.0, 0.09), Vector3(0, 0.5, 0), Color(0.45, 0.33, 0.22))
	_box(st, Vector3(0.32, 0.28, 0.4), Vector3(0, 1.1, 0.02), Color(0.2, 0.32, 0.22))
	_box(st, Vector3(0.33, 0.06, 0.41), Vector3(0, 1.26, 0.02), Color(0.18, 0.28, 0.2))
	_box(st, Vector3(0.22, 0.05, 0.01), Vector3(0, 1.15, 0.225), Color(0.1, 0.1, 0.1))
	return _commit(st)

func _bin_mesh(lid: Color) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := Color(0.13, 0.3, 0.16)
	_box(st, Vector3(0.56, 0.95, 0.68), Vector3(0, 0.5, 0), body)
	_box(st, Vector3(0.6, 0.05, 0.74), Vector3(0, 1.0, 0.01), lid)
	_box(st, Vector3(0.5, 0.04, 0.05), Vector3(0, 1.0, -0.37), Color(0.1, 0.1, 0.1))       # the handle at the back
	_box(st, Vector3(0.06, 0.2, 0.2), Vector3(0.26, 0.1, -0.28), Color(0.05, 0.05, 0.05))  # wheels
	_box(st, Vector3(0.06, 0.2, 0.2), Vector3(-0.26, 0.1, -0.28), Color(0.05, 0.05, 0.05))
	return _commit(st)
