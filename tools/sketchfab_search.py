# Sketchfab search: downloadable models with free licences. usage: search.py "query" [max]
import json, sys, urllib.request, urllib.parse
T = open('/home/claude/.secrets/sketchfab_token').read().strip()
H = {'Authorization': 'Token ' + T, 'User-Agent': 'wasteland/1.0'}
def api(path, **q):
    u = 'https://api.sketchfab.com/v3/' + path + '?' + urllib.parse.urlencode(q)
    return json.load(urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=40))
q = sys.argv[1]; n = int(sys.argv[2]) if len(sys.argv) > 2 else 12
d = api('search', type='models', q=q, downloadable='true', count=24, sort_by='-likeCount')
out = 0
for m in d.get('results', []):
    lic = (m.get('license') or {}).get('label', '?')
    if not any(k in lic for k in ('CC0', 'Attribution', 'Free Standard')): continue
    if 'NonCommercial' in lic: continue
    print('%s | %s | %s | tris %s | likes %s | %s' % (m['uid'], m['name'][:50], lic, m.get('faceCount'), m.get('likeCount'), m['user']['username']))
    out += 1
    if out >= n: break
