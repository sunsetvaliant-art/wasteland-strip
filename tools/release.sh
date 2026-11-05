#!/bin/bash
# Publishing to GitHub Releases (sunsetvaliant-art/wasteland-strip).
#   tools/release.sh full 0.2.0 "notes"    -> exports the whole game, uploads Wasteland_v0.2.0.zip (a fresh download)
#   tools/release.sh patch 0003 "notes"    -> exports only what changed since the last full build, uploads patch_0003.pck
# The in-game launcher downloads every patch_*.pck it hasn't got, in order, on start.
set -e
cd /home/claude/game
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
REPO=sunsetvaliant-art/wasteland-strip
KIND=${1:?full or patch}; ID=${2:?version or patch number}; NOTES=${3:-""}
mkdir -p ../build ../build/patches
if [ "$KIND" = full ]; then
  echo "$ID" > version.txt
  $G --headless --path . --export-release "Windows" ../build/Wasteland.exe 2>&1 | grep -E "^ERROR" | grep -v rcedit || true
  rm -rf ../build_zip/Wasteland && mkdir -p ../build_zip/Wasteland/patches
  cp ../build/Wasteland.exe ../build/Wasteland.pck ../build/*.dll ../build_zip/Wasteland/
  cp tools/patches_readme.txt ../build_zip/Wasteland/patches/READ_ME.txt
  ASSET=../build_zip/Wasteland_v$ID.zip; rm -f $ASSET
  (cd ../build_zip && zip -qr -6 Wasteland_v$ID.zip Wasteland)
  TAG=v$ID; TITLE="Wasteland v$ID (full download)"
else
  BASEVER=$(cat ../build/base_version 2>/dev/null || echo 0.2.0)
  echo "${BASEVER%.*}.$((10#$ID))" > version.txt
  $G --headless --path . --export-patch "Windows" ../build/patches/patch_$ID.pck --patches ../build/Wasteland.pck 2>&1 | grep -E "^ERROR" || true
  ASSET=../build/patches/patch_$ID.pck
  TAG=patch-$ID; TITLE="Patch $ID"
fi
[ "$KIND" = full ] && echo "$ID" > ../build/base_version
ls -la $ASSET
# create the release, then upload the file to it
RID=$(gh api repos/$REPO/releases -X POST -f tag_name=$TAG -f target_commitish=main -f name="$TITLE" -f body="$NOTES" --jq .id)
curl -sS --fail -X POST -H "Authorization: Bearer $(gh auth token)" -H "Content-Type: application/octet-stream" \
  --data-binary @"$ASSET" "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=$(basename $ASSET)" | head -c 300; echo
echo "released $TAG"
