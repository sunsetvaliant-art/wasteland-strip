#!/bin/bash
# usage: SHOT_PLAN="..." tools/run_shots.sh
cd /home/claude/game
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
grep -q "^Shot=" project.godot || sed -i 's|^Boot=.*|&\nShot="*res://tools/shot.gd"|' project.godot
NPC_OFF=1 TERRAIN_DEBUG=$TERRAIN_DEBUG NO_ROAD_PILOT=$NO_ROAD_PILOT GRASS_NOHIDE=$GRASS_NOHIDE WASTELAND_NO_UPDATE=1 WASTELAND_AUTOPLAY=1 timeout 1700 xvfb-run -a -s "-screen 0 960x540x24" $G --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 960x540 --windowed 2>&1 | grep -E "SHOT|PROBE|ZTEST|CARTEST|WHEELS|VEG|PILOTDBG|SCRIPT ERROR|ERROR: [^C]|Parse Error|at: res" | grep -v "ALSA\|audio\|Condition \"status" | head -40
sed -i '/^Shot=/d' project.godot
