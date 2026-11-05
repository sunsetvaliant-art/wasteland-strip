#!/bin/bash
# Builds a patch: a small .pck holding only what changed since the base build.
# usage: tools/make_patch.sh 0002 "short note"   ->  ../build/patches/patch_0002.pck
# The player drops it into the "patches" folder beside Wasteland.exe; files load in name order, newest wins.
set -e
cd /home/claude/game
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
N=${1:?patch number}
mkdir -p ../build/patches
echo "0.1.$((10#$N))" > version.txt
$G --headless --path . --export-patch "Windows" ../build/patches/patch_$N.pck --patches ../build/Wasteland.pck 2>&1 | grep -E "ERROR|savepack" || true
ls -la ../build/patches/patch_$N.pck
