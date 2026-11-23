class_name Prof
extends RefCounted
## 0.2.51: what a slow frame was spent on. The big per-frame jobs (building and road streaming, plants, NPCs, the
## sky...) are timed; when a frame takes over 33 ms the jobs that ran in it are kept (the last 24 such frames), and
## the slowest time each job has ever taken. F9 reports carry both ("spikes", "slowest"), so a stutter on the
## player's PC says where it came from.
static var cur := {}
static var worst := {}
static var spikes: Array = []
static var _last := 0
static var totals := {}         # 0.2.68: every job's time since start (the perf probe reads it)

static func t() -> int:
	return Time.get_ticks_usec()

static func add(job: String, t0: int) -> void:
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	cur[job] = float(cur.get(job, 0.0)) + ms
	totals[job] = float(totals.get(job, 0.0)) + ms
	if ms > float(worst.get(job, 0.0)): worst[job] = snappedf(ms, 0.1)

## once a frame, first thing (main)
static func frame() -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0 if _last > 0 else 0.0
	_last = now
	if ms > 33.0:
		var top := []
		for k in cur: top.append([k, snappedf(float(cur[k]), 0.1)])
		top.sort_custom(func(a, b): return a[1] > b[1])
		spikes.append({"ms": snappedf(ms, 0.1), "t": snappedf(now / 1e6, 0.1), "jobs": top.slice(0, 5)})
		if spikes.size() > 24: spikes.pop_front()
	cur.clear()
