#!/usr/bin/env python3
"""Sketchfab Mixamo export -> our bone names: 'mixamorig:Hips_01' / 'Hips_02' -> 'mixamorig_Hips'. in.glb out.glb"""
import json, struct, sys, re
MX = {"Hips","Spine","Spine1","Spine2","Neck","Head","HeadTop_End","LeftShoulder","LeftArm","LeftForeArm","LeftHand",
      "RightShoulder","RightArm","RightForeArm","RightHand","LeftUpLeg","LeftLeg","LeftFoot","LeftToeBase","LeftToe_End",
      "RightUpLeg","RightLeg","RightFoot","RightToeBase","RightToe_End"}
for s in ("Left", "Right"):
    for f in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
        for i in range(1, 5): MX.add(f"{s}Hand{f}{i}")
src, dst = sys.argv[1], sys.argv[2]
b = open(src, 'rb').read()
jl = struct.unpack('<I', b[12:16])[0]
j = json.loads(b[20:20 + jl]); rest = b[20 + jl:]
n = 0
joints = set(i for sk in j.get('skins', []) for i in sk['joints'])
for i, nd in enumerate(j['nodes']):
    nm = nd.get('name', '')
    base = re.sub(r'_\d+$', '', nm).replace('mixamorig:', '').replace('mixamorig_', '')
    if i in joints and base in MX:
        nd['name'] = 'mixamorig_' + base; n += 1
j.pop('animations', None)          # their own clip: we play ours
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
out = b[:12] + struct.pack('<I', len(js)) + b'JSON' + js + rest
out = out[:8] + struct.pack('<I', len(out)) + out[12:]
open(dst, 'wb').write(out); print(dst, 'renamed', n)
