#!/usr/bin/env python3
"""Engine sound synthesiser. Builds seamless loops for each engine at several rpm points, on and off throttle,
from the firing order: every combustion event is a pressure pulse sent down that bank's exhaust, which rings the
pipe modes, gets choked by the muffler and clipped a bit by the tailpipe. Cross-plane V8 banks fire unevenly,
which is the burble; a lumpy cam adds cycle-to-cycle variation at idle.
Everything is built by circular convolution so the loops are sample-exact seamless.
usage: python3 tools/engine_synth.py  -> assets/audio/engines/<sound>_<rpm>_<on|off>.wav + starter / pops
"""
import numpy as np, wave, os, json

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "engines")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

ENGINES = {
    # crank angle of each firing event in the 720 deg cycle, which bank it exhausts into
    "i6_202": {"fire": [0, 120, 240, 360, 480, 600], "bank": [0] * 6, "pipe": 3.2, "muffler": 900, "grit": 1.6, "thump": 0.9, "lump": 0.05, "mech": 0.05, "tone": 1.0},
    "i4_22r": {"fire": [0, 180, 360, 540], "bank": [0] * 4, "pipe": 2.6, "muffler": 1300, "grit": 2.2, "thump": 0.7, "lump": 0.04, "mech": 0.09, "tone": 1.25},
    # Ford cross-plane: 1-3-7-2-6-5-4-8 every 90 deg; cylinders 1-4 right bank, 5-8 left
    "v8_351": {"fire": [0, 90, 180, 270, 360, 450, 540, 630], "bank": [0, 0, 1, 0, 1, 1, 0, 1], "pipe": 3.6, "muffler": 700, "grit": 2.6, "thump": 1.25, "lump": 0.16, "mech": 0.04, "tone": 0.8},
    "i6_40": {"fire": [0, 120, 240, 360, 480, 600], "bank": [0] * 6, "pipe": 3.4, "muffler": 800, "grit": 1.9, "thump": 1.05, "lump": 0.06, "mech": 0.05, "tone": 0.9},
}
RPMS = [800, 1500, 2500, 3600, 5000]


def pipe_ir(length, muffler, n, bank_delay=0.0):
    """impulse response of header + pipe + muffler: damped modes of an open pipe, low-passed"""
    t = np.arange(n) / SR
    c = 340.0 * 1.35  # hot gas
    f0 = c / (2 * length)
    ir = np.zeros(n)
    for k in range(1, 14):
        f = f0 * k
        if f > 4000: break
        decay = 18 + 9 * k
        ir += (1.0 / k ** 0.55) * np.exp(-decay * t) * np.sin(2 * np.pi * f * t + rng.uniform(0, 1))
    # broadband crack of the exhaust valve opening
    ir[: int(0.002 * SR)] += rng.normal(0, 0.6, int(0.002 * SR)) * np.linspace(1, 0, int(0.002 * SR))
    # muffler: one-pole low-pass in the frequency domain
    F = np.fft.rfft(ir)
    fr = np.fft.rfftfreq(n, 1 / SR)
    F /= (1 + 1j * fr / muffler)
    if bank_delay:
        F *= np.exp(-2j * np.pi * fr * bank_delay)
    return np.fft.irfft(F, n)


def loop(eng, rpm, load):
    cyc = 120.0 / rpm                      # seconds per 720 deg
    ncyc = max(4, int(round(1.6 / cyc)))   # ~1.6 s, whole cycles so the loop wraps clean
    N = int(round(ncyc * cyc * SR))
    cyc = N / SR / ncyc                    # snap the rpm a hair so the cycle is exact
    banks = [np.zeros(N), np.zeros(N)]
    thump = np.zeros(N)
    for c in range(ncyc):
        for i, ang in enumerate(eng["fire"]):
            tt = (c + ang / 720.0) * cyc
            # per-event strength: load, cam lump at low revs, small random misfire-ish variation
            lump = eng["lump"] * max(0.0, 1.6 - rpm / 1500.0)
            a = (0.35 + 0.65 * load) * (1.0 + rng.normal(0, 0.05 + lump))
            if load < 0.2:
                a *= 0.45 + 0.2 * rng.random()          # closed throttle: thin, uneven pulses
            idx = tt * SR
            i0 = int(idx) % N
            frac = idx - int(idx)
            b = banks[eng["bank"][i]]
            b[i0] += a * (1 - frac)
            b[(i0 + 1) % N] += a * frac
            thump[i0] += a
    sig = np.zeros(N)
    for bi, b in enumerate(banks):
        if not b.any(): continue
        ir = pipe_ir(eng["pipe"] * (1.0 + 0.07 * bi), eng["muffler"] * (0.75 + 0.5 * load), N, bank_delay=0.0007 * bi)
        sig += np.fft.irfft(np.fft.rfft(b) * np.fft.rfft(ir), N)
    # body thump: low damped sine per firing, the chest-thump you feel more than hear
    tt = np.arange(N) / SR
    th_ir = np.exp(-tt * 55) * np.sin(2 * np.pi * 38 * eng["tone"] * tt)
    sig += eng["thump"] * 2.2 * np.fft.irfft(np.fft.rfft(thump) * np.fft.rfft(th_ir), N)
    # intake roar on load: noise shaped by the firing rate
    noise = rng.normal(0, 1, N)
    F = np.fft.rfft(noise); fr = np.fft.rfftfreq(N, 1 / SR)
    F *= np.exp(-((fr - 700 * eng["tone"]) / 900) ** 2)
    intake = np.fft.irfft(F, N)
    env = np.fft.irfft(np.fft.rfft(thump) * np.fft.rfft(np.exp(-tt * 140)), N)
    sig += intake * (0.05 + 0.25 * load) * (rpm / 5000.0) * (0.4 + env / (env.max() + 1e-9))
    # valvetrain / timing chain tick (2x camshaft speed, faint)
    mech = np.fft.irfft(np.fft.rfft(rng.normal(0, 1, N)) * np.exp(-((fr - 3500) / 1800) ** 2), N)
    sig += mech * eng["mech"] * (rpm / 3000.0)
    # tailpipe: soft clip for grit, normalise per sample point (pitch/volume curves are done in game)
    sig /= np.percentile(np.abs(sig), 99.5) + 1e-9
    sig = np.tanh(sig * eng["grit"]) / np.tanh(eng["grit"])
    sig -= sig.mean()
    return sig * 0.89, 60.0 * 2 / cyc


def save(name, sig, loop_it=True):
    s16 = (np.clip(sig, -1, 1) * 32767).astype(np.int16)
    p = os.path.join(OUT, name + ".wav")
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(s16.tobytes())
    return p


def starter(eng):
    # starter motor whine + slow compression chug, then catches
    n = int(1.4 * SR); t = np.arange(n) / SR
    crank_rpm = 230
    ncyl = len(eng["fire"])
    ph = 2 * np.pi * (crank_rpm / 60.0) * ncyl / 2 * t
    chug = (0.5 + 0.5 * np.sin(ph)) ** 6
    whine = 0.25 * np.sin(2 * np.pi * 1150 * t + 3 * np.sin(ph)) * (0.6 + 0.4 * chug)
    grind = rng.normal(0, 0.15, n) * chug
    sig = whine + grind + 0.9 * np.sin(2 * np.pi * 45 * t) * chug
    sig *= np.minimum(1, t * 20) * np.minimum(1, (1.4 - t) * 8)
    return sig / np.abs(sig).max() * 0.8


def pop(seed):
    r = np.random.default_rng(seed)
    n = int(0.25 * SR); t = np.arange(n) / SR
    sig = r.normal(0, 1, n) * np.exp(-t * 60) + 1.5 * np.sin(2 * np.pi * (90 + 40 * r.random()) * t) * np.exp(-t * 35)
    F = np.fft.rfft(sig); fr = np.fft.rfftfreq(n, 1 / SR); F /= (1 + 1j * fr / 1800)
    sig = np.fft.irfft(F, n)
    sig = np.tanh(sig / np.abs(sig).max() * 3)
    return sig * 0.95


if __name__ == "__main__":
    index = {}
    for key, eng in ENGINES.items():
        pts = []
        for rpm in RPMS:
            for load, tag in ((1.0, "on"), (0.0, "off")):
                sig, real = loop(eng, rpm, load)
                save(f"{key}_{rpm}_{tag}", sig)
            pts.append(real)
        index[key] = {"rpms": [round(r, 2) for r in pts]}
        save(f"{key}_starter", starter(eng))
        print(key, "done")
    for i in range(4):
        save(f"pop_{i}", pop(i + 11))
    json.dump(index, open(os.path.join(OUT, "index.json"), "w"), indent=1)
