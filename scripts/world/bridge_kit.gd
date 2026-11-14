class_name BridgeKit
## The modular bridge kit: every road bridge in the valley is rebuilt from the same pieces, along the deck lines in
## assets/world/bridges.json (tools/bake_bridges.gd pulled them out of the old baked road tiles).
##   deck     the road seal (drawn by the road shader, so it matches the roads), concrete kerb strips
##   barrier  a concrete safety barrier each side with a steel rail on posts
##   girders  a deck slab on box girders, fascia down the sides
##   piers    a headstock on columns about every 18 m, down to the ground, where the ground is far enough below
##   ends     an abutment wall and splayed wing walls at each end, and a 12 m approach slab that runs down into the
##            road beyond the end, so no lip is left for a wheel to catch
## Before it builds, conform() reshapes the terrain at each end: the ground meets the deck (an earth embankment where
## the ground was lower, a cutting where it was higher), and is kept clear under the span.
## Everything for one 1 km road tile is one mesh with three surfaces (seal, concrete, steel): three draw calls a tile.

const SPAN := 18.0          # target span between piers
const SLAB := 12.0          # approach slab beyond each end
const SLAB_DROP := 0.5      # the slab's far end sits this far under the deck end (buried in the road)
const KERB := 0.5           # concrete strip between the seal and the barrier
const BAR_W := 0.35         # barrier thickness at the top
const BAR_H := 0.85
const RAIL_H := 1.15
const SLAB_D := 0.4         # deck slab depth
const GIRDER_D := 1.0       # girders under the slab
const STEP := 4.0           # deck resolution along

static var bridges: Array = []    # [{P: PackedVector3Array (deck line, dense), hw, mark, wild, L}]

static func load_all() -> Array:
	bridges.clear()
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/bridges.json"))
	if typeof(d) != TYPE_DICTIONARY: return bridges
	for b in d.bridges:
		var raw := PackedVector3Array()
		for p in b.pts: raw.append(Vector3(p[0], p[1], p[2]))
		var P := _smooth_profile(_densify(raw))
		if P.size() < 2: continue
		bridges.append({"P": P, "hw": float(b.hw), "mark": float(b.mark), "wild": float(b.wild), "L": _length(P)})
	return bridges

## The old decks were pulled to the road heights at their ends, which left short steep humps (up to ~30%): smooth
## the height along the deck (about 12 m each way, passes of a box filter), keeping both end heights where they are.
static func _smooth_profile(P: PackedVector3Array) -> PackedVector3Array:
	var n := P.size()
	if n < 4: return P
	var y := PackedFloat32Array()
	for p in P: y.append(p.y)
	var r := 3                        # points each side (STEP 4 m apart -> 12 m)
	for _pass in 3:
		var y2 := y.duplicate()
		for i in range(1, n - 1):
			var k := mini(r, mini(i, n - 1 - i))        # shrink near the ends so the ends stay put
			var acc := 0.0
			for j in range(i - k, i + k + 1): acc += y[j]
			y2[i] = acc / (2 * k + 1)
		y = y2
	var out := PackedVector3Array()
	for i in n: out.append(Vector3(P[i].x, y[i], P[i].z))
	return out

static func _length(P: PackedVector3Array) -> float:
	var s := 0.0
	for i in P.size() - 1: s += Vector2(P[i + 1].x - P[i].x, P[i + 1].z - P[i].z).length()
	return s

static func _densify(raw: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in raw.size() - 1:
		var a := raw[i]; var b := raw[i + 1]
		var n := maxi(1, ceili(Vector2(b.x - a.x, b.z - a.z).length() / STEP))
		for k in n: out.append(a.lerp(b, float(k) / n))
	out.append(raw[raw.size() - 1])
	return out

static func _dir(P: PackedVector3Array, i: int) -> Vector2:
	var i0 := maxi(i - 1, 0); var i1 := mini(i + 1, P.size() - 1)
	var t := Vector2(P[i1].x - P[i0].x, P[i1].z - P[i0].z)
	return t.normalized() if t.length() > 0.0001 else Vector2(1, 0)

## (end point, outward direction, deck height) for end 0 (start) and end 1 (finish)
static func _end(b: Dictionary, e: int) -> Array:
	var P: PackedVector3Array = b.P
	var i := 0 if e == 0 else P.size() - 1
	var t := _dir(P, i)
	return [P[i], -t if e == 0 else t]

# ------------------------------------------------------------------ the ground at the ends
static func conform(data: Terrain3DData) -> int:
	if data == null: return 0
	# two passes over every bridge: first the ground each approach wants (embankment or cutting, with a weight that
	# falls off to the sides), then caps that keep it clear under each deck's own footprint. Twin bridges side by
	# side would otherwise dig out each other's approaches.
	var fill := {}     # Vector2i -> [target, weight]
	var cap := {}      # Vector2i -> max height
	for b in bridges:
		var hw: float = b.hw
		for e in 2:
			var en := _end(b, e)
			var c: Vector3 = en[0]; var t: Vector2 = en[1]
			var y := c.y
			var g0 := float(data.get_height(Vector3(c.x + t.x * SLAB, 0, c.z + t.y * SLAB)))
			if is_nan(g0): continue
			var dh := absf(y - 0.15 - g0)
			var blend := clampf(dh * 6.0, 10.0, 50.0)
			var bank := maxf(8.0, dh * 2.5)
			var reach := SLAB + blend + hw + bank + 6.0
			var x0 := floorf((c.x - reach) / 5.0) * 5.0; var z0 := floorf((c.z - reach) / 5.0) * 5.0
			var x := x0
			while x <= c.x + reach:
				var z := z0
				while z <= c.z + reach:
					var v := Vector2(x - c.x, z - c.z)
					var a := v.dot(t)
					var l := absf(v.dot(t.orthogonal()))
					var key := Vector2i(roundi(x / 5.0), roundi(z / 5.0))
					if a < -0.01 and a > -7.0 and l <= hw + 1.5:
						cap[key] = minf(cap.get(key, INF), y - 1.0)         # just inside the end, under the deck
					elif a >= -0.01 and a < SLAB + blend:
						var wl := 1.0
						if l > hw + 3.0: wl = 1.0 - _smooth((l - hw - 3.0) / bank)
						if wl > 0.0:
							var h0 := float(data.get_height(Vector3(x, 0, z)))
							if not is_nan(h0):
								var tgt: float
								if a < 4.0: tgt = y - 0.6                      # hidden under the approach slab
								elif a < SLAB: tgt = y - 0.15
								else: tgt = lerpf(y - 0.15, h0, _smooth((a - SLAB) / blend))
								var cur: Array = fill.get(key, [0.0, -1.0])
								if wl > cur[1] + 0.001 or (absf(wl - cur[1]) <= 0.001 and tgt > cur[0]): fill[key] = [tgt, wl]
					z += 5.0
				x += 5.0
		# under the span: at least 1.4 m under the deck (abutments and piers stand on it)
		var P: PackedVector3Array = b.P
		for i in P.size():
			var q := P[i]
			var t2 := _dir(P, i).orthogonal()
			for o: float in [-hw - 0.5, -hw * 0.5, 0.0, hw * 0.5, hw + 0.5]:
				var p := Vector3(snappedf(q.x + t2.x * o, 5.0), 0, snappedf(q.z + t2.y * o, 5.0))
				if _past_end(b, p): continue
				var key := Vector2i(roundi(p.x / 5.0), roundi(p.z / 5.0))
				cap[key] = minf(cap.get(key, INF), q.y - 1.4)
	var n := 0
	for key in fill:
		var p := Vector3(key.x * 5.0, 0, key.y * 5.0)
		var h0 := float(data.get_height(p))
		var h := lerpf(h0, float(fill[key][0]), float(fill[key][1]))
		if cap.has(key): h = minf(h, cap[key])
		data.set_height(p, h); n += 1
	for key in cap:
		if fill.has(key): continue
		var p := Vector3(key.x * 5.0, 0, key.y * 5.0)
		var h0 := float(data.get_height(p))
		if not is_nan(h0) and h0 > cap[key]:
			data.set_height(p, cap[key]); n += 1
	return n

static func _past_end(b: Dictionary, p: Vector3) -> bool:
	for e in 2:
		var en := _end(b, e)
		var c: Vector3 = en[0]
		if Vector2(p.x - c.x, p.z - c.z).dot(en[1]) > -1.0: return true
	return false

static func _smooth(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

# ------------------------------------------------------------------ building
class Acc:
	var v := PackedVector3Array(); var n := PackedVector3Array(); var idx := PackedInt32Array()
	var uv := PackedVector2Array(); var uv2 := PackedVector2Array(); var col := PackedColorArray()
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length() < 1e-8: nn = (c - b).cross(a - b)
		nn = nn.normalized()
		var s := v.size()
		v.append_array(PackedVector3Array([a, b, c, d]))
		for _i in 4: n.append(nn)
		idx.append_array(PackedInt32Array([s, s + 1, s + 2, s, s + 2, s + 3]))
	func box(xf: Transform3D, size: Vector3) -> void:
		var h := size * 0.5
		var c := []
		for k in 8: c.append(xf * Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1)))
		for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
			quad(c[f[0]], c[f[1]], c[f[2]], c[f[3]])
	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = idx
		if not uv.is_empty():
			arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_TEX_UV2] = uv2; arr[Mesh.ARRAY_COLOR] = col
		return arr

## Builds every bridge, grouped by road tile. Returns {Vector2i tile: ArrayMesh} with vertices relative to org(tile).
static func build(data: Terrain3DData, mats: Array, x0: float, z0: float) -> Dictionary:
	var groups := {}
	for b in bridges:
		var P: PackedVector3Array = b.P
		var mid := P[P.size() / 2]
		var key := Vector2i(floori((mid.x - x0) / 1024.0), floori((mid.z - z0) / 1024.0))
		if not groups.has(key): groups[key] = []
		groups[key].append(b)
	var out := {}
	for key in groups:
		var org := Vector3(x0 + key.x * 1024.0 + 512.0, 0, z0 + key.y * 1024.0 + 512.0)
		var seal := Acc.new(); var conc := Acc.new(); var steel := Acc.new()
		for b in groups[key]:
			_bridge(b, data, org, seal, conc, steel)
		var am := ArrayMesh.new()
		for pair in [[seal, mats[0]], [conc, mats[1]], [steel, mats[2]]]:
			var acc: Acc = pair[0]
			if acc.v.is_empty(): continue
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, acc.arrays())
			am.surface_set_material(am.get_surface_count() - 1, pair[1])
		out[key] = {"mesh": am, "org": org}
	return out

static func _bridge(b: Dictionary, data: Terrain3DData, org: Vector3, seal: Acc, conc: Acc, steel: Acc) -> void:
	var P: PackedVector3Array = b.P
	var hw: float = b.hw
	var L: float = b.L
	# the line with an approach slab on each end: points, along-distance, deck flag
	var e0 := _end(b, 0); var e1 := _end(b, 1)
	var Q := PackedVector3Array(); var S := PackedFloat32Array()
	var ns := 3
	for k in range(ns, 0, -1):
		var f := float(k) / ns
		Q.append(Vector3(P[0].x + e0[1].x * SLAB * f, P[0].y - SLAB_DROP * f, P[0].z + e0[1].y * SLAB * f))
	for p in P: Q.append(p)
	for k in range(1, ns + 1):
		var f := float(k) / ns
		var pe := P[P.size() - 1]
		Q.append(Vector3(pe.x + e1[1].x * SLAB * f, pe.y - SLAB_DROP * f, pe.z + e1[1].y * SLAB * f))
	var s := -SLAB
	for i in Q.size():
		if i > 0: s += Vector2(Q[i].x - Q[i - 1].x, Q[i].z - Q[i - 1].z).length()
		S.append(s)
	var nq := Q.size()
	var side := []    # per point: the across vector (x, z)
	for i in nq: side.append(_dir(Q, i).orthogonal())
	# ---- the seal and kerb strips (road shader vertex format, like the flush roads)
	var offs := PackedFloat32Array([-hw - KERB])
	var nst := maxi(2, ceili(2.0 * hw / 1.6))
	for i in nst + 1: offs.append(-hw + 2.0 * hw * i / nst)
	offs.append(hw + KERB)
	var m := offs.size()
	var base := seal.v.size()
	for i in nq:
		var sd: Vector2 = side[i]
		# markings fade in over the slab, so they meet the road's own where it runs out from under it
		var fade := clampf((S[i] + SLAB) / SLAB, 0.0, 1.0) * clampf((L + SLAB - S[i]) / SLAB, 0.0, 1.0)
		for j in m:
			var o := offs[j]
			seal.v.append(Vector3(Q[i].x + sd.x * o, Q[i].y, Q[i].z + sd.y * o) - org)
			seal.n.append(Vector3.UP)
			seal.uv.append(Vector2(o, S[i]))
			seal.uv2.append(Vector2(hw, fade))
			seal.col.append(Color(1.0 if (j == 0 or j == m - 1) else 0.0, float(b.mark), 0.0, float(b.wild)))
	for i in nq - 1:
		for j in m - 1:
			var vv := base + i * m + j
			seal.idx.append_array(PackedInt32Array([vv, vv + 1, vv + m, vv + 1, vv + m + 1, vv + m]))
	# slab skirts: the approach slab's sides go down into the ground
	for i in range(0, nq - 1):
		if S[i] >= 0.0 and S[i + 1] <= L: continue
		for sg: float in [-1.0, 1.0]:
			var a := _at(Q, side, i, sg * (hw + KERB), 0.0) - org; var bb := _at(Q, side, i + 1, sg * (hw + KERB), 0.0) - org
			_wall_strip(conc, a, bb, 0.9, sg < 0.0)
	# ---- the deck proper: barrier, slab edge, girders, underside (only over the span)
	var i0 := ns; var i1 := ns + P.size() - 1
	var bo := hw + KERB
	var prof := [Vector2(bo, 0.0), Vector2(bo, 0.25), Vector2(bo + 0.12, 0.5), Vector2(bo + 0.12, BAR_H),
		Vector2(bo + BAR_W + 0.12, BAR_H), Vector2(bo + BAR_W + 0.12, -SLAB_D), Vector2(-(bo + BAR_W + 0.12), -SLAB_D)]
	for sg: float in [-1.0, 1.0]:
		var pr := []
		for q in prof.slice(0, 6): pr.append(Vector2(q.x * sg, q.y))
		_sweep(conc, Q, side, i0, i1, pr, org, sg < 0.0)
	# underside slab
	_sweep(conc, Q, side, i0, i1, [Vector2(bo + BAR_W + 0.12, -SLAB_D), Vector2(-(bo + BAR_W + 0.12), -SLAB_D)], org, false)
	# girders
	var ng := maxi(2, roundi(2.0 * hw / 2.6))
	for g in ng:
		var lc := -hw + 2.0 * hw * g / (ng - 1)
		_sweep(conc, Q, side, i0, i1, [Vector2(lc - 0.35, -SLAB_D), Vector2(lc - 0.3, -SLAB_D - GIRDER_D), Vector2(lc + 0.3, -SLAB_D - GIRDER_D), Vector2(lc + 0.35, -SLAB_D)], org, false)
	# barrier ends, square to the line
	for i in [i0, i1]:
		var fw := 1.0 if i == i1 else -1.0
		for sg: float in [-1.0, 1.0]:
			var a := _at(Q, side, i, sg * bo, 0.0) - org; var bb := _at(Q, side, i, sg * (bo + BAR_W + 0.12), 0.0) - org
			var flip := (fw * sg) < 0.0
			if flip: conc.quad(a, a + Vector3(0, BAR_H, 0), bb + Vector3(0, BAR_H, 0), bb)
			else: conc.quad(bb, bb + Vector3(0, BAR_H, 0), a + Vector3(0, BAR_H, 0), a)
	# steel rail on posts along the barrier tops
	var sp := 0.0
	for i in range(i0, i1 + 1):
		for sg: float in [-1.0, 1.0]:
			if i < i1:
				var a := _at(Q, side, i, sg * (bo + 0.3), RAIL_H) - org; var bb := _at(Q, side, i + 1, sg * (bo + 0.3), RAIL_H) - org
				_beam(steel, a, bb, 0.09)
		if i == i0 or S[i] - sp >= 2.4 or i == i1:
			sp = S[i]
			for sg: float in [-1.0, 1.0]:
				var c := _at(Q, side, i, sg * (bo + 0.3), (BAR_H + RAIL_H) * 0.5) - org
				steel.box(Transform3D(Basis(Vector3.UP, atan2(side[i].x, side[i].y)), c), Vector3(0.08, RAIL_H - BAR_H, 0.08))
	# ---- piers
	var nsp := maxi(1, roundi(L / SPAN))
	if L > 14.0:
		for k in range(1, nsp):
			var sk := L * k / nsp
			var i := i0
			while i < i1 and S[i + 1] < sk: i += 1
			var f := clampf((sk - S[i]) / maxf(S[i + 1] - S[i], 0.001), 0.0, 1.0)
			var c := Q[i].lerp(Q[i + 1], f)
			var sd: Vector2 = side[i]
			var top := c.y - SLAB_D - GIRDER_D
			var ground := INF
			for o: float in [-hw, 0.0, hw]:
				var gh := float(data.get_height(Vector3(c.x + sd.x * o, 0, c.z + sd.y * o)))
				if not is_nan(gh): ground = minf(ground, gh)
			if ground == INF or top - ground < 1.2: continue
			var bs := Basis(Vector3.UP, atan2(sd.x, sd.y))
			conc.box(Transform3D(bs, Vector3(c.x, top - 0.45, c.z) - org), Vector3(2.0 * (bo + 0.3), 0.9, 1.3))
			var ncol := maxi(2, ceili(2.0 * hw / 5.0))
			for q in ncol:
				var o := -(hw - 1.0) + 2.0 * (hw - 1.0) * q / (ncol - 1)
				var cx := c.x + sd.x * o; var cz := c.z + sd.y * o
				var gb := float(data.get_height(Vector3(cx, 0, cz)))
				if is_nan(gb): gb = ground
				var y0 := gb - 1.0; var y1 := top - 0.9
				if y1 - y0 < 0.3: continue
				_column(conc, Vector3(cx, y0, cz) - org, y1 - y0, 0.5)
	# ---- abutments and wing walls
	for e in 2:
		var i := i0 if e == 0 else i1
		var en := _end(b, e)
		var out: Vector2 = en[1]
		var c := Q[i]
		var sd: Vector2 = side[i]
		var back := Vector2(c.x, c.z) - out * 0.6
		var gmin := INF
		for o: float in [-bo, 0.0, bo]:
			for a: float in [-3.0, -0.6]:
				var gh := float(data.get_height(Vector3(c.x + sd.x * o + out.x * a, 0, c.z + sd.y * o + out.y * a)))
				if not is_nan(gh): gmin = minf(gmin, gh)
		if gmin == INF: gmin = c.y - 2.0
		var y0 := gmin - 1.0; var y1 := c.y - SLAB_D
		if y1 - y0 > 0.2:
			conc.box(Transform3D(Basis(Vector3.UP, atan2(sd.x, sd.y)), Vector3(back.x, (y0 + y1) * 0.5, back.y) - org), Vector3(2.0 * (bo + BAR_W + 0.12), y1 - y0, 1.2))
		# wing walls: from the deck corners, splayed out and back along the slab, top running down to the ground
		for sg: float in [-1.0, 1.0]:
			var a2 := Vector2(c.x, c.z) + sd * sg * (bo + BAR_W)
			var b2 := a2 + out * 6.0 + sd * sg * 2.5
			var ga := float(data.get_height(Vector3(b2.x, 0, b2.y)))
			if is_nan(ga): ga = c.y - 1.0
			var A0 := Vector3(a2.x, y0, a2.y) - org; var A1 := Vector3(a2.x, c.y - 0.05, a2.y) - org
			var B0 := Vector3(b2.x, minf(ga, y0 + 0.5) - 0.5, b2.y) - org; var B1 := Vector3(b2.x, maxf(ga + 0.2, c.y - 1.4), b2.y) - org
			conc.quad(A0, A1, B1, B0); conc.quad(B0, B1, A1, A0)

static func _at(Q: PackedVector3Array, side: Array, i: int, o: float, dy: float) -> Vector3:
	var sd: Vector2 = side[i]
	return Vector3(Q[i].x + sd.x * o, Q[i].y + dy, Q[i].z + sd.y * o)

## Sweeps an open profile (Vector2(across, up) from the seal line) along points i0..i1, both faces' winding as given.
static func _sweep(acc: Acc, Q: PackedVector3Array, side: Array, i0: int, i1: int, prof: Array, org: Vector3, flip: bool) -> void:
	for i in range(i0, i1):
		for k in prof.size() - 1:
			var p0: Vector2 = prof[k]; var p1: Vector2 = prof[k + 1]
			var a := _at(Q, side, i, p0.x, p0.y) - org; var b := _at(Q, side, i, p1.x, p1.y) - org
			var c := _at(Q, side, i + 1, p1.x, p1.y) - org; var d := _at(Q, side, i + 1, p0.x, p0.y) - org
			if flip: acc.quad(a, b, c, d)
			else: acc.quad(d, c, b, a)

static func _wall_strip(acc: Acc, a: Vector3, b: Vector3, depth: float, flip: bool) -> void:
	var a1 := a - Vector3(0, depth, 0); var b1 := b - Vector3(0, depth, 0)
	if flip: acc.quad(a, b, b1, a1)
	else: acc.quad(b, a, a1, b1)

static func _beam(acc: Acc, a: Vector3, b: Vector3, t: float) -> void:
	var d := b - a
	if d.length() < 0.01: return
	var bs := Basis.looking_at(d.normalized(), Vector3.UP)
	acc.box(Transform3D(bs, (a + b) * 0.5), Vector3(t, t, d.length()))

static func _column(acc: Acc, foot: Vector3, h: float, r: float) -> void:
	var n := 8
	for k in n:
		var a0 := TAU * k / n; var a1 := TAU * (k + 1) / n
		var p0 := foot + Vector3(cos(a0) * r, 0, sin(a0) * r); var p1 := foot + Vector3(cos(a1) * r, 0, sin(a1) * r)
		acc.quad(p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), p0)
