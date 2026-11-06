#!/usr/bin/env python3
"""Engine Simulator recordings (tools/engine_sim_rec) -> the game's engine loops (assets/audio/engines).
Each loop is cut to a whole number of engine cycles (two crank turns) about 1.6 s long, its end nudged to where the
waveform best matches the start, with a 25 ms crossfade over the seam. One gain per engine keeps on/off/rpm balance.
Usage: engine_loops.py <recordings dir> <out dir>"""
import sys, wave, numpy as np
SR = 44100
SRC, DST = sys.argv[1], sys.argv[2]
def rd(p):
    w = wave.open(p); return np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(np.float64) / 32768
def wr(p, x):
    w = wave.open(p, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes()); w.close()
RPMS = [800, 1500, 2500, 3600, 5000]
for key in ['v8_351', 'i6_202', 'i6_40', 'i4_22r']:
    clips = {}
    for r in RPMS:
        for l in ['on', 'off']:
            x = rd(f'{SRC}/{key}_{r}_{l}.wav')
            x = x - np.convolve(x, np.ones(2205) / 2205, mode='same')
            cyc = 2 * 60.0 / r * SR
            L = int(round(max(1, int(round(1.6 * SR / cyc))) * cyc))
            s0 = int(1.2 * SR); W = int(0.02 * SR); head = x[s0:s0 + W]; best = (0, -9)
            for d in range(-60, 61):
                e = s0 + L + d
                c = np.dot(head, x[e:e + W]) / (np.linalg.norm(head) * np.linalg.norm(x[e:e + W]) + 1e-9)
                if c > best[1]: best = (d, c)
            L += best[0]
            seg = x[s0:s0 + L].copy(); X = int(0.025 * SR); f = np.linspace(0, 1, X)
            seg[:X] = seg[:X] * f + x[s0 + L:s0 + L + X] * (1 - f)
            clips[(r, l)] = seg
    pk = max(np.abs(c).max() for c in clips.values())
    for (r, l), c in clips.items():
        wr(f'{DST}/{key}_{r}_{l}.wav', c * 0.85 / pk * (0.85 if l == 'off' else 1.0))
    print(key, 'done')
