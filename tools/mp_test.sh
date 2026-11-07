#!/bin/bash
# Two copies of the game on this machine, headless: one hosts, one joins 127.0.0.1; prints what each sees.
cd /home/claude/game
G=/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64
grep -q "^Shot=" project.godot || sed -i 's|^Boot=.*|&\nShot="*res://tools/shot.gd"|' project.godot
F=${1:-2400}
NET_DEBUG=1 VEG_OFF=1 WASTELAND_NO_UPDATE=1 WASTELAND_AUTOPLAY=1 SHOT_PLAN="h:mphost:$((F*4))" timeout 1500 $G --headless --path . > /tmp/claude-0/mp_host.log 2>&1 &
until grep -q "MPTEST host" /tmp/claude-0/mp_host.log 2>/dev/null; do sleep 2; done
NET_DEBUG=1 VEG_OFF=1 WASTELAND_NO_UPDATE=1 WASTELAND_AUTOPLAY=1 SHOT_PLAN="j:mpjoin:$F" timeout 1500 $G --headless --path . > /tmp/claude-0/mp_join.log 2>&1
sleep 20; pkill -f "mphost" ; wait
sed -i '/^Shot=/d' project.godot
grep -E "MPTEST|NET |SCRIPT ERROR|Parse Error" /tmp/claude-0/mp_host.log | head -30
echo ----
grep -E "MPTEST|NET |SCRIPT ERROR|Parse Error" /tmp/claude-0/mp_join.log | head -30
