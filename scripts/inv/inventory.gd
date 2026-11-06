class_name Inventory
extends RefCounted
## Grid storage, Unturned style. A grid is {"w", "h", "items": [stack, ...]}; a stack is
## {"id", "n", "x", "y", "r" (turned 90°), "data"}. Clothes and bags carry their own grid in data.grid, so whatever's
## in your pockets goes with the shirt if you take it off or drop it.

## Does a stack of this size fit at x, y (ignoring one stack, the one being moved)?
static func fits(g: Dictionary, sz: Vector2i, x: int, y: int, ignore = null) -> bool:
	if x < 0 or y < 0 or x + sz.x > int(g.w) or y + sz.y > int(g.h):
		return false
	for s in g.items:
		if s == ignore:
			continue
		var o := Items.size_of(s)
		if x < s.x + o.x and s.x < x + sz.x and y < s.y + o.y and s.y < y + sz.y:
			return false
	return true

## The stack covering a cell, or null
static func at(g: Dictionary, x: int, y: int):
	for s in g.items:
		var o := Items.size_of(s)
		if x >= s.x and x < s.x + o.x and y >= s.y and y < s.y + o.y:
			return s
	return null

## First free spot for this stack (tries it turned too). Returns {"x", "y", "r"} or {}
static func free_spot(g: Dictionary, s: Dictionary) -> Dictionary:
	for rot in [s.get("r", false), not s.get("r", false)]:
		var t := s.duplicate()
		t.r = rot
		var sz := Items.size_of(t)
		for y in int(g.h):
			for x in int(g.w):
				if fits(g, sz, x, y):
					return {"x": x, "y": y, "r": rot}
	return {}

## Put a stack in: tops up matching stacks first, then a free spot. Returns how many didn't fit.
static func add(g: Dictionary, s: Dictionary) -> int:
	var d := Items.def(s.id)
	var left: int = s.n
	if int(d.stack) > 1:
		for o in g.items:
			if o.id == s.id and o.n < int(d.stack):
				var take: int = min(int(d.stack) - o.n, left)
				o.n += take
				left -= take
				if left <= 0:
					return 0
	while left > 0:
		var part := s.duplicate(true)
		part.n = min(left, int(d.stack))
		var spot := free_spot(g, part)
		if spot.is_empty():
			return left
		part.x = spot.x
		part.y = spot.y
		part.r = spot.r
		g.items.append(part)
		left -= part.n
	return 0

static func count(g: Dictionary, id: String) -> int:
	var n := 0
	for s in g.items:
		if s.id == id: n += int(s.n)
	return n

## Take up to n of an item out, smallest stacks first. Returns how many came out.
static func take(g: Dictionary, id: String, n: int) -> int:
	var got := 0
	var mine: Array = g.items.filter(func(s): return s.id == id)
	mine.sort_custom(func(a, b): return a.n < b.n)
	for s in mine:
		if got >= n: break
		var t: int = min(int(s.n), n - got)
		s.n -= t
		got += t
		if s.n <= 0:
			g.items.erase(s)
	return got
