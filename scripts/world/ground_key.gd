class_name GroundKey
extends Node3D
## The ground painted from the real thing (0.2.53 pilot: 1 km round Murwillumbah's main street).
## tools/sat_fetch.py + tools/sat_key.py read the NSW government imagery into a key: what every quarter metre of
## ground is (road asphalt, worn asphalt, concrete, pavers, lawn, dirt, gravel, or "leave the terrain": trees,
## water, the bush), the painted lines as a distance field at an eighth of a metre, and the kerbs and islands as
## lines. The photo itself is never shown: the terrain's shader paints our own textures (bump, roughness and all)
## where the key says, and the lines stay sharp right to your feet. Kerbs and islands are real geometry you can hit.
## Inside the key, the old painted roads (Roads' overlay) step aside.
static var inst: GroundKey = null
const LAYERS := [
	["res://assets/ground/rough_grass", 3.0],          # 0 (not drawn: the terrain's own)
	["res://assets/ground/key/asphalt_02", 4.0],       # 1 road
	["res://assets/ground/key/asphalt_04", 4.0],       # 2 car parks, lanes, drives
	["res://assets/ground/key/concrete_pavement", 3.0],# 3 footpaths, slabs
	["res://assets/ground/key/brick_pavement_02", 2.2],# 4 pavers
	["res://assets/ground/rough_grass", 2.5],          # 5 lawn
	["res://assets/ground/farm_soil", 4.0],            # 6 dirt
	["res://assets/ground/key/gravel_road", 3.0],      # 7 gravel
	["res://assets/ground/key/asphalt_02", 4.0],       # 8 (spare)
	["res://assets/ground/key/asphalt_02", 4.0],       # 9 road with yellow paint
]
const KERB_R := 320.0          # kerbs built this close
const KERB_DROP := 420.0
const TILE := 128.0
var main
var meta: Dictionary = {}
var cls := PackedByteArray()
var n := 0
var _tiles := {}               # Vector2i -> {"segs": [[a, b, na, nb]], "isl": [...], "node": Node3D}
var _t := 0.0
var _kmat: StandardMaterial3D
var _fill := {}

static func hard(x: float, z: float) -> bool:
	## paved or gravelled here (no grass, no plants)
	if inst == null or inst.n == 0: return false
	var c := inst.at(x, z)
	return c == 1 or c == 2 or c == 3 or c == 4 or c == 7 or c == 9

func at(x: float, z: float) -> int:
	var i := int((x - float(meta.x0)) / float(meta.class_res))
	var j := int((z - float(meta.z0)) / float(meta.class_res))
	if i < 0 or j < 0 or i >= n or j >= n: return -1
	return cls[j * n + i]

func setup(m, name := "pilot") -> void:
	main = m
	var base := "res://assets/world/ground_key/" + name
	if not FileAccess.file_exists(base + ".json"): return
	meta = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	n = int(meta.class_n)
	cls = FileAccess.get_file_as_bytes(base + "_class.bin.gz").decompress(n * n, FileAccess.COMPRESSION_GZIP)
	if cls.size() != n * n:
		push_warning("ground key: class map didn't load")
		n = 0
		return
	var nm := int(meta.marks_n)
	var mk := FileAccess.get_file_as_bytes(base + "_marks.bin.gz").decompress(nm * nm, FileAccess.COMPRESSION_GZIP)
	var cimg := Image.create_from_data(n, n, false, Image.FORMAT_R8, cls)
	var mimg := Image.create_from_data(nm, nm, false, Image.FORMAT_R8, mk)
	mimg.generate_mipmaps()
	inst = self
	_shader(ImageTexture.create_from_image(cimg), ImageTexture.create_from_image(mimg))
	_load_kerbs(base + "_kerbs.json")
	print("GROUND KEY %s: %d x %d m, %d kerb tiles" % [name, int(float(meta.x1) - float(meta.x0)), int(float(meta.z1) - float(meta.z0)), _tiles.size()])

func _layer_images(suffix: String) -> Array:
	var imgs := []
	for L in LAYERS:
		var t: Texture2D = load(str(L[0]) + suffix)
		var im: Image = t.get_image() if t else Image.create(1024, 1024, true, Image.FORMAT_RGBA8)
		imgs.append(im)
	# one format for all: if any differ, everything uncompressed with mipmaps
	var f: int = imgs[0].get_format()
	var same := true
	for im: Image in imgs:
		if im.get_format() != f or im.get_width() != imgs[0].get_width() or not im.has_mipmaps(): same = false
	if not same:
		for k in imgs.size():
			var im: Image = imgs[k].duplicate()
			if im.is_compressed(): im.decompress()
			im.convert(Image.FORMAT_RGBA8)
			if im.get_width() != 1024: im.resize(1024, 1024)
			im.generate_mipmaps()
			imgs[k] = im
	return imgs

func _shader(ctex: Texture2D, mtex: Texture2D) -> void:
	var tm: Terrain3DMaterial = main.terrain.material
	var tsh: Shader = tm.shader_override
	if tsh == null: return
	var tc := tsh.code
	if not tc.contains("gk_class"):
		var funcs := """
uniform sampler2D gk_class : filter_nearest, repeat_disable;
uniform sampler2D gk_marks : filter_linear_mipmap, repeat_disable;
uniform sampler2DArray gk_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray gk_nrm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 gk_rect = vec4(0.0, 0.0, -1.0, -1.0);
uniform float gk_n = 4000.0;
uniform float gk_tile[10];
uniform vec3 gk_white : source_color = vec3(0.86, 0.86, 0.82);
uniform vec3 gk_yellow : source_color = vec3(0.86, 0.67, 0.12);
float gk_h1(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float gk_vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(gk_h1(i), gk_h1(i + vec2(1.0, 0.0)), f.x), mix(gk_h1(i + vec2(0.0, 1.0)), gk_h1(i + vec2(1.0)), f.x), f.y);
}
"""
		var body := """
	// the ground key (GroundKey): our own surfaces where the imagery says, sharp painted lines
	float gk_in = 0.0;
	vec2 gk_uv = (v_vertex.xz - gk_rect.xy) / gk_rect.zw;
	if (gk_rect.z > 0.0 && gk_uv.x > 0.0 && gk_uv.y > 0.0 && gk_uv.x < 1.0 && gk_uv.y < 1.0) {
		vec2 gk_e = min(gk_uv, vec2(1.0) - gk_uv) * gk_rect.zw;
		gk_in = clamp(min(gk_e.x, gk_e.y) / 15.0, 0.0, 1.0);
		// look the key up a little off where you are (up to ~0.3 m, smoothly), so its quarter-metre grid never shows
		vec2 gk_q = v_vertex.xz;
		vec2 gk_wp = (vec2(gk_vn(gk_q * 0.9), gk_vn(gk_q * 0.9 + 17.3)) - 0.5) * 0.55 + (vec2(gk_vn(gk_q * 3.7 + 5.1), gk_vn(gk_q * 3.7 - 9.7)) - 0.5) * 0.22;
		vec2 gk_tp = (gk_uv + gk_wp / gk_rect.zw) * gk_n - 0.5;
		vec2 gk_f = fract(gk_tp);
		ivec2 gk_b = ivec2(floor(gk_tp));
		// four texels, each its own material; blended by the bilinear weight plus the material's own height, so
		// the edges between them break up like real ones (no quarter-metre stair steps)
		vec3 ta4[4]; vec3 tn4[4]; float tr4[4]; float hb[4]; bool own4[4];
		float gk_y = 0.0; float hm = -9.0;
		for (int k = 0; k < 4; k++) {
			ivec2 o = ivec2(k & 1, k >> 1);
			float w = (o.x == 1 ? gk_f.x : 1.0 - gk_f.x) * (o.y == 1 ? gk_f.y : 1.0 - gk_f.y);
			int c = int(texelFetch(gk_class, clamp(gk_b + o, ivec2(0), ivec2(int(gk_n) - 1)), 0).r * 255.0 + 0.5);
			if (c == 9) gk_y += w;
			own4[k] = c > 0 && c <= 9 && c != 5;          // lawn: the terrain's own grass (and its blades)
			float h = 0.5;
			if (own4[k]) {
				vec2 tuv = v_vertex.xz / gk_tile[c];
				vec4 ta = texture(gk_alb, vec3(tuv, float(c)));
				vec4 tn = texture(gk_nrm, vec3(tuv, float(c)));
				ta4[k] = ta.rgb; tn4[k] = tn.rgb; tr4[k] = tn.a; h = ta.a;
			} else {
				ta4[k] = ALBEDO; tn4[k] = NORMAL_MAP; tr4[k] = ROUGHNESS;
			}
			hb[k] = w + h * 0.45;
			hm = max(hm, hb[k]);
		}
		vec3 gk_a = vec3(0.0); vec3 gk_nm = vec3(0.0); float gk_r = 0.0; float gk_own = 0.0; float gk_tot = 0.0;
		for (int k = 0; k < 4; k++) {
			float b = max(hb[k] - hm + 0.18, 0.0);
			gk_tot += b;
			if (own4[k]) { gk_a += ta4[k] * b; gk_nm += tn4[k] * b; gk_r += tr4[k] * b; gk_own += b; }
		}
		if (gk_own > 0.0001) {
			float k2 = gk_own / max(gk_tot, 0.0001) * gk_in;
			ALBEDO = mix(ALBEDO, gk_a / gk_own, k2);
			NORMAL_MAP = mix(NORMAL_MAP, gk_nm / gk_own, k2);
			ROUGHNESS = mix(ROUGHNESS, gk_r / gk_own, k2);
			SPECULAR = mix(SPECULAR, 0.4, k2);
			AO = mix(AO, 1.0, k2);
		}
		float gk_sd = textureLod(gk_marks, gk_uv, 0.0).r;
		float gk_fw = max(fwidth(gk_sd) * 0.75, 0.004);
		float gk_p = smoothstep(0.5 - gk_fw, 0.5 + gk_fw, gk_sd) * gk_in;
		// worn through where the tyres run: a little grain in the paint
		gk_p *= 0.82 + 0.18 * texture(gk_nrm, vec3(v_vertex.xz / 1.3, 2.0)).a;
		vec3 gk_pc = mix(gk_white, gk_yellow, step(0.2, gk_y));
		ALBEDO = mix(ALBEDO, gk_pc, gk_p);
		ROUGHNESS = mix(ROUGHNESS, 0.6, gk_p);
		NORMAL_MAP = mix(NORMAL_MAP, vec3(0.5, 0.5, 1.0), gk_p * 0.6);
	}
"""
		var fi := tc.find("void fragment()")
		tc = tc.substr(0, fi) + funcs + tc.substr(fi)
		var hook := "\tvec4 rp = road_paint(v_vertex.xz);"
		var hi := tc.find(hook)
		if hi < 0:
			# no painted roads in this shader: put it after the material's own setup
			var ai := tc.rfind("AO_LIGHT_AFFECT = mat.ao_affect;")
			var nl := tc.find("\n", ai)
			tc = tc.substr(0, nl + 1) + body + tc.substr(nl + 1)
		else:
			tc = tc.substr(0, hi) + body + hook + "\n\trp.a *= (1.0 - gk_in);" + tc.substr(hi + hook.length())
		var nsh := Shader.new()
		nsh.code = tc
		tm.shader_override = nsh
	var x0 := float(meta.x0); var z0 := float(meta.z0)
	tm.set_shader_param("gk_rect", Vector4(x0, z0, float(meta.x1) - x0, float(meta.z1) - z0))
	tm.set_shader_param("gk_n", float(n))
	tm.set_shader_param("gk_class", ctex)
	tm.set_shader_param("gk_marks", mtex)
	var tiles := PackedFloat32Array()
	for L in LAYERS: tiles.append(float(L[1]))
	tm.set_shader_param("gk_tile", tiles)
	var aa := Texture2DArray.new()
	aa.create_from_images(_layer_images("_alb_h.png"))
	var na := Texture2DArray.new()
	na.create_from_images(_layer_images("_nrm_r.png"))
	tm.set_shader_param("gk_alb", aa)
	tm.set_shader_param("gk_nrm", na)

# ------------------------------------------------------------------ kerbs and islands
func _load_kerbs(path: String) -> void:
	if not FileAccess.file_exists(path): return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for line in d.get("kerbs", []):
		var pts := PackedVector2Array()
		for q in line: pts.append(Vector2(float(q[0]), float(q[1])))
		# split long straights so the kerb follows the ground
		var dense := PackedVector2Array()
		for i in pts.size() - 1:
			var a := pts[i]; var b := pts[i + 1]
			var k := maxi(1, ceili(a.distance_to(b) / 2.5))
			for j in k: dense.append(a.lerp(b, float(j) / k))
		dense.append(pts[pts.size() - 1])
		# a normal at each point (towards the footpath, away from the road on the left), averaged at the bends
		var nr := PackedVector2Array()
		for i in dense.size():
			var t := (dense[mini(i + 1, dense.size() - 1)] - dense[maxi(i - 1, 0)]).normalized()
			nr.append(Vector2(t.y, -t.x))          # right of the way along = away from the road
		for i in dense.size() - 1:
			var mid := (dense[i] + dense[i + 1]) * 0.5
			var key := Vector2i(floori(mid.x / TILE), floori(mid.y / TILE))
			if not _tiles.has(key): _tiles[key] = {"segs": [], "isl": [], "node": null}
			_tiles[key].segs.append([dense[i], dense[i + 1], nr[i], nr[i + 1]])
	for isl in d.get("islands", []):
		var poly := PackedVector2Array()
		var c := Vector2.ZERO
		for q in isl.poly:
			poly.append(Vector2(float(q[0]), float(q[1])))
			c += poly[poly.size() - 1]
		c /= maxf(poly.size(), 1)
		var key := Vector2i(floori(c.x / TILE), floori(c.y / TILE))
		if not _tiles.has(key): _tiles[key] = {"segs": [], "isl": [], "node": null}
		_tiles[key].isl.append({"poly": poly, "fill": str(isl.fill)})

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or main == null or main.player == null or _tiles.is_empty(): return
	_t = 0.5
	var me: Vector3 = main.player.vehicle.global_position if is_instance_valid(main.player.vehicle) else main.player.global_position
	if main.forge and main.forge.active: me = main.forge.cam.global_position
	var built := 0
	for key: Vector2i in _tiles:
		var t: Dictionary = _tiles[key]
		var c := Vector2((key.x + 0.5) * TILE, (key.y + 0.5) * TILE)
		var dd := Vector2(me.x, me.z).distance_to(c) - TILE * 0.7
		if t.node == null and dd < KERB_R and built < 3:
			t.node = _build_tile(t)
			add_child(t.node)
			built += 1
		elif t.node != null and dd > KERB_DROP:
			t.node.queue_free()
			t.node = null

func _h(x: float, z: float) -> float:
	return ServoGen._h(main.terrain.data, x, z)

func _mat(alb: String, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(alb + "_alb_h.png")
	m.normal_enabled = true
	m.normal_texture = load(alb + "_nrm_r.png")
	m.roughness_texture = load(alb + "_nrm_r.png")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / scale
	return m

## Australian kerb and gutter: a 0.35 m concrete gutter flush with the road, the kerb face 150 mm up, its top, then
## the back sloping down into the footpath (the ground's own height there)
const PROFILE := [[-0.38, 0.0], [-0.02, -0.025], [0.0, -0.02], [0.04, 0.15], [0.17, 0.155], [0.62, 0.0]]
func _build_tile(t: Dictionary) -> Node3D:
	var root := Node3D.new()
	if _kmat == null:
		_kmat = _mat("res://assets/ground/key/concrete_pavement", 2.0)
		_kmat.albedo_color = Color(0.92, 0.92, 0.9)
		_fill = {"grass": _mat("res://assets/ground/rough_grass", 2.5), "concrete": _kmat, "pavers": _mat("res://assets/ground/key/brick_pavement_02", 2.2)}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for s in t.segs:
		var a: Vector2 = s[0]; var b: Vector2 = s[1]; var na: Vector2 = s[2]; var nb: Vector2 = s[3]
		var ra := []; var rb := []
		for pr in PROFILE:
			var pa: Vector2 = a + na * float(pr[0])
			var pb: Vector2 = b + nb * float(pr[0])
			ra.append(Vector3(pa.x, _h(pa.x, pa.y) + 0.03 + float(pr[1]), pa.y))
			rb.append(Vector3(pb.x, _h(pb.x, pb.y) + 0.03 + float(pr[1]), pb.y))
		for k in PROFILE.size() - 1:
			var q: Array[Vector3] = [ra[k], rb[k], rb[k + 1], ra[k + 1]]
			var nrm: Vector3 = ((q[1] - q[0]).cross(q[3] - q[0])).normalized()
			if nrm.y < 0.0 and k != 2: nrm = -nrm
			for v in [q[0], q[2], q[1], q[0], q[3], q[2]]:
				st.set_normal(nrm)
				st.add_vertex(v)
				faces.append(v)
	for isl in t.isl:
		var poly: PackedVector2Array = isl.poly
		var tri := Geometry2D.triangulate_polygon(poly)
		if tri.is_empty(): continue
		var ist := SurfaceTool.new()
		ist.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hs := []
		for q in poly: hs.append(_h(q.x, q.y) + 0.17)
		for i in range(0, tri.size(), 3):
			for j in [0, 2, 1]:
				var q := poly[tri[i + j]]
				var v := Vector3(q.x, float(hs[tri[i + j]]), q.y)
				ist.set_normal(Vector3.UP)
				ist.add_vertex(v)
				faces.append(v)
		var imi := MeshInstance3D.new()
		imi.mesh = ist.commit()
		imi.material_override = _fill.get(str(isl.fill), _kmat)
		imi.visibility_range_end = KERB_R + 60.0
		root.add_child(imi)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _kmat
	mi.visibility_range_end = KERB_R + 60.0
	root.add_child(mi)
	if faces.size() >= 3:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(faces)
		cs.shape = sh
		body.add_child(cs)
		root.add_child(body)
	return root
