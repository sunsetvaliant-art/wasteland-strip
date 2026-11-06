class_name PlayerInv
extends Node
## What you're carrying. Equipment slots (guns, bag, clothes) plus your hands (5 x 3, always there); a worn shirt,
## pants and bag add their own pockets. The guns in the primary and secondary slots are the ones in your hands
## (keys 1 and 2), and their reserve is whatever matching rounds you're carrying.

signal changed

const SLOTS := ["primary", "secondary", "back", "head", "top", "bottom", "feet"]
const SLOT_NAMES := {"primary": "Primary", "secondary": "Secondary", "back": "Back", "head": "Head", "top": "Shirt", "bottom": "Pants", "feet": "Feet"}

var player
var hands := Items.new_grid(5, 3)
var equip := {}            # slot -> stack (or absent)
var using := {}            # item being used: {"stack", "grid", "t", "total"}

func setup(p) -> void:
	player = p

## Every grid you can put things in, in the order things go in: [[label, grid], ...]
func grids() -> Array:
	var out: Array = [["Hands", hands]]
	for sl in ["top", "bottom", "back"]:
		var s = equip.get(sl)
		if s and s.data.has("grid"):
			out.append([Items.def(s.id).name, s.data.grid])
	return out

func count(id: String) -> int:
	var n := 0
	for g in grids(): n += Inventory.count(g[1], id)
	return n

func take(id: String, n: int) -> int:
	var got := 0
	for g in grids():
		if got >= n: break
		got += Inventory.take(g[1], id, n - got)
	if got > 0: changed.emit()
	return got

## Pick something up: straight onto your back / body if that slot's free, else into the first space. Returns leftover.
func add(s: Dictionary) -> int:
	var d := Items.def(s.id)
	if d.has("slot") and not equip.has(d.slot) and s.n == 1 and d.slot in ["primary", "secondary", "back"]:
		equip[d.slot] = s
		_equip_changed()
		return 0
	var left: int = s.n
	for g in grids():
		var part := s.duplicate(true)
		part.n = left
		left = Inventory.add(g[1], part)
		if left <= 0: break
	changed.emit()
	return left

## Wear / hold it (from wherever it is). Whatever was in the slot goes back into the grids if it fits.
func can_equip(s: Dictionary, slot: String) -> bool:
	var d := Items.def(s.id)
	if not d.has("slot"): return false
	if d.slot == slot: return true
	return d.kind == "gun" and slot in ["primary", "secondary"]        # a handgun can go in primary and the other way

func set_slot(slot: String, s) -> void:
	if s == null:
		equip.erase(slot)
	else:
		equip[slot] = s
	_equip_changed()

func _equip_changed() -> void:
	sync_guns()
	changed.emit()

## Rebuild the guns in your hands from the two gun slots, keeping each one's loaded rounds with its item
func sync_guns() -> void:
	if player == null: return
	var want: Array = []
	for sl in ["primary", "secondary"]:
		var s = equip.get(sl)
		if s and Items.def(s.id).kind == "gun":
			want.append(s)
	var cur = player.gun()
	var cur_stack = cur.get_meta("stack") if cur and cur.has_meta("stack") else null
	for g in player.guns:
		if g.has_meta("stack"):
			g.get_meta("stack").data["ammo"] = g.ammo
		g.queue_free()
	player.guns.clear()
	for s in want:
		var g: Gun = Gun.new()
		player.add_child(g)
		g.setup(Items.def(s.id).gun, player)
		g.excludes = [player.get_rid()]
		g.ammo = int(s.data.get("ammo", 0))
		g.set_meta("stack", s)
		var aid: String = Items.GUN_AMMO.get(g.key, "")
		g.on_take = func(n): take(aid, n)
		g.visible = false
		player.guns.append(g)
	player.gun_i = 0
	for i in player.guns.size():
		if player.guns[i].get_meta("stack") == cur_stack: player.gun_i = i
	player.gun_i = clampi(player.gun_i, 0, max(player.guns.size() - 1, 0))

## Called every frame: the guns' reserve is what you're carrying, their loaded rounds live on the item
func tick(dt: float) -> void:
	for g in player.guns:
		g.reserve = count(Items.GUN_AMMO.get(g.key, ""))
		if g.has_meta("stack"):
			g.get_meta("stack").data["ammo"] = g.ammo
	if not using.is_empty():
		using.t += dt
		if player.velocity.length() > 4.0 or player.dead:
			using.clear()          # sprinting or dying spoils it
		elif using.t >= using.total:
			var s: Dictionary = using.stack
			var d := Items.def(s.id)
			player.hp = min(player.hp + float(d.get("heal", 0.0)), 100.0)
			s.n -= 1
			if s.n <= 0:
				using.grid.items.erase(s)
			using.clear()
			changed.emit()

## Bandages and food: takes a moment, cancelled if you run
func use(s: Dictionary, g: Dictionary) -> bool:
	var d := Items.def(s.id)
	if not d.kind in ["med", "food"] or not using.is_empty():
		return false
	if player.hp >= 99.5 and d.kind == "med":
		return false
	using = {"stack": s, "grid": g, "t": 0.0, "total": float(d.get("use_time", 2.0))}
	return true

## Use the first bandage you've got (the B key)
func quick_heal() -> bool:
	for id in ["bandage", "medkit"]:
		for g in grids():
			for s in g[1].items:
				if s.id == id:
					return use(s, g[1])
	return false

func loadout(creative: bool) -> void:
	equip.clear()
	hands = Items.new_grid(5, 3)
	if creative:
		equip["primary"] = Items.fresh("gun_enfield")
		equip["secondary"] = Items.fresh("gun_python")
		equip["top"] = Items.fresh("jacket_army")
		equip["bottom"] = Items.fresh("pants_cargo")
		equip["back"] = Items.fresh("pack_large")
		for k in ["enfield", "python"]: equip["primary" if k == "enfield" else "secondary"].data.ammo = int(Gun.DEFS[k].mag)
		for id in ["gun_slr", "gun_rem870", "gun_dbshotgun", "gun_sawnoff"]:
			var s := Items.fresh(id)
			s.data.ammo = int(Gun.DEFS[Items.def(id).gun].mag)
			Inventory.add(equip.back.data.grid, s)
		for a in [["ammo_303", 60], ["ammo_762", 80], ["ammo_357", 36], ["ammo_12g", 40], ["bandage", 10], ["medkit", 1], ["food_can", 4]]:
			add(Items.fresh(a[0], a[1]))
	else:
		equip["secondary"] = Items.fresh("gun_python")
		equip.secondary.data.ammo = 6
		equip["top"] = Items.fresh("shirt_flanno")
		equip["bottom"] = Items.fresh("pants_jeans")
		add(Items.fresh("ammo_357", 12))
		add(Items.fresh("bandage", 3))
		add(Items.fresh("food_can", 1))
	sync_guns()
	changed.emit()
