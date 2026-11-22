#!/usr/bin/env python3
"""Patch material factors in a .glb in place: glb_mats.py file.glb 'Name=r,g,b,metal,rough' ..."""
import json, struct, sys
p = sys.argv[1]
b = open(p, 'rb').read()
jl = struct.unpack('<I', b[12:16])[0]
j = json.loads(b[20:20 + jl])
rest = b[20 + jl:]
for a in sys.argv[2:]:
    n, v = a.split('=')
    r, g, bb, m, ro = [float(x) for x in v.split(',')]
    for mt in j['materials']:
        if mt.get('name') == n:
            pb = mt.setdefault('pbrMetallicRoughness', {})
            pb['baseColorFactor'] = [r, g, bb, 1.0]; pb['metallicFactor'] = m; pb['roughnessFactor'] = ro
js = json.dumps(j, separators=(',', ':')).encode()
js += b' ' * ((4 - len(js) % 4) % 4)
out = b[:12] + struct.pack('<I', len(js)) + b'JSON' + js + rest
out = out[:8] + struct.pack('<I', len(out)) + out[12:]
open(p, 'wb').write(out)
print('ok', p)
