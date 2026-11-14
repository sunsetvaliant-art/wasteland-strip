class_name PolyMall
## A mall built from traced shapes rather than boxes: Twin City, from the real Tweed City directory plan
## (tools/trace_mall.py -> assets/world/twin_city.json). Every shop and anchor is a polygon in the lot's frame
## (x = south, z = west, metres), with its walls already classed by what's on the other side: the outside, the
## concourse, or the shop next door. So walls stand on the angle, curved ends are short straight runs, and the
## diagonal mall is really diagonal.
##   plan():  the rooms the fit-out works in (BuildProps): the biggest square-on rectangle inside each shop
##   build(): the shell: floor, walls, shopfronts, ways in, ceilings, roof, signs. lod: just the outside, cheaply

const RH := 7.0            # under the mall roof
const PT := 8.0            # top of the parapet
const FRONT_H := 3.0       # shopfront opening
const CEIL := {"unit": 3.9, "store": 4.4, "bigbox": 5.4, "super": 5.4, "cinema": 6.4}

static var _data := {}
static func data(name: String) -> Dictionary:
	if not _data.has(name):
		var path := "res://assets/world/%s.json" % name
		_data[name] = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return _data[name]

static func plan(p: Dictionary, _w: float, _d: float, rng: RandomNumberGenerator, name: String) -> void:
	var dt := data(name)
	p.h = PT
	p.mall.fl = 0
	p.mall.y = 0.0
	p.mall["poly"] = name
	var rooms := []
	var kinds: Array = []
	for u in dt.get("units", []):
		var rc: Array = u.rect
		if float(rc[2]) - float(rc[0]) < 2.2 or float(rc[3]) - float(rc[1]) < 2.2: continue
		var r := {"x0": float(rc[0]) + 0.35, "z0": float(rc[1]) + 0.35, "x1": float(rc[2]) - 0.35, "z1": float(rc[3]) - 0.35, "poly": true, "uid": int(u.id)}
		var kind: String = u.kind
		match kind:
			"toilet": r["type"] = "toilet"; r["title"] = ""
			"bigbox": r["type"] = "bigbox"; r["title"] = u.title
			"super": r["type"] = "super"; r["title"] = u.title
			"cinema": r["type"] = "cine_lobby"; r["title"] = u.title
			"store":
				r["type"] = "unit"; r["title"] = u.title
				r["sub"] = "clothes" if str(u.name) == "bestless" else "general"
			_:
				if kinds.is_empty(): kinds = MallGen.UNIT_KINDS.duplicate()
				var kd: Array = kinds.pop_at(rng.randi() % kinds.size())
				r["type"] = "unit"; r["sub"] = kd[1]; r["title"] = kd[0]
		r["ceil"] = float(CEIL.get(kind, 3.9))
		r["h"] = r.ceil
		rooms.append(r)
	p.floors.append({"y": 0.0, "h": PT, "rooms": rooms})
	# v2: the cinema upstairs: a lobby across the north end, the cinemas side by side to the south
	if dt.has("cinema"):
		var c: Dictionary = dt.cinema
		var rc: Array = c.rect
		var x0 := float(rc[0]) + 0.4; var x1 := float(rc[2]) - 0.4; var z0 := float(rc[1]) + 0.4; var z1 := float(rc[3]) - 0.4
		var lob := x0 + (x1 - x0) * 0.24
		var up := [{"x0": x0, "z0": z0, "x1": lob, "z1": z1, "type": "cine_lobby", "title": "REGENT CINEMAS", "poly": true, "ceil": 4.4, "h": 4.4}]
		var n := 3
		for i in n:
			var za := z0 + (z1 - z0) * i / n; var zb := z0 + (z1 - z0) * (i + 1) / n
			up.append({"x0": lob + 0.3, "z0": za + 0.15, "x1": x1, "z1": zb - 0.15, "type": "cinema", "title": "", "poly": true, "ceil": 7.0, "h": 7.0})
		p.floors.append({"y": float(c.y), "h": float(c.roof) - float(c.y), "rooms": up})

# ------------------------------------------------------------------------------------------------ the shell
static func _tris(poly: Array) -> Array:
	var pts := PackedVector2Array()
	for q in poly: pts.append(Vector2(float(q[0]), float(q[1])))
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		pts.reverse()
		idx = Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		pts = Geometry2D.convex_hull(pts)
		idx = Geometry2D.triangulate_polygon(pts)
	var out := []
	for i in range(0, idx.size(), 3):
		out.append([pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]])
	return out

## A flat sheet over a polygon at height y, facing up or down; collide: walkable (floor)
static func _sheet(g: BuildGen.Geo, mk: String, tris: Array, y: float, up: bool, collide := false, uvs := 0.25) -> void:
	var n := Vector3.UP if up else Vector3.DOWN
	for t in tris:
		var a := Vector3(t[0].x, y, t[0].y); var b := Vector3(t[1].x, y, t[1].y); var c := Vector3(t[2].x, y, t[2].y)
		g.tri(mk, a, b, c, n, t[0] * uvs, t[1] * uvs, t[2] * uvs)
		if collide:
			g.tris.append(g.xf * a); g.tris.append(g.xf * b); g.tris.append(g.xf * c)

## A wall along a..b (x, z) from y0 to y1
static func _wall(g: BuildGen.Geo, mk: String, a: Vector2, b: Vector2, y0: float, y1: float, th: float, collide := true) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.05 or y1 - y0 < 0.02: return
	var mid := (a + b) * 0.5
	g.box(mk, Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), Vector3(mid.x, (y0 + y1) * 0.5, mid.y)), Vector3(th, y1 - y0, ln + th * 0.5), collide)

static func build(p: Dictionary, g: BuildGen.Geo, lod := false) -> void:
	var dt := data(str(p.mall.poly))
	if dt.is_empty(): return
	if int(dt.get("v", 1)) >= 2:
		build2(p, g, dt, lod)
		return
	var clad: String = p.clad
	var trim: String = p.trim
	if not p.has("_labels"): p["_labels"] = []
	var otris := _tris(dt.outline)
	if lod:
		# far off: the outline as one wall, a roof on it
		var o: Array = dt.outline
		for i in o.size():
			var a := Vector2(float(o[i][0]), float(o[i][1])); var b := Vector2(float(o[(i + 1) % o.size()][0]), float(o[(i + 1) % o.size()][1]))
			_wall(g, clad, a, b, -0.3, PT, 0.3, false)
		# the roof as it looks close up (pale over the malls, the shops' own roofs on top), so the change-over doesn't show
		_sheet(g, "trim:white", otris, RH + 0.04, true)
		for u in dt.units:
			_sheet(g, "concrete", _tris(u.poly), RH + 0.1, true)
		return
	# the floor: one sheet of terrazzo you can walk on, and the ground under the lot is levelled to meet it
	_sheet(g, "terrazzo", otris, 0.0, true, true)
	# over the malls: glass; the shops' own roofs sit just above it
	_sheet(g, "glass", otris, RH, false)
	_sheet(g, "glass", otris, RH + 0.04, true)
	# the glass roof's frame
	for bm in dt.get("beams", []):
		_wall(g, trim, Vector2(float(bm[0]), float(bm[1])), Vector2(float(bm[2]), float(bm[3])), RH - 0.35, RH, 0.22, false)
	var by_id := {}
	for u in dt.units: by_id[int(u.id)] = u
	for u in dt.units:
		var uid := int(u.id)
		var kind: String = u.kind
		var ceil_y: float = CEIL.get(kind, 3.9)
		var ut := _tris(u.poly)
		_sheet(g, "trim:white", ut, ceil_y, false)
		_sheet(g, "concrete", ut, RH + 0.1, true)
		var rc: Array = u.rect
		var cen := Vector2((float(rc[0]) + float(rc[2])) * 0.5, (float(rc[1]) + float(rc[3])) * 0.5)
		var anchor := kind != "unit"
		# an anchor's way in: the middle of its longest run of mall frontage
		var best := -1; var best_len := 0.0
		if anchor:
			for wi in u.walls.size():
				var wl: Array = u.walls[wi]
				if int(wl[4]) != 1: continue
				var ln := Vector2(float(wl[2]) - float(wl[0]), float(wl[3]) - float(wl[1])).length()
				if ln > best_len: best_len = ln; best = wi
		var signed_ := false
		for wi in u.walls.size():
			var wl: Array = u.walls[wi]
			var a := Vector2(float(wl[0]), float(wl[1])); var b := Vector2(float(wl[2]), float(wl[3]))
			var other := int(wl[4])
			var d := b - a
			var ln := d.length()
			if ln < 0.3: continue
			var t := d / ln
			var nrm := Vector2(t.y, -t.x)
			if nrm.dot((a + b) * 0.5 - cen) < 0.0: nrm = -nrm          # out of the shop
			if other == 0:
				_wall(g, clad, a, b, -0.4, PT, 0.3)
			elif other == 1:
				if anchor and wi != best:
					_wall(g, "plaster:white", a, b, 0.0, RH, 0.2)
					continue
				# a shopfront: open under a bulkhead, a pier at each end (an anchor: a wide way in in a solid front)
				var o0 := 0.0; var o1 := ln
				if anchor:
					var gap := minf(12.0, ln - 1.0)
					o0 = (ln - gap) * 0.5; o1 = o0 + gap
					_wall(g, "plaster:white", a, a + t * o0, 0.0, FRONT_H, 0.2)
					_wall(g, "plaster:white", a + t * o1, b, 0.0, FRONT_H, 0.2)
				else:
					var pier := minf(0.35, ln * 0.2)
					_wall(g, trim, a, a + t * pier, 0.0, FRONT_H, 0.24)
					_wall(g, trim, b - t * pier, b, 0.0, FRONT_H, 0.24)
				_wall(g, "plaster:white", a, b, FRONT_H, RH, 0.2, false)
				_wall(g, trim, a, b, FRONT_H - 0.12, FRONT_H, 0.26, false)
				# its name over the door, facing the mall
				var title := ""
				for r in p.floors[0].rooms:
					if int(r.get("uid", -1)) == uid: title = str(r.get("title", ""))
				if title != "" and not signed_ and ln > 3.0:
					signed_ = true
					var mid := (a + b) * 0.5 + nrm * 0.14
					var big := anchor
					ShopGen._label(p, Vector3(mid.x, FRONT_H + (0.9 if big else 0.45), mid.y), title, 0.9 if big else 0.38, minf(ln - 0.6, 14.0 if big else 6.0), atan2(nrm.x, nrm.y), Color(0.12, 0.12, 0.14))
			elif uid < other or not by_id.has(other):
				_wall(g, "plaster:white", a, b, 0.0, maxf(ceil_y, float(CEIL.get(by_id[other].kind, 3.9)) if by_id.has(other) else ceil_y) + 0.1, 0.16)
	# where a mall meets the outside: glass walls, except at its ends, which are the ways in
	for gl in dt.get("glass", []):
		for sg in gl.segs:
			var a := Vector2(float(sg[0]), float(sg[1])); var b := Vector2(float(sg[2]), float(sg[3]))
			_wall(g, clad, a, b, -0.4, 0.5, 0.3)
			_wall(g, "glass", a, b, 0.5, 4.2, 0.08)
			_wall(g, clad, a, b, 4.2, PT, 0.3, false)
	var ocen := Vector2.ZERO
	for q in dt.outline: ocen += Vector2(float(q[0]), float(q[1]))
	ocen /= maxf(dt.outline.size(), 1)
	for en in dt.get("entries", []):
		var first: Array = en.segs[0]; var last: Array = en.segs[en.segs.size() - 1]
		for sg in en.segs:
			var a := Vector2(float(sg[0]), float(sg[1])); var b := Vector2(float(sg[2]), float(sg[3]))
			_wall(g, clad, a, b, 3.6, PT, 0.3, false)
			_wall(g, trim, a, b, 3.45, 3.6, 0.9, false)          # a canopy over the doors
		# posts at each end, and the centre's name over the widest ways in
		var pa := Vector2(float(first[0]), float(first[1])); var pb := Vector2(float(last[2]), float(last[3]))
		for q in [pa, pb]:
			g.aabb(trim, Vector3(q.x - 0.2, -0.3, q.y - 0.2), Vector3(q.x + 0.2, 3.6, q.y + 0.2))
		if float(en.len) > 8.0:
			var mid := (pa + pb) * 0.5
			var dd := (pb - pa).normalized()
			var nrm := Vector2(dd.y, -dd.x)
			if nrm.dot(mid - ocen) < 0.0: nrm = -nrm
			var at := mid + nrm * 0.25
			ShopGen._label(p, Vector3(at.x, 5.2, at.y), str(p.mall.name), 1.3, minf(pa.distance_to(pb) - 1.0, 16.0), atan2(nrm.x, nrm.y), Color(0.96, 0.95, 0.9))


# ======================================================================================== v2 (the annotated plan)
const CANOPY := 3.8
const CINE_DOOR_H := 4.2

static func _flat(g: BuildGen.Geo, mk: String, t: Array, y: float, up: bool, collide := false, uvs := 0.25) -> void:
	var n := Vector3.UP if up else Vector3.DOWN
	for i in range(0, t.size(), 6):
		var a := Vector2(t[i], t[i + 1]); var b := Vector2(t[i + 2], t[i + 3]); var c := Vector2(t[i + 4], t[i + 5])
		# keep the winding facing the way we want
		if ((b - a).cross(c - a) > 0.0) == up:
			var tmp := b; b = c; c = tmp
		var A := Vector3(a.x, y, a.y); var B := Vector3(b.x, y, b.y); var C := Vector3(c.x, y, c.y)
		g.tri(mk, A, B, C, n, a * uvs, b * uvs, c * uvs)
		if collide:
			g.tris.append(g.xf * A); g.tris.append(g.xf * B); g.tris.append(g.xf * C)

## Pieces of a..b left once the openings that lie along it are taken out: [[a, b, opening?], ...]
static func _cut(a: Vector2, b: Vector2, opens: Array, tol := 1.2) -> Array:
	var d := b - a
	var ln := d.length()
	if ln < 0.01: return []
	var t := d / ln
	var spans := []
	for o in opens:
		var oa := Vector2(float(o[0]), float(o[1])); var ob := Vector2(float(o[2]), float(o[3]))
		# close to the line, and overlapping it
		var ra := (oa - a).dot(t); var rb := (ob - a).dot(t)
		var da := absf((oa - a).cross(t)); var db := absf((ob - a).cross(t))
		if maxf(da, db) > tol: continue
		var s0 := clampf(minf(ra, rb) - 0.3, 0.0, ln); var s1 := clampf(maxf(ra, rb) + 0.3, 0.0, ln)
		if s1 - s0 > 0.4: spans.append([s0, s1])
	spans.sort_custom(func(x, y): return x[0] < y[0])
	var out := []
	var cur := 0.0
	for sp in spans:
		if sp[0] > cur + 0.05: out.append([a + t * cur, a + t * sp[0], false])
		out.append([a + t * maxf(sp[0], cur), a + t * sp[1], true])
		cur = maxf(cur, sp[1])
	if ln > cur + 0.05: out.append([a + t * cur, b, false])
	return out

## A sloped slab from a (at ya) to b (at yb), w wide and 0.25 thick, that you can walk or drive on
static func _slope(g: BuildGen.Geo, mk: String, a: Vector2, ya: float, b: Vector2, yb: float, w: float) -> void:
	var d := b - a
	var hz := d.length()
	if hz < 0.1: return
	var mid := (a + b) * 0.5
	var ang := atan(( yb - ya) / hz)
	var basis := Basis(Vector3.UP, atan2(d.x, d.y)) * Basis(Vector3.RIGHT, -ang)
	var len3 := sqrt(hz * hz + (yb - ya) * (yb - ya))
	g.box(mk, Transform3D(basis, Vector3(mid.x, (ya + yb) * 0.5 - 0.13, mid.y)), Vector3(w, 0.26, len3 + 0.1), true)

static func _stairs(g: BuildGen.Geo, mk: String, a: Vector2, ya: float, b: Vector2, yb: float, w: float) -> void:
	# treads you see, and a smooth slope under them to walk up
	var d := b - a
	var hz := d.length()
	var n := maxi(int(ceil((yb - ya) / 0.175)), 1)
	var t := d / hz
	var rot := Basis(Vector3.UP, atan2(d.x, d.y))
	for i in n:
		var p := a + t * (hz * (i + 0.5) / n)
		var top := ya + (yb - ya) * (i + 1) / n
		g.box(mk, Transform3D(rot, Vector3(p.x, (ya + top) * 0.5, p.y)), Vector3(w, top - ya, hz / n + 0.02), false)
	_slope(g, mk, a, ya, b, yb, w)

static func build2(p: Dictionary, g: BuildGen.Geo, dt: Dictionary, lod: bool) -> void:
	var clad: String = p.clad
	var trim: String = p.trim
	if not p.has("_labels"): p["_labels"] = []
	var cine: Dictionary = dt.get("cinema", {})
	var crc: Array = cine.get("rect", [0, 0, 0, 0])
	var cy := float(cine.get("y", 5.2)); var croof := float(cine.get("roof", 13.0))
	var c0 := Vector2(float(crc[0]), float(crc[1])); var c1 := Vector2(float(crc[2]), float(crc[3]))
	if lod:
		var o: Array = dt.outline
		for i in o.size():
			var a := Vector2(float(o[i][0]), float(o[i][1])); var b := Vector2(float(o[(i + 1) % o.size()][0]), float(o[(i + 1) % o.size()][1]))
			_wall(g, clad, a, b, -0.3, PT, 0.3, false)
		_flat(g, "trim:white", dt.inside_tris, RH + 0.04, true)
		for u in dt.units: _sheet(g, "concrete", _tris(u.poly), RH + 0.1, true)
		_flat(g, trim, dt.covered_tris, CANOPY + 0.1, true)
		g.aabb(clad, Vector3(c0.x, 0, c0.y), Vector3(c1.x, croof, c1.y), false)
		return
	# ---- ground floor, mall roof, canopies
	_flat(g, "terrazzo", dt.floor_tris, 0.0, true, true)
	_flat(g, "glass", dt.inside_tris, RH, false)
	_flat(g, "glass", dt.inside_tris, RH + 0.04, true)
	for bm in dt.get("beams", []):
		_wall(g, trim, Vector2(float(bm[0]), float(bm[1])), Vector2(float(bm[2]), float(bm[3])), RH - 0.35, RH, 0.22, false)
	_flat(g, "trim:white", dt.covered_tris, CANOPY, false)
	_flat(g, "tin:grey", dt.covered_tris, CANOPY + 0.12, true)
	for q in dt.get("covered_posts", []):
		g.aabb(trim, Vector3(float(q[0]) - 0.12, 0.0, float(q[1]) - 0.12), Vector3(float(q[0]) + 0.12, CANOPY, float(q[1]) + 0.12))
	# ---- shops, anchors, toilets
	var by_id := {}
	for u in dt.units: by_id[int(u.id)] = u
	var tdoors: Array = dt.get("toilet_doors", [])
	var entries: Array = dt.get("entries", [])
	for u in dt.units:
		var uid := int(u.id)
		var kind: String = u.kind
		var ceil_y: float = CEIL.get(kind, 3.9)
		if kind == "toilet": ceil_y = 3.0
		var ut := _tris(u.poly)
		_sheet(g, "tile:white" if kind == "toilet" else "trim:white", ut, ceil_y, false)
		_sheet(g, "concrete", ut, RH + 0.1, true)
		var rc: Array = u.rect
		var cen := Vector2((float(rc[0]) + float(rc[2])) * 0.5, (float(rc[1]) + float(rc[3])) * 0.5)
		var anchor := kind in ["bigbox", "super", "store", "cinema"]
		var best := -1; var best_len := 0.0
		if anchor:
			for wi in u.walls.size():
				var wl: Array = u.walls[wi]
				if int(wl[4]) not in [1, 2]: continue
				var ln := Vector2(float(wl[2]) - float(wl[0]), float(wl[3]) - float(wl[1])).length()
				if ln > best_len: best_len = ln; best = wi
		var title := ""
		for r in p.floors[0].rooms:
			if int(r.get("uid", -1)) == uid: title = str(r.get("title", ""))
		var signed_ := false
		for wi in u.walls.size():
			var wl: Array = u.walls[wi]
			var a := Vector2(float(wl[0]), float(wl[1])); var b := Vector2(float(wl[2]), float(wl[3]))
			var other := int(wl[4])
			var d := b - a
			var ln := d.length()
			if ln < 0.3: continue
			var t := d / ln
			var nrm := Vector2(t.y, -t.x)
			if nrm.dot((a + b) * 0.5 - cen) < 0.0: nrm = -nrm
			if other == 0 or other == 4:
				# outside: a solid wall up to the parapet, with any marked way in cut through it
				for pc in _cut(a, b, entries):
					if pc[2]:
						_wall(g, clad, pc[0], pc[1], 3.0, PT, 0.3, false)
					else:
						_wall(g, clad, pc[0], pc[1], -0.4, PT, 0.3)
			elif other == 5:
				_wall(g, "plaster:white", a, b, 0.0, RH, 0.2)
			elif other == 1 or other == 2:
				var top := RH if other == 1 else PT
				var face := "plaster:white" if other == 1 else clad
				if kind == "toilet":
					for pc in _cut(a, b, tdoors, 1.5):
						if pc[2]:
							_wall(g, "plaster:white", pc[0], pc[1], 2.2, top, 0.18, false)
						else:
							_wall(g, "plaster:white", pc[0], pc[1], 0.0, top, 0.18)
					continue
				if anchor and wi != best:
					_wall(g, face, a, b, 0.0, top, 0.2)
					continue
				var o0 := 0.0; var o1 := ln
				if anchor:
					var gap := minf(12.0, ln - 1.0)
					o0 = (ln - gap) * 0.5; o1 = o0 + gap
					_wall(g, face, a, a + t * o0, 0.0, FRONT_H, 0.2)
					_wall(g, face, a + t * o1, b, 0.0, FRONT_H, 0.2)
				else:
					var pier := minf(0.35, ln * 0.2)
					_wall(g, trim, a, a + t * pier, 0.0, FRONT_H, 0.24)
					_wall(g, trim, b - t * pier, b, 0.0, FRONT_H, 0.24)
				_wall(g, face, a, b, FRONT_H, top, 0.2, false)
				_wall(g, trim, a, b, FRONT_H - 0.12, FRONT_H, 0.26, false)
				if title != "" and not signed_ and ln > 3.0:
					signed_ = true
					var mid := (a + b) * 0.5 + nrm * 0.14
					ShopGen._label(p, Vector3(mid.x, FRONT_H + (0.9 if anchor else 0.45), mid.y), title, 0.9 if anchor else 0.38, minf(ln - 0.6, 14.0 if anchor else 6.0), atan2(nrm.x, nrm.y), Color(0.12, 0.12, 0.14))
			elif uid < other or not by_id.has(other):
				_wall(g, "plaster:white", a, b, 0.0, maxf(ceil_y, float(CEIL.get(by_id[other].kind, 3.9)) if by_id.has(other) else ceil_y) + 0.1, 0.16)
	# ---- where the inside meets the outside (or the covered walkways): glass, with the green ways in left open
	for wl in dt.get("inside_walls", []):
		var a := Vector2(float(wl[0]), float(wl[1])); var b := Vector2(float(wl[2]), float(wl[3]))
		for pc in _cut(a, b, entries):
			if pc[2]:
				_wall(g, clad, pc[0], pc[1], 3.6, PT, 0.3, false)
				_wall(g, trim, pc[0], pc[1], 3.45, 3.6, 0.9, false)
			elif int(wl[4]) == 4:
				_wall(g, clad, pc[0], pc[1], -0.4, PT, 0.3)
			else:
				_wall(g, clad, pc[0], pc[1], -0.4, 0.5, 0.3)
				_wall(g, "glass", pc[0], pc[1], 0.5, 3.4, 0.08)
				_wall(g, clad, pc[0], pc[1], 3.4, PT, 0.3, false)
	# ---- travelators down to the car park: a moving ramp with glass sides
	var by := float(dt.basement.y) if dt.has("basement") else -4.0
	for tr in dt.get("travelators", []):
		var a := Vector2(float(tr[0]), float(tr[1])); var b := Vector2(float(tr[2]), float(tr[3]))
		var w := float(tr[4])
		var d := (b - a).normalized()
		var sd := Vector2(d.y, -d.x)
		_slope(g, "rubber", a, 0.0, b, by, w - 0.5)
		# a flat plate at the top over the edge of the cut, and one at the bottom onto the car park floor
		var lip := a - d * 1.2
		g.box("steel", Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), Vector3((lip.x + a.x) * 0.5, -0.04, (lip.y + a.y) * 0.5)), Vector3(w - 0.5, 0.08, 1.2), true)
		for s_ in [-1.0, 1.0]:
			var off: Vector2 = sd * (w * 0.5 - 0.15) * s_
			# the balustrade: glass along the ramp, a steel rail on top, the cut floor edge closed with a skirt
			for k in 8:
				var f0 := k / 8.0; var f1 := (k + 1) / 8.0
				var pa: Vector2 = a.lerp(b, f0) + off; var pb: Vector2 = a.lerp(b, f1) + off
				var ya := lerpf(0.0, by, f0); var yb := lerpf(0.0, by, f1)
				_wall(g, "glass", pa, pb, minf(ya, yb), maxf(ya, yb) + 1.0, 0.06)
				_wall(g, trim, pa, pb, maxf(ya, yb) + 1.0, maxf(ya, yb) + 1.08, 0.1, false)
			_wall(g, clad, a + off, b + off, by, 0.0, 0.2)
		# the far end of the hole: a wall from the car park ceiling up to the floor
		_wall(g, clad, b - sd * w * 0.5 + d * 0.3, b + sd * w * 0.5 + d * 0.3, by + 2.6, 0.0, 0.25, false)

		var mid := a.lerp(b, 0.15) + d * 0.0
		ShopGen._label(p, Vector3(a.x, 2.6, a.y), "CAR PARK", 0.3, 3.0, atan2(-d.x, -d.y), Color(0.1, 0.2, 0.55))
	# ---- the underground car park
	if dt.has("basement"):
		var bs: Dictionary = dt.basement
		_flat(g, "trim:grey", bs.tris, by, true, true)
		_flat(g, "trim:white", bs.tris, -0.32, false)
		# fluoro tubes on the ceiling, one between each pair of column rows
		for q in bs.cols:
			g.aabb("lamp", Vector3(float(q[0]) - 1.2, -0.42, float(q[1]) + 3.9), Vector3(float(q[0]) + 1.2, -0.34, float(q[1]) + 4.1), false)
		for wl in bs.walls:
			_wall(g, "concrete", Vector2(float(wl[0]), float(wl[1])), Vector2(float(wl[2]), float(wl[3])), by, -0.3, 0.3)
		for q in bs.cols:
			g.aabb("concrete", Vector3(float(q[0]) - 0.3, by, float(q[1]) - 0.3), Vector3(float(q[0]) + 0.3, -0.3, float(q[1]) + 0.3))
		# parking bay lines along the column rows
		for q in bs.cols:
			g.aabb("trim:white", Vector3(float(q[0]) - 2.6, by + 0.005, float(q[1]) - 0.05), Vector3(float(q[0]) + 2.6, by + 0.015, float(q[1]) + 0.05), false)
	# ---- the car ramp down, in the cinema building's ground floor
	if dt.has("ramp"):
		var rp: Dictionary = dt.ramp
		var top := Vector2(rp.top[0], rp.top[1]); var bot := Vector2(rp.bottom[0], rp.bottom[1]); var door := Vector2(rp.door[0], rp.door[1])
		var w := float(rp.w)
		var d := (bot - top).normalized()
		var sd := Vector2(d.y, -d.x)
		_slope(g, "concrete_worn", door, 0.0, top, 0.0, w)
		_slope(g, "concrete_worn", top, 0.0, bot, by, w)
		for s_ in [-1.0, 1.0]:
			var off: Vector2 = sd * (w * 0.5 + 0.15) * s_
			_wall(g, "concrete", door + off, bot + off, by, 0.9, 0.3)
		_wall(g, "concrete", top - sd * w * 0.5 + d * 0.0, top + sd * w * 0.5, 0.0, 0.0, 0.2, false)
	# ---- the cinema building: walls round it, the floor upstairs, the roof
	if not cine.is_empty():
		var cn := [Vector2(c0.x, c0.y), Vector2(c1.x, c0.y), Vector2(c1.x, c1.y), Vector2(c0.x, c1.y)]
		var st: Dictionary = cine.stairs
		var sb := Vector2(st.bottom[0], st.bottom[1]); var stp := Vector2(st.top[0], st.top[1])
		var sw := float(st.w)
		var rdoor := Vector2(dt.ramp.door[0], dt.ramp.door[1]) if dt.has("ramp") else Vector2.INF
		for i in 4:
			var a: Vector2 = cn[i]; var b: Vector2 = cn[(i + 1) % 4]
			# the ramp's door in the south wall, the stair landing in the north wall
			var opens := []
			if rdoor != Vector2.INF and absf((b - a).normalized().cross(rdoor - a)) < 2.5:
				var t := (b - a).normalized()
				opens.append([(rdoor - t * (float(dt.ramp.w) * 0.5 + 0.6)).x, (rdoor - t * (float(dt.ramp.w) * 0.5 + 0.6)).y, (rdoor + t * (float(dt.ramp.w) * 0.5 + 0.6)).x, (rdoor + t * (float(dt.ramp.w) * 0.5 + 0.6)).y])
			var lnd := Vector2(st.landing[0], st.landing[1])
			var landing := absf((b - a).normalized().cross(lnd - a)) < 3.5
			for pc in _cut(a, b, opens, 3.0):
				if pc[2]:
					_wall(g, clad, pc[0], pc[1], CINE_DOOR_H, croof, 0.35, false)
				elif landing:
					var wt := (b - a).normalized()
					var mid := lnd.lerp(stp, 0.5)
					var hole := [(mid - wt * 2.2).x, (mid - wt * 2.2).y, (mid + wt * 2.2).x, (mid + wt * 2.2).y]
					for pc2 in _cut(pc[0], pc[1], [hole], 3.5):
						if pc2[2]:
							_wall(g, clad, pc2[0], pc2[1], -0.4, cy, 0.35)
							_wall(g, clad, pc2[0], pc2[1], cy + 3.0, croof, 0.35, false)
						else:
							_wall(g, clad, pc2[0], pc2[1], -0.4, croof, 0.35)
				else:
					_wall(g, clad, pc[0], pc[1], -0.4, croof, 0.35)
		# upstairs floor and the ground floor's ceiling, the roof
		var slab := [c0.x, c0.y, c1.x, c0.y, c1.x, c1.y, c0.x, c0.y, c1.x, c1.y, c0.x, c1.y]
		_flat(g, "carpet:maroon", slab, cy, true, true)
		_flat(g, "concrete", slab, cy - 0.3, false)
		_flat(g, "concrete", slab, croof, true)
		_flat(g, "plaster:white", slab, croof - 0.3, false)
		# upstairs: the lobby wall with a door to each cinema, the walls between the cinemas
		var x0 := c0.x + 0.4; var x1 := c1.x - 0.4; var z0 := minf(c0.y, c1.y) + 0.4; var z1 := maxf(c0.y, c1.y) - 0.4
		var lob := x0 + (x1 - x0) * 0.24
		var n := 3
		for i in n:
			var za := z0 + (z1 - z0) * i / n; var zb := z0 + (z1 - z0) * (i + 1) / n
			var zm := (za + zb) * 0.5
			_wall(g, "plaster:charcoal", Vector2(lob, za), Vector2(lob, zm - 1.1), cy, croof - 0.3, 0.25)
			_wall(g, "plaster:charcoal", Vector2(lob, zm + 1.1), Vector2(lob, zb), cy, croof - 0.3, 0.25)
			_wall(g, "plaster:charcoal", Vector2(lob, zm - 1.1), Vector2(lob, zm + 1.1), cy + 2.4, croof - 0.3, 0.25, false)
			if i > 0:
				_wall(g, "plaster:charcoal", Vector2(lob, za), Vector2(x1, za), cy, croof - 0.3, 0.3)
			# raked seating: steps rising to the back (south) of each cinema, and a screen at the lobby end
			var rows := 9
			for k in rows:
				var xa := lob + 6.0 + (x1 - lob - 7.0) * k / rows
				var xb := lob + 6.0 + (x1 - lob - 7.0) * (k + 1) / rows
				g.aabb("carpet:maroon", Vector3(xa, cy, za + 1.2), Vector3(xb, cy + 0.3 * (k + 1), zb - 1.2))
			g.aabb("lamp:grey", Vector3(lob + 0.6, cy + 1.6, za + 1.5), Vector3(lob + 0.75, cy + 5.6, zb - 1.5), false)
			# step lights up the aisle and two ceiling downlight strips
			g.aabb("lamp:yellow", Vector3(lob + 6.0, cy + 0.02, za + 0.5), Vector3(x1 - 1.0, cy + 0.06, za + 0.6), false)
			for zz in [lerpf(za, zb, 0.3), lerpf(za, zb, 0.7)]:
				g.aabb("lamp:yellow", Vector3(lob + 3.0, croof - 0.42, zz - 0.1), Vector3(x1 - 2.0, croof - 0.34, zz + 0.1), false)
			ShopGen._label(p, Vector3(lob - 0.14, cy + 2.8, zm), "CINEMA %d" % (i + 1), 0.35, 2.4, -PI * 0.5, Color(0.9, 0.85, 0.6))
		# lobby ceiling panels
		var lz := z0 + 3.0
		while lz < z1 - 2.0:
			var lx := x0 + 3.0
			while lx < lob - 2.0:
				g.aabb("lamp", Vector3(lx - 0.6, croof - 0.42, lz - 0.6), Vector3(lx + 0.6, croof - 0.34, lz + 0.6), false)
				lx += 6.0
			lz += 6.0
		# the stairs up from the mall, a roof over the stair hall
		_stairs(g, "terrazzo", sb, 0.0, stp, cy, sw)
		var lnd2 := Vector2(st.landing[0], st.landing[1])
		var ld := (lnd2 - stp)
		# starts right where the stairs end (any overlap is a lip you can't walk over)
		var lend := lnd2 + ld.normalized() * 1.2
		g.box("terrazzo", Transform3D(Basis(Vector3.UP, atan2(ld.x, ld.y)), Vector3((stp.x + lend.x) * 0.5, cy - 0.15, (stp.y + lend.y) * 0.5)), Vector3(sw + 1.0, 0.3, stp.distance_to(lend)), true)
		var sd := (stp - sb).normalized().orthogonal()
		for s_ in [-1.0, 1.0]:
			var off: Vector2 = sd * (sw * 0.5 + 0.1) * s_
			_wall(g, "glass", sb + off, stp + off, 0.0, cy + 1.0, 0.06, false)
			_wall(g, trim, sb + off, stp + off, cy + 1.0, cy + 1.08, 0.1, false)
		# the stair hall: a roof over all of it, and a wall on its far (west) side where it meets the outside
		var bx: Array = cine.get("box", [])
		if bx.size() == 4:
			var lo := Vector2(minf(bx[0], bx[2]), minf(bx[1], bx[3])); var hi := Vector2(maxf(bx[0], bx[2]), maxf(bx[1], bx[3]))
			g.aabb("concrete", Vector3(lo.x, cy + 3.4, lo.y), Vector3(hi.x, cy + 3.7, hi.y), false)
			g.aabb("plaster:white", Vector3(lo.x, cy + 3.3, lo.y), Vector3(hi.x, cy + 3.4, hi.y), false)
			var far := hi.y if absf(hi.y - stp.y) < absf(lo.y - stp.y) else lo.y
			_wall(g, clad, Vector2(lo.x, far), Vector2(hi.x, far), -0.4, cy + 3.7, 0.3)
		ShopGen._label(p, Vector3(sb.x - 0.5, 4.6, sb.y), "CINEMAS  UPSTAIRS", 0.4, 6.0, atan2(-(stp - sb).normalized().x, -(stp - sb).normalized().y), Color(0.9, 0.85, 0.6))
	# ---- ways in from the outside: the centre's name over the big ones
	var ocen := Vector2.ZERO
	for q in dt.outline: ocen += Vector2(float(q[0]), float(q[1]))
	ocen /= maxf(dt.outline.size(), 1)
	for en in entries:
		var pa := Vector2(float(en[0]), float(en[1])); var pb := Vector2(float(en[2]), float(en[3]))
		if pa.distance_to(pb) < 5.0: continue
		var mid := (pa + pb) * 0.5
		var dd := (pb - pa).normalized()
		var nrm := Vector2(dd.y, -dd.x)
		if nrm.dot(mid - ocen) < 0.0: nrm = -nrm
		var at := mid + nrm * 0.25
		ShopGen._label(p, Vector3(at.x, 4.6, at.y), str(p.mall.name), 0.9, minf(pa.distance_to(pb) - 0.5, 12.0), atan2(nrm.x, nrm.y), Color(0.96, 0.95, 0.9))


## The terrain's surface sits just under the mall floor; where you go down (the travelators, the car ramp) it has
## to go. Holes in the terrain over those (5 m cells, so they spill a little under the floor round them, which hides
## them). Called once when the world loads, after the ground's levelled.
static func terrain_holes(name: String, lot: Array, td) -> int:
	var dt := data(name)
	if int(dt.get("v", 1)) < 2 or not td.has_method("set_control_hole"): return 0
	var xf := Transform3D(Basis(Vector3.UP, float(lot[3])), Vector3(float(lot[1]), 0, float(lot[2])))
	var rects := []          # [a, b, half width] in the lot's frame
	for tr in dt.get("travelators", []):
		rects.append([Vector2(tr[0], tr[1]), Vector2(tr[2], tr[3]), float(tr[4]) * 0.5])
	if dt.has("ramp"):
		var rp: Dictionary = dt.ramp
		rects.append([Vector2(rp.top[0], rp.top[1]), Vector2(rp.bottom[0], rp.bottom[1]), float(rp.w) * 0.5])
	var n := 0
	for r in rects:
		var a: Vector2 = r[0]; var b: Vector2 = r[1]; var hw: float = r[2] + 2.6
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * (hw + 5.0)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * (hw + 5.0)
		var wlo := xf * Vector3(lo.x, 0, lo.y); var whi := xf * Vector3(hi.x, 0, hi.y)
		var c := (wlo + whi) * 0.5
		var rad := wlo.distance_to(whi) * 0.5 + 5.0
		var x := snappedf(c.x - rad, 5.0)
		while x <= c.x + rad:
			var z := snappedf(c.z - rad, 5.0)
			while z <= c.z + rad:
				# the cell from this vertex: does it touch the ramp's footprint (padded)?
				var hit := false
				for cc in [Vector2(2.5, 2.5), Vector2(0, 0), Vector2(5, 0), Vector2(0, 5), Vector2(5, 5)]:
					var lp: Vector3 = xf.affine_inverse() * Vector3(x + cc.x, 0, z + cc.y)
					var q := Vector2(lp.x, lp.z)
					var ab := b - a
					var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
					if q.distance_to(a + ab * t) <= hw: hit = true; break
				if hit:
					td.set_control_hole(Vector3(x, 0, z), true)
					n += 1
				z += 5.0
			x += 5.0
	return n
