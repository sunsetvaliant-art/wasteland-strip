class_name VehicleSpecs
extends RefCounted
## Engines, gearboxes and the default build for every body. A "design" is a plain Dictionary so the vehicle builder
## can edit it, save it as JSON and rebuild the car from it.

## torque curves are [rpm, Nm] at full throttle (period figures, a bit tired after decades in a paddock)
const ENGINES := {
	"202": {"name": "Holden 202 red six", "glb": "engine_holden_202", "cyl": 6, "sound": "i6_202", "idle": 720, "redline": 4800, "limiter": 5100,
		"curve": [[0, 120], [800, 200], [1600, 238], [2200, 258], [3000, 252], [4000, 228], [4800, 196], [5400, 160]], "inertia": 0.17, "friction": 16.0, "kg": 205, "len": 0.86},
	"22r": {"name": "Toyota 22R", "glb": "engine_toyota_22r", "cyl": 4, "sound": "i4_22r", "idle": 800, "redline": 5000, "limiter": 5400,
		"curve": [[0, 90], [800, 140], [2000, 172], [3200, 186], [4000, 180], [4800, 162], [5600, 135]], "inertia": 0.11, "friction": 12.0, "kg": 160, "len": 0.66},
	"351": {"name": "Ford 351 Cleveland V8", "glb": "engine_ford_351", "cyl": 8, "sound": "v8_351", "idle": 680, "redline": 5400, "limiter": 5800,
		"curve": [[0, 220], [800, 330], [1600, 420], [2600, 474], [3200, 480], [4000, 452], [5000, 395], [5800, 330]], "inertia": 0.24, "friction": 24.0, "kg": 285, "len": 0.74},
	"40": {"name": "Jeep 4.0 six", "glb": "engine_jeep_40", "cyl": 6, "sound": "i6_40", "idle": 700, "redline": 5000, "limiter": 5300,
		"curve": [[0, 170], [800, 250], [1600, 298], [2800, 314], [3600, 300], [4500, 268], [5300, 228]], "inertia": 0.19, "friction": 18.0, "kg": 230, "len": 0.82},
	# made in Meshy; sounds recorded in Engine Simulator from engines built to their specs
	"400": {"name": "Ford 400 V8 ('79 pickup)", "glb": "engine_pickup_v8", "cyl": 8, "sound": "v8_pickup", "idle": 650, "redline": 4400, "limiter": 4800,
		"curve": [[0, 260], [800, 380], [1600, 450], [2200, 465], [3000, 440], [3800, 390], [4600, 320]], "inertia": 0.27, "friction": 24.0, "kg": 300, "len": 0.75},
	"426": {"name": "Chrysler 426 Hemi (with its 4-speed)", "glb": "engine_hemi_426", "cyl": 8, "sound": "v8_hemi", "idle": 850, "redline": 6000, "limiter": 6500,
		"curve": [[0, 260], [1000, 420], [2000, 560], [3000, 630], [4000, 664], [5000, 640], [6000, 575], [6600, 500]], "inertia": 0.28, "friction": 28.0, "kg": 350, "len": 1.0},
	"blown": {"name": "Blown big-block V8 (twin superchargers)", "glb": "engine_blown_v8", "cyl": 8, "sound": "v8_blown", "idle": 1000, "redline": 7000, "limiter": 7400,
		"curve": [[0, 300], [1000, 520], [2000, 760], [3000, 900], [4000, 980], [5000, 990], [6000, 930], [7000, 820], [7600, 700]], "inertia": 0.32, "friction": 34.0, "kg": 380, "len": 0.8},
}
const GEARBOXES := {
	"auto3": {"name": "3-speed auto (Trimatic / C4)", "auto": true, "ratios": [2.45, 1.45, 1.0], "reverse": 2.2, "shift_time": 0.45},
	"man4": {"name": "4-speed manual", "auto": false, "ratios": [3.07, 1.68, 1.19, 1.0], "reverse": 3.2, "shift_time": 0.35},
	"man5": {"name": "5-speed manual", "auto": false, "ratios": [3.97, 2.34, 1.46, 1.0, 0.85], "reverse": 4.0, "shift_time": 0.35},
	"truck4": {"name": "4-speed truck box (granny first)", "auto": false, "ratios": [6.32, 3.09, 1.69, 1.0], "reverse": 7.4, "shift_time": 0.6},
}
const DIFFS := ["open", "lsd", "locked"]

## Coil springs on a short-long-arm front end, cart springs (leaf packs) under a live axle out back. Rates per wheel.
static func default_design(kind: String) -> Dictionary:
	var cat: Dictionary = Car.catalog()
	var d: Dictionary = cat.get(kind, cat["vjwagon"])
	var big: bool = d.cls == "4x4"
	var mn: Array = d.min
	var ext: Array = d.ext
	var heavy: bool = float(d.kg) > 1600.0
	var tyre_r := 0.39 if big else 0.31
	var track: float = float(ext[2]) * 0.5 - (0.2 if big else 0.18)
	var ride: float = float(mn[1]) + (0.24 if big else 0.15)        # wheel centre height under the body at rest
	var eng := "202"
	var n: String = str(d.name).to_lower()
	if big: eng = "40"
	elif n.contains("falcon") or n.contains("fairlane") or n.contains("charger") or n.contains("muscle") or n.contains("chevy"): eng = "351"
	elif n.contains("pickup") or n.contains("hilux") or n.contains("tercel"): eng = "22r"
	var mass := float(d.kg) * 2.3
	var front := {"z": float(d.ax_f), "type": "live" if big else "ifs", "spring": "leaf" if big else "coil", "freq": 1.45 if big else 1.25,
		"travel": 0.26 if big else 0.2, "zeta_b": 0.3, "zeta_r": 0.5, "arb": 0.0 if big else 14000.0, "steer": true,
		"drive": big, "track": track, "tyre_r": tyre_r, "tyre_w": 0.26 if big else 0.19, "brake": 2400.0, "diff": "open"}
	var rear := {"z": float(d.ax_r), "type": "live", "spring": "leaf", "freq": 1.55 if big else 1.4, "travel": 0.26 if big else 0.2,
		"zeta_b": 0.3, "zeta_r": 0.5, "arb": 0.0, "steer": false, "drive": true, "track": track, "tyre_r": tyre_r,
		"tyre_w": 0.26 if big else 0.2, "brake": 1500.0, "diff": "lsd" if eng == "351" else "open"}
	return {
		"cab": kind, "cab_offset": [0.0, 0.0, 0.0], "ride": ride, "mass": mass, "front_share": 0.56,
		"cda": 1.75 if big else 0.95, "engine": eng, "gearbox": "man4" if (big or heavy) else "auto3", "final": 3.9 if big else 3.36,
		"axles": [front, rear],
		"frame": {"len": float(ext[0]) * 0.92, "width": track * 1.2, "z": float(mn[0]) + float(ext[0]) * 0.5},
	}

static func torque(eng: Dictionary, rpm: float) -> float:
	var c: Array = eng.curve
	if rpm <= c[0][0]: return c[0][1]
	for i in range(1, c.size()):
		if rpm <= c[i][0]:
			var t: float = (rpm - c[i - 1][0]) / float(c[i][0] - c[i - 1][0])
			return lerpf(c[i - 1][1], c[i][1], t)
	return c[-1][1]
