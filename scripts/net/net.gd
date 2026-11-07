class_name Net
extends Node
## LAN multiplayer. One player hosts (the pause menu's Multiplayer page), the others on the same network find the
## game in the list (the host shouts on the LAN once a second) or type its address, and join.
##   The host runs the world: zombies and scavs think on the host only; everyone else gets them as puppets that
##   follow the host's snapshots (10 a second). Shots at a puppet are sent to the host, which does the damage and
##   tells everyone when one dies (each machine ragdolls its own copy).
##   Each player runs themselves: where they are, which way they look, their gun, what they're driving, sent 20 times
##   a second. A car someone else is driving follows their snapshots on your machine.
##   Loot, inventories and the Forge stay on each machine.
## Everything goes through this one node (/root/Main/Net), so its path is the same on every machine.

const PORT := 24680
const BEACON_PORT := 24681
const MAX_PLAYERS := 8
const BODIES := ["player", "survivor_female", "scav_2", "warboy", "scav_hooded", "warbringer", "warboy_enforcer", "player"]

var main
var peer: ENetMultiplayerPeer
var hosting := false
var my_name := "Survivor"
var players := {}            # peer id -> RemotePlayer
var names := {}              # peer id -> name
var npcs := {}               # host: net id -> NPC     client: net id -> NPC puppet
var _npc_ids := {}           # host: NPC -> net id
var _next_id := 1
var _send_t := 0.0
var _world_t := 0.0
var _beacon_t := 0.0
var _udp: PacketPeerUDP
var found := {}              # LAN games heard: "ip" -> {name, players, t}
var status := ""
signal changed

func setup(m) -> void:
	main = m
	name = "Net"
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): status = "Connected"; rpc_id(1, "hello", my_name, Boot.version); changed.emit())
	multiplayer.connection_failed.connect(func(): status = "Couldn't connect"; _close(); changed.emit())
	multiplayer.server_disconnected.connect(func(): status = "The host left"; _close(); changed.emit())

func online() -> bool:
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func is_client() -> bool:
	return online() and not hosting

## AI and spawning run here (offline, or the host)
func runs_world() -> bool:
	return not is_client()

# ---------------------------------------------------------------- starting and stopping
func host() -> String:
	_close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		peer = null
		return "Couldn't host (port %d busy?)" % PORT
	multiplayer.multiplayer_peer = peer
	hosting = true
	status = "Hosting on %s, port %d" % [", ".join(lan_addresses()), PORT]
	# the zombies and scavs already about become the shared ones
	for n in get_tree().get_nodes_in_group("npcs"):
		_register(n)
	changed.emit()
	return status

func join(ip: String) -> String:
	_close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		peer = null
		return "Couldn't start connecting"
	multiplayer.multiplayer_peer = peer
	hosting = false
	status = "Connecting to %s..." % ip
	# the host's world takes over: our own zombies and scavs go
	for n in get_tree().get_nodes_in_group("npcs") + get_tree().get_nodes_in_group("corpses"):
		if n.has_method("free_body"): n.free_body()
	changed.emit()
	return status

func leave() -> void:
	_close()
	status = "Offline"
	changed.emit()

func _close() -> void:
	for id in players.keys():
		_drop_player(id)
	for id in npcs.keys():
		var n = npcs[id]
		if is_instance_valid(n) and n.get("puppet"): n.free_body()
	npcs.clear()
	_npc_ids.clear()
	if peer:
		peer.close()
	peer = null
	hosting = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

static func lan_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.split(".").size() == 4 and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			out.append(a)
	return out if out.size() else ["this computer"]

# ---------------------------------------------------------------- finding games on the LAN
func listen_for_games(on: bool) -> void:
	if on and _udp == null:
		_udp = PacketPeerUDP.new()
		if _udp.bind(BEACON_PORT) != OK:
			_udp = null
	elif not on and _udp:
		_udp.close()
		_udp = null

func _beacon() -> void:
	var u := PacketPeerUDP.new()
	u.set_broadcast_enabled(true)
	u.set_dest_address("255.255.255.255", BEACON_PORT)
	u.put_packet(("WASTELAND|%s|%s|%d" % [my_name.replace("|", " "), Boot.version, players.size() + 1]).to_utf8_buffer())
	u.close()

# ---------------------------------------------------------------- per frame
func _process(dt: float) -> void:
	if _udp:
		while _udp.get_available_packet_count() > 0:
			var msg := _udp.get_packet().get_string_from_utf8().split("|")
			var ip := _udp.get_packet_ip()
			if msg.size() >= 4 and msg[0] == "WASTELAND":
				var fresh := not found.has(ip)
				found[ip] = {"name": msg[1], "version": msg[2], "players": int(msg[3]), "t": Time.get_ticks_msec()}
				if fresh: changed.emit()
		for ip in found.keys():
			if Time.get_ticks_msec() - int(found[ip].t) > 5000:
				found.erase(ip)
				changed.emit()
	if not online():
		return
	if hosting:
		_beacon_t -= dt
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			_beacon()
	_send_t -= dt
	if _send_t <= 0.0:
		_send_t = 0.05
		_send_me()
	if hosting:
		_world_t -= dt
		if _world_t <= 0.0:
			_world_t = 0.1
			_send_world()
		_env_t -= dt
		if _env_t <= 0.0 and SkyCycle.inst:
			_env_t = 5.0
			rpc("env_state", SkyCycle.inst.state())

# ---------------------------------------------------------------- players
func _on_peer_connected(id: int) -> void:
	print("NET peer connected ", id)          # they introduce themselves (hello) before anything is made for them

func _on_peer_disconnected(id: int) -> void:
	_drop_player(id)
	changed.emit()

@rpc("any_peer", "reliable")
func hello(pname: String, version: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if hosting and version != Boot.version:
		rpc_id(id, "refused", "The host is on v%s and you're on v%s: update first" % [Boot.version, version])
		get_tree().create_timer(0.5).timeout.connect(func(): if peer: peer.disconnect_peer(id))
		return
	names[id] = pname
	_ensure_player(id)
	if hosting:
		# tell the newcomer who's here, and everyone else about the newcomer
		rpc_id(id, "hello", my_name, Boot.version)
		for other in names:
			if other != id: rpc_id(id, "introduce", other, names[other])
		for other in names:
			if other != id: rpc_id(other, "introduce", id, pname)
	changed.emit()

@rpc("authority", "reliable")
func introduce(id: int, pname: String) -> void:
	if id == multiplayer.get_unique_id():
		return
	names[id] = pname
	_ensure_player(id)
	changed.emit()

@rpc("authority", "reliable")
func refused(why: String) -> void:
	status = why
	changed.emit()

func _ensure_player(id: int) -> RemotePlayer:
	if players.has(id) and is_instance_valid(players[id]):
		return players[id]
	var rp := RemotePlayer.new()
	rp.peer_id = id
	rp.display_name = names.get(id, "Player %d" % id)
	rp.body_key = BODIES[id % BODIES.size()]
	rp.net = self
	main.add_child(rp)
	rp.global_position = main.player.global_position + Vector3(2, 0, 2)
	players[id] = rp
	return rp

func _drop_player(id: int) -> void:
	if players.has(id) and is_instance_valid(players[id]):
		players[id].release_car()
		players[id].queue_free()
	players.erase(id)
	names.erase(id)

## Everyone who's playing, here and over the network (the zombies pick the nearest)
func all_players() -> Array:
	var out := [main.player]
	for id in players:
		if is_instance_valid(players[id]): out.append(players[id])
	return out

func _send_me() -> void:
	var p: Player = main.player
	var g: Gun = p.gun()
	var car_info := []
	if p.vehicle:
		var c: Car = p.vehicle
		car_info = [str(c.name), c.home_pos if "home_pos" in c else c.global_position, c.global_transform, c.linear_velocity, c.angular_velocity,
			c.steer_now, c.rpm, c.throttle, c.design]
	rpc("player_state", p.global_position, p.body_yaw, p.yaw, p.pitch, p.crouching, p.dead, p.velocity,
		g.key if (g and p.armed()) else "", p.ads, car_info, p.hp)

@rpc("any_peer", "unreliable_ordered")
func player_state(pos: Vector3, body_yaw: float, yaw: float, pitch: float, crouch: bool, is_dead: bool, vel: Vector3,
		gun_key: String, ads: float, car_info: Array, hp: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not names.has(id):
		return
	var rp := _ensure_player(id)
	rp.apply_state(pos, body_yaw, yaw, pitch, crouch, is_dead, vel, gun_key, ads, car_info, hp)

## A shot went off: the others hear it and see the flash
func shot(origin: Vector3, dir: Vector3, gun_key: String) -> void:
	if online():
		rpc("shot_fx", origin, dir, gun_key)

@rpc("any_peer", "unreliable")
func shot_fx(origin: Vector3, dir: Vector3, gun_key: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) and is_instance_valid(players[id]):
		players[id].show_shot(origin, dir, gun_key)

## You shot another player: their machine takes the damage
func hit_player(rp: RemotePlayer, total: float, dir: Vector3, point: Vector3) -> void:
	rpc_id(rp.peer_id, "you_were_hit", total, dir, point)

@rpc("any_peer", "reliable")
func you_were_hit(total: float, dir: Vector3, point: Vector3) -> void:
	var p: Player = main.player
	if p and not p.dead:
		p.take_damage(total, point - dir * 5.0, dir * total * 0.3, point)

## A zombie (on the host) bit a remote player
func npc_hurt_player(rp: RemotePlayer, amount: float, from: Vector3) -> void:
	rpc_id(rp.peer_id, "you_were_bitten", amount, from)

@rpc("authority", "reliable")
func you_were_bitten(amount: float, from: Vector3) -> void:
	if main.player and not main.player.dead:
		main.player.take_damage(amount, from)

# ---------------------------------------------------------------- the world (zombies and scavs)
func _register(n) -> int:
	if _npc_ids.has(n):
		return _npc_ids[n]
	var id := _next_id
	_next_id += 1
	_npc_ids[n] = id
	npcs[id] = n
	return id

## Host: a new NPC appeared (the director or a camp made it)
func npc_spawned(n) -> void:
	if hosting and online():
		_register(n)

func _send_world() -> void:
	var ids := PackedInt32Array()
	var data := PackedFloat32Array()
	var meta := []
	for n in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(n) or n.dead or n.get("puppet"):
			continue
		var id := _register(n)
		ids.append(id)
		var v: Vector3 = n.velocity
		data.append_array([n.global_position.x, n.global_position.y, n.global_position.z, atan2(n.face_dir.x, n.face_dir.z), v.x, v.z,
			1.0 if n.rig.action != "" else 0.0])
		meta.append([n.kind, n.model_key, n.anim_set, n.rig.action, n.gun.key if n.gun else ""])
	# forget the ones that are gone
	for id in npcs.keys():
		if not is_instance_valid(npcs[id]):
			npcs.erase(id)
	rpc("world_state", ids, data, meta)

var _env_t := 0.0

## The host's clock and weather
@rpc("authority", "reliable")
func env_state(st: Array) -> void:
	if SkyCycle.inst: SkyCycle.inst.take_state(st)

@rpc("authority", "unreliable_ordered")
func world_state(ids: PackedInt32Array, data: PackedFloat32Array, meta: Array) -> void:
	var seen := {}
	for i in ids.size():
		var id := ids[i]
		seen[id] = true
		var n = npcs.get(id)
		if n == null or not is_instance_valid(n):
			n = NPC.new()
			n.kind = meta[i][0]
			n.model_key = meta[i][1]
			n.puppet = true
			n.net_id = id
			n.puppet_gun = meta[i][4]
			main.add_child(n)
			n.global_position = Vector3(data[i * 7], data[i * 7 + 1], data[i * 7 + 2])
			n.anim_set = meta[i][2]
			npcs[id] = n
		if n.dead:
			continue
		n.net_target(Vector3(data[i * 7], data[i * 7 + 1], data[i * 7 + 2]), data[i * 7 + 3], Vector3(data[i * 7 + 4], 0, data[i * 7 + 5]), meta[i][3])
	# puppets the host no longer sends (gone out of range there) go quietly
	for id in npcs.keys():
		var n = npcs[id]
		if not seen.has(id) and is_instance_valid(n) and not n.dead:
			n.free_body()
			npcs.erase(id)

## Client: you shot a puppet; the host does the damage
func hit_npc(n, parts: Dictionary, dir: Vector3, point: Vector3, force: float) -> void:
	rpc_id(1, "npc_hit", int(n.net_id), parts, dir, point, force)

@rpc("any_peer", "reliable")
func npc_hit(id: int, parts: Dictionary, dir: Vector3, point: Vector3, force: float) -> void:
	if not hosting:
		return
	var n = npcs.get(id)
	if n and is_instance_valid(n) and not n.dead:
		var who = players.get(multiplayer.get_remote_sender_id())
		n.take_hit(parts, dir, point, force, who)
		if OS.get_environment("NET_DEBUG") != "": print("NET npc ", id, " hit by ", multiplayer.get_remote_sender_id(), " dead=", n.dead)

## Host: one died; everyone drops their copy the same way
func npc_died(n, impulse: Vector3, point: Vector3, part: String, cuts: Array) -> void:
	if hosting and online() and _npc_ids.has(n):
		rpc("npc_die", int(_npc_ids[n]), impulse, point, part, cuts)

@rpc("authority", "reliable")
func npc_die(id: int, impulse: Vector3, point: Vector3, part: String, cuts: Array) -> void:
	var n = npcs.get(id)
	if n and is_instance_valid(n) and not n.dead:
		n.die(impulse, point, part, cuts)
		if OS.get_environment("NET_DEBUG") != "": print("NET puppet ", id, " died, ragdoll=", n.ragdoll != null)
	npcs.erase(id)

## Host: a zombie's swing or a scav's shot (the clients see it)
func npc_act(n, clip: String) -> void:
	pass          # the action clip rides along in the snapshot
