# Sketchfab download: dl.py uid name -> /home/claude/sf/dl/<name>/ (glb if offered, else gltf zip unpacked)
import json, sys, os, urllib.request, zipfile, io
T = open('/home/claude/.secrets/sketchfab_token').read().strip()
H = {'Authorization': 'Token ' + T, 'User-Agent': 'wasteland/1.0'}
uid, name = sys.argv[1], sys.argv[2]
out = '/home/claude/sf/dl/' + name; os.makedirs(out, exist_ok=True)
meta = json.load(urllib.request.urlopen(urllib.request.Request('https://api.sketchfab.com/v3/models/' + uid, headers=H), timeout=60))
json.dump({'uid': uid, 'name': meta['name'], 'author': meta['user']['username'], 'license': (meta.get('license') or {}).get('label'), 'url': meta.get('viewerUrl')}, open(out + '/meta.json', 'w'), indent=1)
d = json.load(urllib.request.urlopen(urllib.request.Request('https://api.sketchfab.com/v3/models/' + uid + '/download', headers=H), timeout=60))
if 'glb' in d:
    data = urllib.request.urlopen(d['glb']['url'], timeout=600).read(); open(out + '/model.glb', 'wb').write(data); print(name, 'glb', len(data))
else:
    data = urllib.request.urlopen(d['gltf']['url'], timeout=600).read(); zipfile.ZipFile(io.BytesIO(data)).extractall(out); print(name, 'gltf zip', len(data))
