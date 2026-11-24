#!/usr/bin/env python3
"""0.2.74: zombie voices, closer to a real throat than the old buzz through vowels.
A glottal pulse train (Rosenberg pulses) with heavy jitter and shimmer that drops into vocal fry (slow, uneven,
period-doubled pulses: the creak), breath noise riding the pulses, a wet gurgle (noise flutter through a low band),
time-varying formant resonators for the vowels (a proper vocal tract, not band-passed buzz), a gasp in, and a little
room. Writes assets/audio/sfx/zgroan_0..7, zattack_0..2 (and zattack), zdie, zbreath_0..1.
usage: python3 tools/zombie_voice.py"""
import numpy as np, wave, os, math
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")

def save(name, x, peak=0.9):
    x = x / (np.abs(x).max() + 1e-9) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())

def glottal(r, n, f0_curve, fry_curve, jitter=0.08, shimmer=0.25):
    """pulse train; fry_curve 0..1 blends toward slow irregular pulses with period doubling"""
    out = np.zeros(n); breath_env = np.zeros(n)
    i = 0; k = 0
    while i < n:
        fry = fry_curve[i]
        f0 = f0_curve[i] * (1 - fry) + (38 + 18 * r.random()) * fry
        T = SR / max(f0, 20) * (1 + r.normal(0, jitter + 0.25 * fry))
        T = max(int(T), 40)
        amp = (1 + r.normal(0, shimmer + 0.3 * fry)) * (0.55 if (fry > 0.5 and k % 2) else 1.0)
        # Rosenberg pulse: open 40 %, close 16 %
        op = int(T * 0.4); cl = max(int(T * 0.16), 2)
        p = np.zeros(T)
        tt = np.arange(op) / op; p[:op] = 0.5 * (1 - np.cos(np.pi * tt))
        tc = np.arange(cl) / cl; p[op:op + cl] = np.cos(0.5 * np.pi * tc)
        d = np.diff(p, prepend=0.0) * abs(amp)
        e = min(n, i + T)
        out[i:e] += d[:e - i]
        breath_env[i:e] += p[:e - i]
        i += T; k += 1
    return out, breath_env

def resonator(x, f_curve, bw_curve):
    """a two-pole resonator whose frequency and bandwidth follow the curves (per sample)"""
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i in range(len(x)):
        r = math.exp(-math.pi * bw_curve[i] / SR)
        c = 2 * r * math.cos(2 * math.pi * f_curve[i] / SR)
        v = x[i] * (1 - r) + c * y1 - r * r * y2
        y2 = y1; y1 = v; y[i] = v
    return y

def bp(x, fc, bw):
    F = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); F *= np.exp(-((f - fc) / bw) ** 2); return np.fft.irfft(F, len(x))

def room(x, r, wet=0.18, t60=0.45):
    n = int(t60 * SR); t = np.arange(n) / SR
    ir = r.normal(0, 1, n) * np.exp(-6.9 * t / t60); ir[0] = 0
    ir = bp(ir, 1200, 1500)
    y = np.convolve(x, ir)[:len(x)]
    return x + wet * y / (np.abs(y).max() + 1e-9) * np.abs(x).max()

V = {  # formants F1..F4 (Hz) of a big rough male throat
    "uh": (560, 1100, 2400, 3300), "ah": (720, 1200, 2500, 3400), "aw": (580, 880, 2450, 3300), "oo": (330, 800, 2300, 3200),
    "er": (480, 1300, 1650, 3100), "eh": (520, 1650, 2450, 3400), "rr": (420, 1150, 1500, 3000), "gh": (300, 1400, 2200, 3200)}

def voice(seed, length, f0, vowels, fry=0.4, rasp=0.3, gurgle=0.3, gasp=0.0, rise=0.0, loud=1.0):
    r = np.random.default_rng(seed)
    n = int(length * SR); t = np.arange(n) / SR
    # pitch: a slow wander, a fall at the end, optional rise (an attack's shriek)
    f0c = f0 * (1 + 0.1 * np.sin(2 * np.pi * (0.4 + 0.5 * r.random()) * t + r.random() * 6) + rise * np.minimum(1, t / (0.3 * length)) - 0.25 * np.clip((t - 0.7 * length) / (0.3 * length), 0, 1))
    # fry comes and goes, more of it at the ends
    fc = np.clip(fry * (0.6 + 0.4 * np.sin(2 * np.pi * (0.8 + r.random()) * t + r.random() * 6)) + 0.5 * np.clip((t - 0.75 * length) / (0.25 * length), 0, 1), 0, 1)
    src, ph = glottal(r, n, f0c, fc)
    noise = r.normal(0, 1, n)
    src = src * 1.0 + rasp * noise * (0.3 + ph) * 0.05
    # vowel path through the formants
    m = len(vowels)
    keys = np.linspace(0, n - 1, m)
    fcurves = [np.interp(np.arange(n), keys, [V[v][j] for v in vowels]) for j in range(4)]
    bws = [np.full(n, b) for b in (110, 140, 220, 300)]
    y = sum(g * resonator(src, fcurves[j], bws[j]) for j, g in enumerate((1.0, 0.7, 0.35, 0.18)))
    # gurgle: wet flutter low in the throat
    if gurgle > 0:
        flutter = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (16 + 8 * r.random()) * t + r.normal(0, 0.6, n).cumsum() * 0.002)))
        y += gurgle * bp(noise, 450, 300) * flutter * 0.6 * (np.abs(y).max() + 1e-9)
    amp = np.minimum(1, t / 0.12) * np.minimum(1, (length - t) / 0.35) * (0.8 + 0.2 * np.sin(2 * np.pi * 1.3 * t + r.random() * 6))
    y = y * amp
    if gasp > 0:   # a ragged breath in first
        gn = int(0.35 * SR)
        g = bp(r.normal(0, 1, gn), 1800, 1400) * np.sin(np.pi * np.arange(gn) / gn) ** 2
        y = np.concatenate([g * gasp * 0.5 * np.abs(y).max() / (np.abs(g).max() + 1e-9), y])
    y = np.tanh(y / (np.abs(y).max() + 1e-9) * (1.6 + loud))
    return room(y, r)

def breath(seed, length):
    r = np.random.default_rng(seed)
    n = int(length * SR); t = np.arange(n) / SR
    cyc = 0.5 - 0.5 * np.cos(2 * np.pi * t / (length / 2))
    x = bp(r.normal(0, 1, n), 900, 900) * cyc ** 1.5
    x += 0.35 * bp(r.normal(0, 1, n), 350, 150) * cyc * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 22 * t)))
    return room(x, r, 0.12)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("zgroan_0", voice(11, 2.2, 82, ["uh", "aw", "rr", "uh"], fry=0.35, gasp=0.6))
    save("zgroan_1", voice(12, 1.7, 95, ["ah", "uh", "gh"], fry=0.5, gurgle=0.5))
    save("zgroan_2", voice(13, 2.8, 70, ["rr", "aw", "oo", "aw"], fry=0.6, gurgle=0.2))
    save("zgroan_3", voice(14, 1.3, 120, ["eh", "ah", "rr"], fry=0.25, rasp=0.6))
    save("zgroan_4", voice(15, 2.4, 76, ["oo", "uh", "er", "uh"], fry=0.7, gurgle=0.6, gasp=0.8))
    save("zgroan_5", voice(16, 1.9, 88, ["gh", "ah", "aw"], fry=0.45, gurgle=0.35))
    save("zgroan_6", voice(17, 3.0, 64, ["uh", "rr", "uh", "oo", "uh"], fry=0.8, gurgle=0.3))
    save("zgroan_7", voice(18, 1.5, 104, ["ah", "er", "gh"], fry=0.3, rasp=0.5, gasp=0.5))
    for i, (f0, v) in enumerate(((150, ["ah", "ah", "rr"]), (170, ["eh", "ah", "gh"]), (135, ["aw", "ah", "rr"]))):
        x = voice(30 + i, 1.0, f0, v, fry=0.15, rasp=0.9, gurgle=0.25, rise=0.35, loud=2.0)
        save("zattack_%d" % i, x)
        if i == 0: save("zattack", x)
    save("zdie", voice(40, 1.8, 72, ["oo", "uh", "gh", "uh"], fry=0.9, gurgle=0.8))
    save("zbreath_0", breath(50, 2.6))
    save("zbreath_1", breath(51, 3.4))
    print("zombie voices written to", os.path.abspath(OUT))
