#!/bin/bash
# usage: SHOT_PLAN="..." tools/run_shots.sh
cd /home/claude/game
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
grep -q "^Shot=" project.godot || sed -i 's|^Boot=.*|&\nShot="*res://tools/shot.gd"|' project.godot
WASTELAND_NO_UPDATE=1 WASTELAND_AUTOPLAY=1 timeout 1700 xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --windowed 2>&1 | grep -E "SHOT|SCRIPT ERROR|ERROR: [^C]|Parse Error|at: res" | grep -v "ALSA\|audio\|Condition \"status" | head -40
sed -i '/^Shot=/d' project.godot
