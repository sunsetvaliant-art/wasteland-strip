#!/usr/bin/env python3
"""Gunshots, mechanisms, impacts, zombie groans and the scav alarm whistle, synthesised.
Gunshot = supersonic crack (sharp N-wave) + muzzle blast (low, band-limited boom) + a tail that echoes off the hills.
usage: python3 tools/sfx_synth.py -> assets/audio/sfx/*.wav"""
import numpy as np, wave, os
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(5)

def lp(x, fc):
    F = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); F /= (1 + (f / fc) ** 2); return np.fft.irfft(F, len(x))
def hp(x, fc):
    F = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); F *= (f / fc) ** 2 / (1 + (f / fc) ** 2); return np.fft.irfft(F, len(x))
def bp(x, fc, bw):
    F = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); F *= np.exp(-((f - fc) / bw) ** 2); return np.fft.irfft(F, len(x))
def env(n, a, d):
    t = np.arange(n) / SR; return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)
def save(name, x, peak=0.95):
    x = x / (np.abs(x).max() + 1e-9) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())

def shot(boom_f, boom_d, crack, tail, length=2.4, body=1.0, seed=0):
    r = np.random.default_rng(seed)
    n = int(length * SR); t = np.arange(n) / SR
    x = np.zeros(n)
    # crack: a 1 ms N-wave
    if crack > 0:
        k = int(0.0012 * SR); x[:k] += crack * np.linspace(1, -1, k)
    # muzzle blast: a low thump plus a band of noise
    x += body * np.sin(2 * np.pi * boom_f * t * (1 - 0.35 * t)) * env(n, 0.001, boom_d)
    x += 0.9 * lp(r.normal(0, 1, n), 2400) * env(n, 0.0005, boom_d * 0.6)
    x += 0.35 * hp(r.normal(0, 1, n), 3000) * env(n, 0.0002, 0.02)
    # tail: echoes off the ranges, each later one darker and quieter
    for i, (dly, g, fc) in enumerate([(0.11, 0.35, 1800), (0.27, 0.25, 1100), (0.55, 0.2, 700), (0.9, 0.12, 450)]):
        d = int(dly * SR); e = lp(np.roll(x, d) * (np.arange(n) >= d), fc) * g * tail
        x += e
    x += tail * 0.25 * lp(r.normal(0, 1, n), 500) * env(n, 0.05, 0.6)
    x = np.tanh(x * 1.8)
    return x

def mech(parts, length=1.0, seed=1):
    """clicks and slides: list of (time, kind, gain)"""
    r = np.random.default_rng(seed)
    n = int(length * SR); x = np.zeros(n)
    for tm, kind, g in parts:
        i = int(tm * SR)
        if kind == "click":
            k = int(0.012 * SR); s = bp(r.normal(0, 1, k * 4), 3200, 1800)[:k] * env(k, 0.0002, 0.003)
        elif kind == "clack":
            k = int(0.05 * SR); s = (bp(r.normal(0, 1, k), 1500, 900) + 0.6 * np.sin(2 * np.pi * 420 * np.arange(k) / SR)) * env(k, 0.0003, 0.012)
        elif kind == "slide":
            k = int(0.12 * SR); s = bp(r.normal(0, 1, k), 2400, 1500) * np.hanning(k) * 0.5
        elif kind == "thunk":
            k = int(0.08 * SR); s = (np.sin(2 * np.pi * 180 * np.arange(k) / SR) + 0.4 * bp(r.normal(0, 1, k), 900, 500)) * env(k, 0.0005, 0.02)
        elif kind == "shell":
            k = int(0.25 * SR); tt = np.arange(k) / SR
            s = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * dcy) for f, dcy in ((3100, 22), (5400, 30), (7900, 40))) * 0.4
        x[i:i + len(s)] += g * s[: n - i]
    return x

# --- guns
save("shot_303", shot(72, 0.22, 1.0, 1.0, body=1.2, seed=1))
save("shot_slr", shot(80, 0.19, 0.9, 0.9, body=1.1, seed=2))
save("shot_357", shot(105, 0.13, 0.5, 0.7, length=1.8, body=0.9, seed=3))
save("shot_12g", shot(58, 0.3, 0.2, 1.1, length=2.6, body=1.5, seed=4))
save("shot_sawn", shot(52, 0.34, 0.1, 1.2, length=2.6, body=1.7, seed=6))
save("dry", mech([(0, "click", 1)], 0.2))
save("bolt", mech([(0.0, "clack", 1), (0.12, "slide", 0.8), (0.3, "slide", 0.8), (0.42, "clack", 1)], 0.7))
save("pump", mech([(0.0, "slide", 1), (0.08, "clack", 1), (0.22, "slide", 1), (0.3, "clack", 1)], 0.6))
save("mag_out", mech([(0, "click", 0.8), (0.05, "slide", 0.6)], 0.4))
save("mag_in", mech([(0, "slide", 0.5), (0.1, "thunk", 1), (0.12, "click", 0.7)], 0.4))
save("shell_in", mech([(0, "slide", 0.4), (0.06, "thunk", 0.7)], 0.3))
save("break_open", mech([(0, "clack", 1), (0.1, "shell", 0.6), (0.18, "shell", 0.5)], 0.6))
save("break_close", mech([(0, "thunk", 1), (0.02, "clack", 0.9)], 0.3))
save("cylinder", mech([(i * 0.05, "click", 0.6) for i in range(6)] + [(0.4, "clack", 1)], 0.7))
save("cock", mech([(0, "click", 1), (0.05, "click", 0.6)], 0.2))
for i in range(3):
    save(f"casing_{i}", mech([(0, "shell", 1), (0.11 + i * 0.03, "shell", 0.4)], 0.5, seed=10 + i))

# --- impacts
n = int(0.3 * SR); t = np.arange(n) / SR
save("hit_flesh", lp(R.normal(0, 1, n), 900) * env(n, 0.0005, 0.03) + 0.8 * np.sin(2 * np.pi * 90 * t) * env(n, 0.001, 0.05))
save("hit_dirt", bp(R.normal(0, 1, n), 1200, 1500) * env(n, 0.0003, 0.04))
save("hit_metal", sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((1250, 14), (2710, 20), (4400, 28))) + bp(R.normal(0, 1, n), 4000, 2000) * env(n, 0.0002, 0.006))
save("ricochet", np.sin(2 * np.pi * np.cumsum(np.linspace(3400, 1400, n)) / SR) * env(n, 0.002, 0.12))
save("splat", lp(R.normal(0, 1, n), 1400) * env(n, 0.001, 0.08) + 0.5 * np.sin(2 * np.pi * 60 * t) * env(n, 0.002, 0.08))

# --- zombie groans: a buzzy glottal source through vowel formants, pitch wandering, rasp
def groan(seed, length, f0, vowels, rasp=0.4):
    r = np.random.default_rng(seed)
    n = int(length * SR); t = np.arange(n) / SR
    f = f0 * (1 + 0.12 * np.sin(2 * np.pi * 0.7 * t + r.random() * 6) + 0.05 * r.normal(0, 1, n).cumsum() / np.sqrt(n))
    ph = np.cumsum(f) / SR
    src = (2 * (ph % 1) - 1) ** 3 + rasp * r.normal(0, 1, n) * (0.5 + 0.5 * np.sin(2 * np.pi * f0 * 0.5 * t))
    out = np.zeros(n)
    seg = n // len(vowels)
    for i, (f1, f2, f3) in enumerate(vowels):
        w = np.zeros(n); a = max(0, i * seg - seg // 2); b = min(n, (i + 1) * seg + seg // 2)
        w[a:b] = np.hanning(b - a)
        out += w * (bp(src, f1, 120) + 0.6 * bp(src, f2, 180) + 0.25 * bp(src, f3, 250))
    out *= np.minimum(1, t / 0.15) * np.minimum(1, (length - t) / 0.4)
    return np.tanh(out * 3)
V = {"u": (300, 870, 2240), "o": (500, 900, 2400), "a": (750, 1150, 2500), "e": (480, 1700, 2500), "r": (420, 1300, 1600)}
save("zgroan_0", groan(1, 2.2, 78, [V["u"], V["o"], V["a"], V["r"]]))
save("zgroan_1", groan(2, 1.6, 92, [V["a"], V["u"]], rasp=0.6))
save("zgroan_2", groan(3, 2.8, 68, [V["r"], V["o"], V["u"], V["o"]], rasp=0.3))
save("zgroan_3", groan(4, 1.2, 110, [V["e"], V["a"]], rasp=0.8))
save("zattack", groan(5, 0.9, 140, [V["a"], V["a"], V["r"]], rasp=1.0))
save("zdie", groan(6, 1.4, 70, [V["o"], V["u"], V["u"]], rasp=0.5))

# --- scav alarm: a pea whistle, two long blasts (pea makes the trill)
n = int(1.9 * SR); t = np.arange(n) / SR
trill = 1 + 0.08 * np.sign(np.sin(2 * np.pi * 26 * t))
fw = 2850 * trill
blast = ((t > 0.05) & (t < 0.8)) | ((t > 1.0) & (t < 1.8))
x = np.sin(2 * np.pi * np.cumsum(fw) / SR) * blast + 0.15 * bp(R.normal(0, 1, n), 2900, 600) * blast
save("whistle", lp(x, 6000))
print("sfx done")
