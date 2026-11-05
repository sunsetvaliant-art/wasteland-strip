#!/bin/bash
# Publishing.
#   tools/release.sh full 0.2.0 "notes"   -> exports the whole game to ../build_zip/Wasteland_v0.2.0.zip (sent as a full download)
#   tools/release.sh patch 0001 "notes"   -> exports only what changed since the last full build into the repo's updates/ folder,
#                                            adds it to updates/manifest.json and pushes; every player's launcher picks it up
set -e
cd /home/claude/game
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
REPO_DIR=/home/claude/wasteland-strip
KIND=${1:?full or patch}; ID=${2:?version or patch number}; NOTES=${3:-""}; PRESET=${4:-Windows}
mkdir -p ../build ../build/patches $REPO_DIR/updates
MAN=$REPO_DIR/updates/manifest.json
[ -f $MAN ] || echo '{"patches": []}' > $MAN
if [ "$KIND" = full ]; then
  echo "$ID" > version.txt
  $G --headless --path . --export-release "Windows" ../build/Wasteland.exe 2>&1 | grep -E "^ERROR" | grep -v rcedit || true
  rm -rf ../build_zip/Wasteland && mkdir -p ../build_zip/Wasteland/patches
  cp ../build/Wasteland.exe ../build/Wasteland.pck ../build/*.dll ../build_zip/Wasteland/
  cp tools/patches_readme.txt ../build_zip/Wasteland/patches/READ_ME.txt
  rm -f ../build_zip/Wasteland_v$ID.zip
  (cd ../build_zip && zip -qr -6 Wasteland_v$ID.zip Wasteland)
  echo "$ID" > ../build/base_version
  python3 - "$MAN" "$ID" "$NOTES" <<'PY'
import json,sys,datetime
p,v,n=sys.argv[1:]; m=json.load(open(p))
m["full"]={"version":v,"date":datetime.date.today().isoformat(),"notes":n}
m["patches"]=[]          # a new full build starts a fresh patch line
json.dump(m,open(p,"w"),indent=1)
PY
  ls -la ../build_zip/Wasteland_v$ID.zip
else
  BASEVER=$(cat ../build/base_version)
  VER="${BASEVER%.*}.$((${BASEVER##*.} + 10#$ID))"
  echo "$VER" > version.txt
  $G --headless --path . --export-patch "$PRESET" $REPO_DIR/updates/patch_${BASEVER}_$ID.pck --patches ../build/Wasteland.pck 2>&1 | grep -E "^ERROR" || true
  PF=patch_${BASEVER}_$ID.pck
  SIZE=$(stat -c %s $REPO_DIR/updates/$PF)
  PARTS=""
  if [ $SIZE -gt 95000000 ]; then        # GitHub won't take a file over 100 MB: ship it in 90 MB pieces
    (cd $REPO_DIR/updates && split -b 90M -d -a 2 $PF $PF.p && rm $PF)
    PARTS=$(cd $REPO_DIR/updates && ls $PF.p* | tr '\n' ',')
  fi
  python3 - "$MAN" "$PF" "$VER" "$NOTES" "$SIZE" "$PARTS" <<'PY'
import json,sys,datetime
p,f,v,n,s,parts=sys.argv[1:]; m=json.load(open(p))
e={"file":f,"version":v,"date":datetime.date.today().isoformat(),"notes":n,"size":int(s)}
if parts.strip(","): e["parts"]=[x for x in parts.split(",") if x]
m["patches"]=[x for x in m["patches"] if x["file"]!=f]+[e]
json.dump(m,open(p,"w"),indent=1)
PY
  ls -la $REPO_DIR/updates/ | grep "${BASEVER}_$ID"
fi
# keep the repo's copy of the project in step, then publish
tar --exclude=./.godot --exclude=./terrain --exclude=./data --exclude=./ws_models --exclude=./build -cf - . | (cd $REPO_DIR && tar -xf -)
cd $REPO_DIR
# push big things a few at a time so no single push gets too large
for d in updates; do [ -d $d ] && git add $d && git commit -qm "Release $KIND $ID: $d

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01UwUdmBaRmNwsMyT6MNDatn" && git push 2>&1 | tail -1; done
git add -A && git commit -qm "Release $KIND $ID

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01UwUdmBaRmNwsMyT6MNDatn" && git push 2>&1 | tail -1
echo "released $KIND $ID"
