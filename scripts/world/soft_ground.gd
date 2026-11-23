class_name SoftGround
extends StaticBody3D
## Ground that gives (0.2.72): a strip of mud or sand that tyres sink into and leave ruts in.
##   Sand: how far a tyre sinks is down to its contact pressure, which is about its inflation pressure plus the
##         carcass: a road tyre at 32 psi sinks a long way in soft sand and digs itself in if it spins, till the axle
##         bottoms out; aired down to 12-15 psi it floats. Packed sand gives a little; wet sand by the water is firm.
##   Mud:  sinks to the hard pan whatever the pressure; what counts is the tread (mud terrains bite, road tyres skate)
##         and how tall the tyre is (the axle has to stay clear of it).
## The surface is a 10 cm depth grid: tyres press it down (never up), spinning ones dig, the sides heap up a little.
## The collision is the untouched surface (1 m heightmap): a bellied-out car sits on it. Car reads the ruts through
## depth_at() and asks press() each physics step.

const CELL := 0.1
const TYPES := {
	# eq: sink per kPa over p0 (m), p0: what it carries without giving, max: the hard pan (m), dig: m per m of wheelspin,
	# mu: grip (mud: road tyre .. mud terrain), crr: rolling drag on the flat, bull: drag per (sink / radius)
	"mud": {"name": "MUD", "col": Color(0.36, 0.27, 0.18), "rough": 0.32, "eq": 0.00012, "p0": 0.0, "base": 0.08, "max": 0.2, "dig": 0.008, "mu": [0.3, 0.6], "slide": 0.72, "crr": 0.04, "bull": 0.3, "spray": Color(0.2, 0.14, 0.08)},
	"soft_sand": {"name": "SOFT SAND", "col": Color(0.88, 0.72, 0.48), "rough": 0.95, "eq": 0.0011, "p0": 70.0, "base": 0.0, "max": 0.55, "dig": 0.006, "mu": [0.55, 0.6], "slide": 0.7, "crr": 0.04, "bull": 0.6, "spray": Color(0.85, 0.76, 0.58)},
	"packed_sand": {"name": "PACKED SAND", "col": Color(0.78, 0.63, 0.43), "rough": 0.9, "eq": 0.0003, "p0": 90.0, "base": 0.0, "max": 0.12, "dig": 0.004, "mu": [0.65, 0.68], "slide": 0.72, "crr": 0.03, "bull": 0.9, "spray": Color(0.76, 0.66, 0.5)},
	"wet_sand": {"name": "WET SAND", "col": Color(0.55, 0.44, 0.3), "rough": 0.45, "eq": 0.0001, "p0": 120.0, "base": 0.0, "max": 0.04, "dig": 0.002, "mu": [0.75, 0.75], "slide": 0.75, "crr": 0.02, "bull": 0.9, "spray": Color(0.5, 0.42, 0.31)},
}

var kind := "mud"
var length := 100.0
var width := 5.0
var nx := 0
var nz := 0
var base := PackedFloat32Array()      # surface height (local y) per cell corner, untouched
var cap := PackedFloat32Array()       # 0.2.73: how deep each column can go (a raised bed: never down past the grass)
var ground := PackedFloat32Array()    # the terrain under each column's middle
var depth := PackedFloat32Array()     # how far it's been pressed down (negative: heaped up)
var _img: Image
var _tex: ImageTexture
var _dirty := false
var _t := 0.0
var mi: MeshInstance3D

## The test strips by Thornbill Drive, Murwillumbah (a paddock north of the industrial estate): mud and three sands,
## 100 m each, side by side
const TEST_AT := Vector3(1730.0, 0.0, 1846.0)
static func test_strips(main: Node) -> void:
	var kinds := ["mud", "soft_sand", "packed_sand", "wet_sand"]
	for i in kinds.size():
		var z := TEST_AT.z + float(i) * 8.0
		# grass and trees keep off (the blocker only reaches 14 m from its centre: one per 20 m)
		for k in 6:
			Buildings.add_blocker(TEST_AT.x + 10.0 + float(k) * 18.0, z + 2.5, 0.0, 20.0, 7.5)
		var sg := SoftGround.new()
		sg.kind = kinds[i]
		sg.name = "SoftGround_" + kinds[i]
		main.add_child(sg)
		sg.global_position = Vector3(TEST_AT.x, 0.0, z)
		sg.build(main)

func build(main: Node) -> void:
	nx = int(length / CELL) + 1
	nz = int(width / CELL) + 1
	base.resize(nx * nz)
	depth.resize(nx * nz)
	# the ground under it, every metre, then filled in between (the terrain's 5 m triangles are straight between)
	var mx := int(length) + 1
	var mz := int(width) + 1
	# 0.2.73: a raised bed as deep as the ground goes soft (the ruts used to dig below the terrain and show the grass
	# through), ramped up over 6 m at each end so you drive on and off
	var bed := float(TYPES[kind].max) + 0.06
	var raise_at := func(fx: float) -> float: return bed * clampf(minf(fx, length - fx) / 6.0, 0.0, 1.0)
	var coarse := PackedFloat32Array(); coarse.resize(mx * mz)
	var terr := PackedFloat32Array(); terr.resize(mx * mz)
	for j in mz:
		for i in mx:
			var th := float(main.height_at(global_position.x + float(i), global_position.z + float(j)))
			terr[j * mx + i] = th
			coarse[j * mx + i] = th + 0.04 + float(raise_at.call(float(i)))
	cap.resize(nx)
	ground.resize(nx)
	for i in nx: cap[i] = float(raise_at.call(float(i) * CELL)) + 0.03
	for j in nz:
		for i in nx:
			var fx := float(i) * CELL; var fz := float(j) * CELL
			var i0 := mini(int(fx), mx - 2); var j0 := mini(int(fz), mz - 2)
			var tx := fx - float(i0); var tz := fz - float(j0)
			var h := lerpf(lerpf(coarse[j0 * mx + i0], coarse[j0 * mx + i0 + 1], tx), lerpf(coarse[(j0 + 1) * mx + i0], coarse[(j0 + 1) * mx + i0 + 1], tx), tz)
			base[j * nx + i] = h
			if j == nz / 2: ground[i] = lerpf(lerpf(terr[j0 * mx + i0], terr[j0 * mx + i0 + 1], tx), lerpf(terr[(j0 + 1) * mx + i0], terr[(j0 + 1) * mx + i0 + 1], tx), tz)
			# mud starts pocked and wet, sand a little rippled
			var n := sin(float(i) * 0.37 + float(j) * 0.9) * 0.5 + sin(float(i) * 0.11 - float(j) * 0.23) * 0.5
			depth[j * nx + i] = n * (0.03 if kind == "mud" else 0.008)
	# collision: the untouched surface, a metre a cell
	var hs := HeightMapShape3D.new()
	hs.map_width = mx
	hs.map_depth = mz
	hs.map_data = coarse
	var cs := CollisionShape3D.new()
	cs.shape = hs
	cs.position = Vector3(float(mx - 1) * 0.5, 0.0, float(mz - 1) * 0.5)
	add_child(cs)
	set_meta("soft_ground", self)
	_build_mesh()

func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			st.set_uv(Vector2((float(i) + 0.5) / float(nx), (float(j) + 0.5) / float(nz)))
			st.set_uv2(Vector2(float(i) * CELL, float(j) * CELL))
			st.add_vertex(Vector3(float(i) * CELL, base[j * nx + i], float(j) * CELL))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + nx)
			st.add_index(a + 1); st.add_index(a + nx + 1); st.add_index(a + nx)
	var am := st.commit()
	am.custom_aabb = AABB(Vector3(0, -1, 0), Vector3(length, 60, width))
	_img = Image.create_from_data(nx, nz, false, Image.FORMAT_RF, depth.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)
	mi = MeshInstance3D.new()
	mi.mesh = am
	var m := ShaderMaterial.new()
	m.shader = _shader()
	var t: Dictionary = TYPES[kind]
	m.set_shader_parameter("depth_tex", _tex)
	m.set_shader_parameter("col", t.col)
	m.set_shader_parameter("rough", float(t.rough))
	m.set_shader_parameter("texel", Vector2(1.0 / float(nx), 1.0 / float(nz)))
	m.set_shader_parameter("cell", CELL)
	m.set_shader_parameter("wet", 1.0 if kind == "mud" else (0.6 if kind == "wet_sand" else 0.0))
	var nt := NoiseTexture2D.new(); nt.width = 256; nt.height = 256; nt.seamless = true
	var fn := FastNoiseLite.new(); fn.frequency = 0.08; nt.noise = fn
	m.set_shader_parameter("grain", nt)
	mi.material_override = m
	mi.visibility_range_end = 400.0
	add_child(mi)
	# the bed's sides, down into the ground
	var sk := SurfaceTool.new()
	sk.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zz in [0.0, width]:
		var j := 0 if zz == 0.0 else nz - 1
		var nrm := Vector3(0, 0, -1) if zz == 0.0 else Vector3(0, 0, 1)
		for i in nx - 1:
			var a0 := Vector3(float(i) * CELL, base[j * nx + i], zz); var a1 := Vector3(float(i + 1) * CELL, base[j * nx + i + 1], zz)
			var b0 := Vector3(a0.x, ground[i] - 0.15, zz); var b1 := Vector3(a1.x, ground[i + 1] - 0.15, zz)
			sk.set_normal(nrm)
			for v in [a0, b0, a1, a1, b0, b1]: sk.add_vertex(v)
	var skm := StandardMaterial3D.new()
	skm.albedo_color = (t.col as Color).darkened(0.25)
	skm.roughness = 0.95
	skm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var smi := MeshInstance3D.new()
	smi.mesh = sk.commit()
	smi.material_override = skm
	smi.visibility_range_end = 400.0
	add_child(smi)
	# a sign at the start of the strip
	var lb := Label3D.new()
	lb.text = str(t.name)
	lb.font_size = 96
	lb.pixel_size = 0.01
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position = Vector3(-2.0, base[(nz / 2) * nx] + 1.6, width * 0.5)
	lb.modulate = Color(1, 1, 0.85)
	lb.outline_size = 12
	add_child(lb)

static var _sh: Shader
static func _shader() -> Shader:
	if _sh: return _sh
	_sh = Shader.new()
	_sh.code = """
shader_type spatial;
uniform sampler2D depth_tex : filter_linear;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform vec4 col : source_color;
uniform float rough = 0.9;
uniform float wet = 0.0;
uniform vec2 texel;
uniform float cell = 0.1;
varying float dep;
void vertex() {
	float d = texture(depth_tex, UV).r;
	dep = d;
	VERTEX.y -= d;
	float dx = texture(depth_tex, UV + vec2(texel.x, 0.0)).r - texture(depth_tex, UV - vec2(texel.x, 0.0)).r;
	float dz = texture(depth_tex, UV + vec2(0.0, texel.y)).r - texture(depth_tex, UV - vec2(0.0, texel.y)).r;
	NORMAL = normalize(NORMAL + vec3(dx, 0.0, dz) / (2.0 * cell));
}
void fragment() {
	float g = texture(grain, UV2 * 0.35).r;
	float g2 = texture(grain, UV2 * 2.7).r;
	vec3 c = col.rgb * (0.82 + 0.3 * g) * (0.9 + 0.2 * g2);
	// pressed down: darker and (mud) wetter in the ruts
	float rut = clamp(dep * 6.0, 0.0, 1.0);
	c *= 1.0 - rut * (0.25 + 0.25 * wet);
	ALBEDO = c;
	ROUGHNESS = mix(rough, 0.12, rut * wet);
	SPECULAR = 0.5;
}
"""
	return _sh

func _process(dt: float) -> void:
	if not _dirty: return
	_t -= dt
	if _t > 0.0: return
	_t = 0.08
	_dirty = false
	_img.set_data(nx, nz, false, Image.FORMAT_RF, depth.to_byte_array())
	_tex.update(_img)

func _cell(p: Vector3) -> Vector2i:
	var l := to_local(p)
	return Vector2i(roundi(l.x / CELL), roundi(l.z / CELL))

## How far the ground's been pressed down here (m)
func depth_at(p: Vector3) -> float:
	var c := _cell(p)
	if c.x < 0 or c.y < 0 or c.x >= nx or c.y >= nz: return 0.0
	return maxf(depth[c.y * nx + c.x], 0.0)

## The grip, slide and rolling drag this ground gives a tyre ([mu, slide, crr, kind])
func surface(tread: float, sink: float, r: float) -> Array:
	var t: Dictionary = TYPES[kind]
	var mu := lerpf(float(t.mu[0]), float(t.mu[1]), clampf(tread, 0.0, 1.0))
	var crr := float(t.crr) + float(t.bull) * sink / maxf(r, 0.2)
	return [mu, float(t.slide), crr, "mud" if kind == "mud" else "sand"]

## A tyre pressing on it: N load (N), psi, r radius, b width, slip speed (m/s), dt. Presses the ground down to where
## this tyre settles (and deeper while it spins) and returns how deep it now is under the tyre.
func press(p: Vector3, N: float, psi: float, r: float, b: float, slip: float, dt: float) -> float:
	var c := _cell(p)
	if c.x < 0 or c.y < 0 or c.x >= nx or c.y >= nz: return 0.0
	var t: Dictionary = TYPES[kind]
	# contact pressure ~ inflation pressure plus what the carcass carries (kPa); a heavier wheel loads a bigger patch,
	# which reaches deeper
	var p_kpa := psi * 6.895 + 30.0
	var load := pow(clampf(N / 3000.0, 0.2, 4.0), 0.3)
	var eq := (float(t.base) + float(t.eq) * maxf(p_kpa - float(t.p0), 0.0)) * load
	var hard := float(t.max)
	eq = minf(eq, hard)
	var here := depth[c.y * nx + c.x]
	var want := maxf(here, eq)
	# wheelspin digs (the tyre throws it out behind)
	want += float(t.dig) * absf(slip) * dt * clampf(N / 3000.0, 0.3, 2.0)
	want = minf(want, hard + 0.05)
	want = minf(want, cap[c.x])                  # never through the bottom of the bed
	var hw := maxi(1, roundi(b * 0.5 / CELL))
	for dj in range(-hw, hw + 1):
		var j := c.y + dj
		if j < 0 or j >= nz: continue
		for di in range(-1, 2):
			var i := c.x + di
			if i < 0 or i >= nx: continue
			var k := j * nx + i
			if depth[k] < want: depth[k] = lerpf(depth[k], want, 0.6 if di == 0 else 0.35)
		# the edges heap up a little
	for side in [-hw - 1, hw + 1]:
		var j2: int = c.y + side
		if j2 >= 0 and j2 < nz:
			var k2 := j2 * nx + c.x
			depth[k2] = minf(depth[k2], -want * 0.18)
	_dirty = true
	return maxf(depth[c.y * nx + c.x], 0.0)
