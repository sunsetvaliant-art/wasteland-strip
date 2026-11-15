#!/usr/bin/env python3
"""0.2.52: the landmark buildings from the user's pictures (scripts/world/herogen.gd) put on their real lots."""
import json, math
ROOT = "/home/claude/game/"
B = json.load(open(ROOT + "assets/world/buildings.json"))
L = B["lots"]
def find(pred):
    for i, l in enumerate(L):
        if pred(l): return i
    raise SystemExit("not found")
sub = lambda l: str(l[7]) if len(l) > 7 else ""
i = find(lambda l: sub(l).startswith("IMPERIAL HOTEL"))
L[i] = ["shop"] + L[i][1:7] + ["pub/2/3.5/IMPERIAL HOTEL/imperial"]
i = find(lambda l: sub(l).startswith("RIVERVIEW HOTEL"))
L[i] = ["pub"] + L[i][1:7] + ["RIVERVIEW HOTEL|riverview"]
# the Austral: 86 Murwillumbah St (Overture place at -642, -216), the shop facing it
i = find(lambda l: abs(l[1] + 651.49) < 0.5 and abs(l[2] + 197.9) < 0.5)
L[i] = ["shop"] + L[i][1:7] + ["cafe/2/3.0/AUSTRAL CAFE & BAKERY/austral"]
if "+heroes1" not in B["ver"]: B["ver"] += "+heroes1"
json.dump(B, open(ROOT + "assets/world/buildings.json", "w"), separators=(",", ":"))
print("ok")
