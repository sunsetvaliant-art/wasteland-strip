#!/bin/bash
# Tries a patch the way players get it, before it's published: exports the would-be patch, unpacks the base build and
# every patch on top of each other (as the launcher loads them), adds the Linux Terrain3D library, and starts the game
# from that. Prints any script or load errors; "EXPORT OK" if the game got as far as building the world.
#   tools/check_export.sh
set -e
cd /home/claude/game
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
REPO_DIR=/home/claude/wasteland-strip
W=/tmp/claude-0/check_export
rm -rf $W && mkdir -p $W/prev $W/game/addons/terrain_3d/bin
BASEVER=$(cat ../build/base_version)
PREV=../build/Wasteland.pck
LIST="../build/Wasteland.pck"
for f in $(cd $REPO_DIR/updates && ls patch_${BASEVER}_*.pck patch_${BASEVER}_*.pck.p00 2>/dev/null | sed 's/\.p00$//' | sort -u); do
  if [ -f $REPO_DIR/updates/$f ]; then cp $REPO_DIR/updates/$f $W/prev/$f; else cat $REPO_DIR/updates/$f.p* > $W/prev/$f; fi
  PREV="$PREV,$W/prev/$f"; LIST="$LIST $W/prev/$f"
done
$G --headless --path . --export-patch Windows $W/new.pck --patches "$PREV" 2>&1 | grep -E "^ERROR" || true
python3 tools/pck_strip.py $W/new.pck $W/stripped.pck $(echo "$PREV" | tr ',' ' ' | sed 's|../build/Wasteland.pck||')
python3 - $W/game $LIST $W/stripped.pck <<'PY'
import os, sys
src = open("tools/pck_strip.py").read().replace("\nmain()", "\n"); ns = {}; exec(src, ns)
out = sys.argv[1]
for pk in sys.argv[2:]:
    p = ns["read_index"](pk)
    for e in p["files"]:
        if e["flags"] & 2: continue
        d = os.path.join(out, e["path"].replace("res://", ""))
        os.makedirs(os.path.dirname(d), exist_ok=True)
        p["fh"].seek((p["base"] if p["rel"] else 0) + e["off"])
        open(d, "wb").write(p["fh"].read(e["size"]))
PY
cp addons/terrain_3d/bin/libterrain.linux.*.so $W/game/addons/terrain_3d/bin/
cd $W/game
WASTELAND_NO_UPDATE=1 WASTELAND_AUTOPLAY=1 VEG_OFF=1 timeout 1500 xvfb-run -a -s "-screen 0 960x540x24" $G --path . \
  --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 960x540 --windowed --quit-after 400 > $W/run.log 2>&1 || true
grep -E "SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Failed loading|not found|Can't load|ROADPILOT|RGROADS|LANDMARKS|LAUNCHER" $W/run.log | grep -v "libterrain.linux.debug" | sort | uniq -c | head -30
if grep -qE "ROADPILOT|RGROADS" $W/run.log && ! grep -qE "SCRIPT ERROR|Failed to load script" $W/run.log; then echo "EXPORT OK"; else echo "EXPORT BROKEN (log: $W/run.log)"; fi
