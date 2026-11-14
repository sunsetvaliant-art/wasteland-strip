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
