class_name Streets
extends Node3D
## Streets by the block (0.2.54, tools/make_streets.py): every block the sealed roads close off has a kerb profile
## (shopping street, old town, estate, industrial, island, roundabout), and the street round it is built from that:
## kerb and gutter as real geometry you can hit (roll-top in the estates, laybacks at driveways, ramps at
## crossings), shopping-street footpaths paved at kerb height to the shop fronts, concrete paths and driveway
## crossovers, the kerb returns' corners sealed, zebras, stop and give-way lines, car parks laid out in bays (all
## painted into the ground with the roads), and the furniture: traffic lights, bus stops and shelters, street
## lights, power poles, bins, benches, stop and give-way signs. Built a 128 m tile at a time near you.
static var inst: Streets = null

const TILE := 128.0
const BUILD_R := 480.0
const DROP_R := 620.0
const COLLIDE_R := 170.0
const UNCOLLIDE_R := 240.0
const DRAW_KERB := 260.0

## kerb cross-section: stations (m from the kerb line, + into the block) and the height at each, per profile
## (profile ids as in make_streets.py: MAIN 0, TOWN 1, EST 2, IND 3, ISL 4, RBT 5, LAY 6, RAMP 7)
const STA := [-0.40, -0.02, 0.0, 0.04, 0.20, 0.45, 0.80]
const PH := [
	[0.0, -0.02, -0.015, 0.15, 0.155, 0.155, 0.155],    # MAIN: up onto the paved footpath
	[0.0, -0.02, -0.015, 0.15, 0.155, 0.10, 0.0],       # TOWN: barrier kerb, back down to the verge
	[0.0, -0.015, -0.01, 0.03, 0.085, 0.10, 0.0],       # EST: roll-top
	[0.0, -0.02, -0.015, 0.15, 0.155, 0.10, 0.0],       # IND
	[0.0, -0.02, -0.015, 0.15, 0.155, 0.12, 0.05],      # ISL
	[0.0, -0.01, 0.0, 0.03, 0.07, 0.10, 0.10],          # RBT: mountable
	[0.0, -0.02, -0.015, 0.0, 0.03, 0.045, 0.0],        # LAY: driveway layback
	[0.0, -0.02, -0.015, 0.0, 0.02, 0.07, 0.0],         # RAMP: kerb ramp at a crossing
]
const SLAB_Y := 0.155

var main
var _bytes := PackedByteArray()
var _index := {}             # Vector2i -> [offset, length]
var _ox := 0.0
var _oz := 0.0
var _tiles := {}             # Vector2i -> {node, paint: Array[Node], body, data}
var _masks := {}             # Vector2i -> PackedByteArray (unpacked bits, 128 x 128) or empty
var _t := 0.0
var _kmat: StandardMaterial3D
var _furn_mesh := {}         # kind -> Mesh
var _paint_mat: ShaderMaterial
var _busy := false
var _slice_t := 0
var worst_slice := 0          # longest stretch one tile build held the frame (us), for tests and F9
var _mark_mat: ShaderMaterial

func setup(m) -> void:
	main = m
	inst = self
	var path := "res://assets/world/streets.bin"
	if not FileAccess.file_exists(path) or OS.get_environment("STREETS_OFF") != "": return
	_bytes = FileAccess.get_file_as_bytes(path)
	if _bytes.size() < 16 or _bytes.slice(0, 4).get_string_from_ascii() != "STR3":
		push_warning("streets: bad file"); _bytes = PackedByteArray(); return
	_ox = _bytes.decode_float(4); _oz = _bytes.decode_float(8)
	var n := _bytes.decode_u32(12)
	for i in n:
		var o := 16 + i * 20
		_index[Vector2i(_bytes.decode_s32(o), _bytes.decode_s32(o + 4))] = [_bytes.decode_u32(o + 8), _bytes.decode_u32(o + 12), _bytes.decode_u32(o + 16)]
	_kmat = StandardMaterial3D.new()
	_kmat.albedo_texture = load("res://assets/ground/concrete_alb_h.png")
	_kmat.normal_enabled = true
	_kmat.normal_texture = load("res://assets/ground/concrete_nrm_r.png")
	_kmat.normal_scale = 0.5
	_kmat.uv1_triplanar = true
	_kmat.uv1_world_triplanar = true
	_kmat.uv1_scale = Vector3.ONE * 0.3
	_kmat.albedo_color = Color(0.97, 0.95, 0.91)
	_kmat.roughness = 0.9
	_kmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_furniture_meshes()
	print("STREETS %d tiles" % n)

# ------------------------------------------------------------------ reading a tile
func _tile_data(k: Vector2i) -> Dictionary:
	var e = _index.get(k)
	if e == null: return {}
	var sp := StreamPeerBuffer.new()
	sp.data_array = _bytes.slice(int(e[0]), int(e[0]) + int(e[1]))
	var d := {"kerb": [], "paint": [], "furn": [], "slab": []}
	for _i in sp.get_u32():
		var prof := sp.get_u32()
		var np := sp.get_u32()
		var pts := PackedVector2Array(); pts.resize(np)
		var kinds := PackedInt32Array(); kinds.resize(np)
		for j in np:
			pts[j] = Vector2(sp.get_float(), sp.get_float()); kinds[j] = sp.get_u32()
		d.kerb.append([prof, pts, kinds])
	for _i in sp.get_u32():
		var surf := sp.get_float(); var style := sp.get_float(); var nv := sp.get_u32()
		var tri := sp.get_data(nv * 8)[1] as PackedByteArray
		d.paint.append([surf, style, tri.to_float32_array()])
	for _i in sp.get_u32():
		d.furn.append([sp.get_u32(), sp.get_float(), sp.get_float(), sp.get_float(), sp.get_float()])
	for _i in sp.get_u32():
		var nv := sp.get_u32()
		var tri := (sp.get_data(nv * 16)[1] as PackedByteArray).to_float32_array()     # x, z, anchor x, anchor z
		var rings := []
		for _r in sp.get_u32():
			var nr := sp.get_u32()
			rings.append((sp.get_data(nr * 16)[1] as PackedByteArray).to_float32_array())
		d.slab.append([tri, rings])
	d["fence"] = []
	for _i in sp.get_u32():
		var fm := sp.get_u32(); var col := sp.get_u32(); var np2 := sp.get_u32()
		var fp := (sp.get_data(np2 * 8)[1] as PackedByteArray).to_float32_array()
		d.fence.append([fm, col, fp])
	var ml := sp.get_u32()
	d["mask"] = sp.get_data(ml)[1] if ml > 0 else PackedByteArray()
	return d

## paved or kerbed here: nothing grows (veg asks this for every plant)
static func hard(x: float, z: float) -> bool:
	if inst == null or inst._index.is_empty(): return false
	var k := Vector2i(floori((x - inst._ox) / TILE), floori((z - inst._oz) / TILE))
	var m = inst._masks.get(k)
	if m == null:
		m = PackedByteArray()
		if inst._index.has(k):
			# 0.2.56: straight to the mask (the index says where it is), not the whole tile
			var e: Array = inst._index[k]
			var mo := int(e[0]) + int(e[2])
			var ml := inst._bytes.decode_u32(mo)
			if ml > 0: m = inst._bytes.slice(mo + 4, mo + 4 + ml).decompress(2048, FileAccess.COMPRESSION_DEFLATE)
		inst._masks[k] = m
	var mb: PackedByteArray = m
	if mb.size() < 2048: return false
	var i := int(x - inst._ox - k.x * TILE); var j := int(z - inst._oz - k.y * TILE)
	if i < 0 or j < 0 or i > 127 or j > 127: return false
	var bit := j * 128 + i
	return (mb[bit >> 3] >> (7 - (bit & 7))) & 1 == 1

# ------------------------------------------------------------------ streaming
func _anchor() -> Vector3:
	var me: Vector3 = main.player.global_position if main.player else Vector3.ZERO
	if main.player and main.player.vehicle: me = main.player.vehicle.global_position
	if main.forge and main.forge.active: me = main.forge.cam.global_position
	return me

func _process(dt: float) -> void:
	var _pt := Prof.t()
	_process_inner(dt)
	Prof.add("streets", _pt)

func _process_inner(dt: float) -> void:
	if _index.is_empty() or main == null or main.terrain == null or main.terrain.data == null: return
	_t -= dt
	if _t > 0.0: return
	_t = 0.12
	var me := _anchor()
	var c := Vector2i(floori((me.x - _ox) / TILE), floori((me.z - _oz) / TILE))
	var r := ceili(BUILD_R / TILE)
	var best := Vector2i(1 << 30, 0); var bd := INF
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := c + Vector2i(dx, dz)
			if _tiles.has(k) or not _index.has(k): continue
			var d := _dist(k, me)
			if d < BUILD_R and d < bd: bd = d; best = k
	if bd < INF and not _busy:
		_busy = true
		_tiles[best] = {"node": null, "paint": [], "body": null, "faces": PackedVector3Array(), "shapes": [], "pending": true}
		var td: Dictionary = await _build(best)
		_busy = false
		if _tiles.has(best) and _tiles[best].get("pending", false): _tiles[best] = td
		else: _free(td)
	for k in _tiles.keys():
		var t: Dictionary = _tiles[k]
		if t.get("pending", false): continue
		var d := _dist(k, me)
		if d > DROP_R:
			_free(t); _tiles.erase(k)
			continue
		if t.body == null and d < COLLIDE_R: _make_body(t)
		elif t.body != null and d > UNCOLLIDE_R:
			(t.body as Node).queue_free(); t.body = null

func _dist(k: Vector2i, me: Vector3) -> float:
	var cx := _ox + (k.x + 0.5) * TILE; var cz := _oz + (k.y + 0.5) * TILE
	return maxf(0.0, Vector2(me.x - cx, me.z - cz).length() - TILE * 0.7)

## hand the frame back once a build has had its 2.5 ms
var worst_where := ""
func _slice(where := "") -> void:
	var used := Time.get_ticks_usec() - _slice_t
	if used > 2500:
		if used > worst_slice: worst_slice = used; worst_where = where
		await get_tree().process_frame
		_slice_t = Time.get_ticks_usec()

func _free(t: Dictionary) -> void:
	if t.node != null and is_instance_valid(t.node): (t.node as Node).queue_free()
	for p in t.paint:
		if is_instance_valid(p): (p as Node).queue_free()
	if Roads.inst:
		for cc in Roads.inst._cascades: cc.dirty = true

# ------------------------------------------------------------------ the ground under it (a 5 m grid for the tile)
var _hg := PackedFloat32Array()
var _hx := 0.0
var _hz := 0.0
const HN := 28
func _height_grid(k: Vector2i) -> void:
	var data: Terrain3DData = main.terrain.data
	_hx = floorf((_ox + k.x * TILE) / 5.0) * 5.0 - 5.0
	_hz = floorf((_oz + k.y * TILE) / 5.0) * 5.0 - 5.0
	_hg.resize(HN * HN)
	for j in HN:
		for i in HN:
			var h := float(data.get_height(Vector3(_hx + i * 5.0, 0, _hz + j * 5.0)))
			_hg[j * HN + i] = 0.0 if is_nan(h) else h

## The ground exactly (the fences: the 5 m grid smooths over a step between two yards and a fence on it floats or sinks)
func _he(x: float, z: float) -> float:
	var v: float = main.terrain.data.get_height(Vector3(x, 0, z))
	return _h(x, z) if is_nan(v) else v

func _h(x: float, z: float) -> float:
	var fx := (x - _hx) / 5.0; var fz := (z - _hz) / 5.0
	var i := clampi(int(fx), 0, HN - 2); var j := clampi(int(fz), 0, HN - 2)
	var u := clampf(fx - i, 0.0, 1.0); var v := clampf(fz - j, 0.0, 1.0)
	var a := _hg[j * HN + i]; var b := _hg[j * HN + i + 1]
	var c := _hg[(j + 1) * HN + i]; var d := _hg[(j + 1) * HN + i + 1]
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)

# ------------------------------------------------------------------ building a tile
func _build(k: Vector2i) -> Dictionary:
	_slice_t = Time.get_ticks_usec()
	var d := _tile_data(k)
	await _slice("parse")
	_height_grid(k)
	await _slice("heights")
	var org := Vector3(_ox + k.x * TILE, 0, _oz + k.y * TILE)
	var root := Node3D.new()
	root.name = "Streets_%d_%d" % [k.x, k.y]
	root.position = org
	add_child(root)
	var faces := PackedVector3Array()
	# kerbs
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nv := 0
	for run in d.kerb:
		nv += _kerb(st, run[1], run[2], org, faces)
		await _slice("kerb")
	# raised footpaths in the shopping streets
	for sl in d.slab:
		_slab(st, sl[0], sl[1], org, faces)
		await _slice("slab")
	if nv > 0 or not d.slab.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _kmat
		mi.visibility_range_end = DRAW_KERB
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	await _slice("after kerbs")
	# furniture
	var by_kind := {}
	var shapes := []
	for f in d.furn:
		var kind := int(f[0])
		if not _furn_mesh.has(kind): continue
		var x := float(f[1]); var z := float(f[2])
		var y := _h(x, z)
		if kind in [4, 5] and _on_slab(d.slab, x, z): y += SLAB_Y
		var xf := Transform3D(Basis(Vector3.UP, float(f[3])), Vector3(x, y, z) - org)
		if kind == 7 and float(f[4]) > 0.5: kind = 70          # power pole with a street light
		if not by_kind.has(kind): by_kind[kind] = []
		by_kind[kind].append(xf)
		shapes.append([kind, xf])
	for kind in by_kind:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _furn_mesh[kind]
		mm.instance_count = by_kind[kind].size()
		for i in mm.instance_count: mm.set_instance_transform(i, by_kind[kind][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 380.0 if kind in [6, 7, 70, 1] else 160.0
		root.add_child(mmi)
	# back yard fences (shared with the neighbours, corner posts and all)
	var fg: BuildGen.Geo = null
	if not d.fence.is_empty():
		fg = BuildGen.Geo.new()
		for fr in d.fence:
			_fence(fg, fr, org)
			await _slice("fences")
		await _slice("fences")
		var fmi := MeshInstance3D.new()
		fmi.mesh = fg.commit()
		fmi.visibility_range_end = 120.0
		root.add_child(fmi)
	await _slice("after furniture")
	# paint: drawn with the roads into the ground
	var paint := []
	if Roads.inst and not Roads.inst._cascades.is_empty() and not d.paint.is_empty():
		_paint_mats()
		var groups := {}
		for p in d.paint:
			var mark := float(p[1]) > 0.5
			if not groups.has(mark): groups[mark] = []
			groups[mark].append(p)
		for mark in groups:
			var vs := PackedVector3Array(); var uv := PackedVector2Array(); var uv2 := PackedVector2Array(); var cs := PackedColorArray()
			for p in groups[mark]:
				await _slice("paint")
				var tri: PackedFloat32Array = p[2]
				var col := Color(float(p[0]), 1.0 if mark else 0.0, 0.0, 0.12)
				for i in range(0, tri.size() / 2, 3):
					# 0.2.55: nothing painted up a bank (it smears down the slope from above)
					var h0 := _h(tri[i * 2], tri[i * 2 + 1]); var h1 := _h(tri[i * 2 + 2], tri[i * 2 + 3]); var h2 := _h(tri[i * 2 + 4], tri[i * 2 + 5])
					var cx := (tri[i * 2] + tri[i * 2 + 2] + tri[i * 2 + 4]) / 3.0; var cz := (tri[i * 2 + 1] + tri[i * 2 + 3] + tri[i * 2 + 5]) / 3.0
					var hc := _h(cx, cz)
					var lo := minf(minf(h0, h1), minf(h2, hc)); var hi := maxf(maxf(h0, h1), maxf(h2, hc))
					var span := maxf(Vector2(tri[i * 2], tri[i * 2 + 1]).distance_to(Vector2(tri[i * 2 + 2], tri[i * 2 + 3])), Vector2(tri[i * 2], tri[i * 2 + 1]).distance_to(Vector2(tri[i * 2 + 4], tri[i * 2 + 5])))
					if hi - lo > 1.0 and (hi - lo) / maxf(span, 1.0) > 0.22: continue
					for j in 3:
						var x := tri[(i + j) * 2]; var z := tri[(i + j) * 2 + 1]
						vs.append(Vector3(x - org.x, 0.0, z - org.z))
						uv.append(Vector2(x, z))           # world-mapped: texture the same size every way (0.2.55: was streaky)
						uv2.append(Vector2(1.0e5, 1.0))
						cs.append(col)
			if vs.is_empty(): continue
			var arr := []; arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_TEX_UV2] = uv2; arr[Mesh.ARRAY_COLOR] = cs
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var pmi := MeshInstance3D.new()
			pmi.mesh = am
			pmi.material_override = _mark_mat if mark else _paint_mat
			pmi.position = org
			pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Roads.inst._cascades[0].vp.add_child(pmi)
			paint.append(pmi)
		for cc in Roads.inst._cascades: cc.dirty = true
	return {"node": root, "paint": paint, "body": null, "faces": faces, "shapes": shapes, "fshapes": fg.shapes if fg != null else []}

const FENCE_H := [1.5, 1.8, 1.0]
func _fence(g: BuildGen.Geo, fr: Array, org: Vector3) -> void:
	var fm := int(fr[0])
	var mk: String = ["timber", Buildings.COLORBOND[int(fr[1]) % Buildings.COLORBOND.size()], "brick"][clampi(fm, 0, 2)]
	var hgt: float = FENCE_H[clampi(fm, 0, 2)]
	var pts: PackedFloat32Array = fr[2]
	for v in pts.size() / 2 - 1:
		var a := Vector2(pts[v * 2] - org.x, pts[v * 2 + 1] - org.z)
		var c := Vector2(pts[v * 2 + 2] - org.x, pts[v * 2 + 3] - org.z)
		var L := a.distance_to(c)
		if L < 0.05: continue
		var n := maxi(1, ceili(L / 2.4))
		var dir := (c - a) / L
		var yaw := atan2(dir.x, dir.y)
		for k in n:
			var p0 := a.lerp(c, float(k) / n); var p1 := a.lerp(c, float(k + 1) / n)
			var m := (p0 + p1) * 0.5
			# 0.2.58: where the ground steps across the fence (two yards levelled to different heights), the bottom
			# runs down to the low side and the fence stands its full height above the high side: a retaining wall
			# with the fence on top, instead of a fence the high yard's plants seemed to float along the top of
			var nrm := Vector2(-dir.y, dir.x) * 0.7
			var gy := _he(m.x + org.x, m.y + org.z)
			var g1 := _he(m.x + nrm.x + org.x, m.y + nrm.y + org.z)
			var g2 := _he(m.x - nrm.x + org.x, m.y - nrm.y + org.z)
			var lo := minf(gy, minf(g1, g2)); var hi := maxf(gy, maxf(g1, g2))
			if is_nan(lo) or is_nan(hi): lo = gy; hi = gy
			var top := hi + hgt
			g.box(mk, Transform3D(Basis(Vector3.UP, yaw), Vector3(m.x, (lo - 0.1 + top) * 0.5, m.y)), Vector3(0.05 if fm != 2 else 0.2, top - lo + 0.1, p0.distance_to(p1)))
			if fm != 2:
				var py := _he(p0.x + org.x, p0.y + org.z)
				var pl := minf(py, lo)
				g.box("steel" if fm == 1 else "timber", Transform3D(Basis(Vector3.UP, yaw), Vector3(p0.x, (pl - 0.1 + top + 0.15) * 0.5, p0.y)), Vector3(0.09, top + 0.15 - pl + 0.1, 0.09), false)
	# the post at the run's last corner (the one a neighbour's run meets)
	if fm != 2 and pts.size() >= 4:
		var e := Vector2(pts[pts.size() - 2] - org.x, pts[pts.size() - 1] - org.z)
		var ey := _he(e.x + org.x, e.y + org.z)
		g.box("steel" if fm == 1 else "timber", Transform3D(Basis.IDENTITY, Vector3(e.x, ey - 0.1 + hgt * 0.5 + 0.05, e.y)), Vector3(0.09, hgt + 0.3, 0.09), false)

func _paint_mats() -> void:
	if _paint_mat != null: return
	_paint_mat = Roads.inst.overlay_mat.duplicate()
	_paint_mat.render_priority = 1
	_mark_mat = Roads.inst.overlay_mat.duplicate()
	_mark_mat.render_priority = 2

func _on_slab(slabs: Array, x: float, z: float) -> bool:
	for sl in slabs:
		var tri: PackedFloat32Array = sl[0]
		for i in range(0, tri.size() / 2, 3):
			if Geometry2D.point_is_inside_triangle(Vector2(x, z), Vector2(tri[i * 2], tri[i * 2 + 1]), Vector2(tri[i * 2 + 2], tri[i * 2 + 3]), Vector2(tri[i * 2 + 4], tri[i * 2 + 5])):
				return true
	return false

func _kerb(st: SurfaceTool, pts: PackedVector2Array, kinds: PackedInt32Array, org: Vector3, faces: PackedVector3Array) -> int:
	var n := pts.size()
	if n < 2: return 0
	var rows := []
	for i in n:
		var a := pts[maxi(i - 1, 0)]; var b := pts[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		var nn := Vector2(t.y, -t.x)
		var prof: Array = PH[clampi(kinds[i], 0, PH.size() - 1)]
		var row := PackedVector3Array()
		var h0 := _h(pts[i].x, pts[i].y)
		for s in STA.size():
			var p := pts[i] + nn * float(STA[s])
			# the gutter and kerb follow the road edge's level; the back follows the ground behind
			var hg := h0 if float(STA[s]) <= 0.2 else _h(p.x, p.y)
			row.append(Vector3(p.x - org.x, hg + 0.02 + float(prof[s]), p.y - org.z))
		rows.append(row)
	for i in n - 1:
		var r0: PackedVector3Array = rows[i]; var r1: PackedVector3Array = rows[i + 1]
		for s in STA.size() - 1:
			var q: Array[Vector3] = [r0[s], r1[s], r1[s + 1], r0[s + 1]]
			var nrm := (q[1] - q[0]).cross(q[3] - q[0])
			if nrm.length_squared() < 1e-10: nrm = (q[2] - q[1]).cross(q[3] - q[2])
			nrm = nrm.normalized()
			if nrm.y < -0.05: nrm = -nrm
			for v in [q[0], q[2], q[1], q[0], q[3], q[2]]:
				st.set_normal(nrm); st.add_vertex(v); faces.append(v)
	return n

func _slab(st: SurfaceTool, tri: PackedFloat32Array, rings: Array, org: Vector3, faces: PackedVector3Array) -> void:
	## the shopping-street footpath sits at kerb-top height off the road edge (its anchor), not on the ground behind;
	## where the ground falls away more than a metre or climbs well above it (a bank) that bit is left out
	for i in range(0, tri.size() / 4, 3):
		var vv := []
		var ok := true
		for j in 3:
			var o := (i + j) * 4
			var x := tri[o]; var z := tri[o + 1]
			var y := _h(tri[o + 2], tri[o + 3]) + 0.02 + SLAB_Y
			var g := _h(x, z)
			if g < y - 1.2 or g > y + 0.9: ok = false
			vv.append(Vector3(x - org.x, y, z - org.z))
		if not ok: continue
		var order := [vv[0], vv[2], vv[1]] if ((vv[1] - vv[0]) as Vector3).cross(vv[2] - vv[0]).y > 0.0 else [vv[0], vv[1], vv[2]]
		for v in order:
			st.set_normal(Vector3.UP); st.add_vertex(v); faces.append(v)
	# a skirt down to the ground round the edge (shows at the block ends and the lane side)
	for r in rings:
		var rr: PackedFloat32Array = r
		for i in rr.size() / 4 - 1:
			var o := i * 4
			var ax := rr[o]; var az := rr[o + 1]; var bx := rr[o + 4]; var bz := rr[o + 5]
			var ya := _h(rr[o + 2], rr[o + 3]) + 0.02 + SLAB_Y; var yb := _h(rr[o + 6], rr[o + 7]) + 0.02 + SLAB_Y
			var ga := _h(ax, az); var gb := _h(bx, bz)
			if ga < ya - 1.2 or gb < yb - 1.2 or ga > ya + 0.9 or gb > yb + 0.9: continue
			var a0 := Vector3(ax - org.x, minf(ga, ya) - 0.05, az - org.z); var a1 := Vector3(ax - org.x, ya, az - org.z)
			var b0 := Vector3(bx - org.x, minf(gb, yb) - 0.05, bz - org.z); var b1 := Vector3(bx - org.x, yb, bz - org.z)
			var sn := Vector3(bz - az, 0.0, ax - bx).normalized()
			for v in [a0, b0, b1, a0, b1, a1]:
				st.set_normal(sn); st.add_vertex(v)

func _make_body(t: Dictionary) -> void:
	var b := StaticBody3D.new()
	b.add_to_group("road")
	var faces: PackedVector3Array = t.faces
	if faces.size() >= 3:
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(faces)
		var cs := CollisionShape3D.new(); cs.shape = sh
		b.add_child(cs)
	for s in t.shapes:
		var kind := int(s[0]); var xf: Transform3D = s[1]
		var shp: Shape3D; var off := Vector3.ZERO
		match kind:
			1, 6, 7, 70:
				var c := CylinderShape3D.new(); c.radius = 0.13 if kind != 1 else 0.09; c.height = 6.0
				shp = c; off = Vector3(0, 3.0, 0)
			2, 8, 9:
				var c := CylinderShape3D.new(); c.radius = 0.05; c.height = 2.4
				shp = c; off = Vector3(0, 1.2, 0)
			3:
				var bx := BoxShape3D.new(); bx.size = Vector3(3.4, 2.4, 0.1)
				shp = bx; off = Vector3(0, 1.2, -0.7)
			4:
				var bx := BoxShape3D.new(); bx.size = Vector3(0.55, 0.95, 0.55)
				shp = bx; off = Vector3(0, 0.47, 0)
			5:
				var bx := BoxShape3D.new(); bx.size = Vector3(1.8, 0.5, 0.5)
				shp = bx; off = Vector3(0, 0.25, 0)
			_:
				continue
		var cs2 := CollisionShape3D.new(); cs2.shape = shp
		cs2.transform = Transform3D(xf.basis, xf.origin + xf.basis * off)
		b.add_child(cs2)
	for sh in t.get("fshapes", []):
		var fcs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = sh[1]
		fcs.shape = bs; fcs.transform = sh[0]
		b.add_child(fcs)
	if b.get_child_count() == 0:
		b.free(); return
	(t.node as Node3D).add_child(b)
	t.body = b

# ------------------------------------------------------------------ the furniture (made once, front faces +Z)
func _m(c: Color, metal := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.metallic = metal; m.roughness = rough
	return m

func _box(st: SurfaceTool, size: Vector3, at: Vector3, basis := Basis.IDENTITY) -> void:
	var bm := BoxMesh.new(); bm.size = size
	st.append_from(bm, 0, Transform3D(basis, at))

func _cyl(st: SurfaceTool, r: float, h: float, at: Vector3, basis := Basis.IDENTITY, r_top := -1.0) -> void:
	var cm := CylinderMesh.new(); cm.top_radius = r if r_top < 0.0 else r_top; cm.bottom_radius = r; cm.height = h
	cm.radial_segments = 10; cm.rings = 1
	st.append_from(cm, 0, Transform3D(basis, at + basis * Vector3(0, h * 0.5, 0)))

func _mesh(parts: Array) -> ArrayMesh:
	## parts: [[material, method name]]: each method fills a SurfaceTool
	var am := ArrayMesh.new()
	for p in parts:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		call(str(p[1]), st)
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, p[0])
	return am

func _build_furniture_meshes() -> void:
	var grey := _m(Color(0.42, 0.43, 0.44), 0.6, 0.55)
	var galv := _m(Color(0.62, 0.63, 0.62), 0.7, 0.5)
	var dark := _m(Color(0.08, 0.08, 0.08), 0.0, 0.5)
	var yellow := _m(Color(0.75, 0.62, 0.12), 0.2, 0.6)
	var timber := _m(Color(0.36, 0.3, 0.24), 0.0, 0.95)
	var green := _m(Color(0.12, 0.3, 0.17), 0.1, 0.7)
	var red := _m(Color(0.62, 0.08, 0.07), 0.0, 0.6)
	var white := _m(Color(0.86, 0.86, 0.84), 0.0, 0.6)
	var glass := _m(Color(0.55, 0.62, 0.62, 0.35), 0.0, 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var slats := _m(Color(0.45, 0.33, 0.22), 0.0, 0.9)
	_furn_mesh[1] = _mesh([[galv, "_f_sig_pole"], [dark, "_f_sig_heads"], [yellow, "_f_sig_button"]])
	_furn_mesh[2] = _mesh([[galv, "_f_thin_pole"], [white, "_f_bus_plate"], [green, "_f_bus_band"]])
	_furn_mesh[3] = _mesh([[grey, "_f_shelter_frame"], [glass, "_f_shelter_glass"]])
	_furn_mesh[4] = _mesh([[green, "_f_bin"], [dark, "_f_bin_lid"]])
	_furn_mesh[5] = _mesh([[slats, "_f_bench_slats"], [dark, "_f_bench_legs"]])
	_furn_mesh[6] = _mesh([[galv, "_f_lamp_pole"], [grey, "_f_lamp_head"]])
	_furn_mesh[7] = _mesh([[timber, "_f_pp"], [white, "_f_pp_ins"]])
	_furn_mesh[70] = _mesh([[timber, "_f_pp"], [white, "_f_pp_ins"], [galv, "_f_pp_arm"], [grey, "_f_pp_lamp"]])
	_furn_mesh[8] = _mesh([[galv, "_f_sign_pole"], [red, "_f_stop"]])
	_furn_mesh[9] = _mesh([[galv, "_f_sign_pole"], [red, "_f_gw_red"], [white, "_f_gw_white"]])

# 1 traffic lights: a galvanised pole, a target-board lantern each way, the push button
func _f_sig_pole(st: SurfaceTool) -> void:
	_cyl(st, 0.075, 3.9, Vector3.ZERO); _box(st, Vector3(0.12, 0.18, 0.1), Vector3(0, 1.05, 0.1))
func _f_sig_heads(st: SurfaceTool) -> void:
	_box(st, Vector3(0.34, 1.0, 0.26), Vector3(0, 3.2, 0.2))
	_box(st, Vector3(0.6, 1.25, 0.03), Vector3(0, 3.2, 0.34))
	_box(st, Vector3(0.34, 1.0, 0.26), Vector3(0, 3.2, -0.2))
func _f_sig_button(st: SurfaceTool) -> void:
	_box(st, Vector3(0.14, 0.14, 0.12), Vector3(0, 1.05, 0.17))
# 2 bus stop sign
func _f_thin_pole(st: SurfaceTool) -> void: _cyl(st, 0.035, 2.7, Vector3.ZERO)
func _f_bus_plate(st: SurfaceTool) -> void: _box(st, Vector3(0.42, 0.6, 0.02), Vector3(0, 2.3, 0.05))
func _f_bus_band(st: SurfaceTool) -> void: _box(st, Vector3(0.42, 0.14, 0.025), Vector3(0, 2.52, 0.055))
# 3 bus shelter: open side to +Z (the road)
func _f_shelter_frame(st: SurfaceTool) -> void:
	for x in [-1.65, 1.65]:
		for z in [-0.7, 0.6]: _box(st, Vector3(0.08, 2.4, 0.08), Vector3(x, 1.2, z))
	_box(st, Vector3(3.6, 0.08, 1.7), Vector3(0, 2.44, -0.05))
	_box(st, Vector3(2.6, 0.06, 0.35), Vector3(0, 0.45, -0.5))
	for x in [-1.1, 1.1]: _box(st, Vector3(0.06, 0.42, 0.3), Vector3(x, 0.22, -0.5))
func _f_shelter_glass(st: SurfaceTool) -> void:
	_box(st, Vector3(3.3, 1.9, 0.02), Vector3(0, 1.25, -0.72))
	for x in [-1.65, 1.65]: _box(st, Vector3(0.02, 1.9, 0.9), Vector3(x, 1.25, -0.25))
# 4 street bin
func _f_bin(st: SurfaceTool) -> void: _cyl(st, 0.27, 0.85, Vector3.ZERO, Basis.IDENTITY, 0.29)
func _f_bin_lid(st: SurfaceTool) -> void: _cyl(st, 0.3, 0.08, Vector3(0, 0.85, 0))
# 5 bench: timber slats on cast legs
func _f_bench_slats(st: SurfaceTool) -> void:
	for z in [-0.12, 0.0, 0.12]: _box(st, Vector3(1.8, 0.035, 0.1), Vector3(0, 0.45, z))
	for y in [0.62, 0.75]: _box(st, Vector3(1.8, 0.09, 0.03), Vector3(0, y, -0.22))
func _f_bench_legs(st: SurfaceTool) -> void:
	for x in [-0.75, 0.75]:
		_box(st, Vector3(0.05, 0.45, 0.42), Vector3(x, 0.22, 0))
		_box(st, Vector3(0.05, 0.4, 0.05), Vector3(x, 0.65, -0.22))
# 6 street light: tapered pole, outreach arm over the road, the lantern
func _f_lamp_pole(st: SurfaceTool) -> void:
	_cyl(st, 0.11, 7.2, Vector3.ZERO, Basis.IDENTITY, 0.06)
	_box(st, Vector3(0.06, 0.06, 1.8), Vector3(0, 7.1, 0.9))
func _f_lamp_head(st: SurfaceTool) -> void: _box(st, Vector3(0.28, 0.12, 0.6), Vector3(0, 7.02, 1.85))
# 7 timber power pole, crossarm, insulators; 70 with a street light
func _f_pp(st: SurfaceTool) -> void:
	_cyl(st, 0.15, 10.0, Vector3(0, -0.4, 0), Basis.IDENTITY, 0.12)
	_box(st, Vector3(2.4, 0.1, 0.1), Vector3(0, 9.0, 0))
func _f_pp_ins(st: SurfaceTool) -> void:
	for x in [-1.05, -0.35, 0.35, 1.05]: _cyl(st, 0.04, 0.16, Vector3(x, 9.05, 0))
func _f_pp_arm(st: SurfaceTool) -> void: _box(st, Vector3(0.05, 0.05, 1.6), Vector3(0, 7.2, 0.8))
func _f_pp_lamp(st: SurfaceTool) -> void: _box(st, Vector3(0.24, 0.1, 0.5), Vector3(0, 7.15, 1.6))
# 8 stop sign, 9 give way: the face turned to the traffic it's for (+Z)
func _f_sign_pole(st: SurfaceTool) -> void: _cyl(st, 0.03, 2.5, Vector3.ZERO)
func _plate(st: SurfaceTool, r: float, sides: int, roll: float, z: float) -> void:
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = 0.02; cm.radial_segments = sides; cm.rings = 1
	st.append_from(cm, 0, Transform3D(Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 2.2, z)))
func _f_stop(st: SurfaceTool) -> void: _plate(st, 0.38, 8, PI / 8.0, 0.04)
func _f_gw_red(st: SurfaceTool) -> void: _plate(st, 0.48, 3, PI, 0.04)
func _f_gw_white(st: SurfaceTool) -> void: _plate(st, 0.3, 3, PI, 0.055)
