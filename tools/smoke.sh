#!/bin/bash
# Fast check: boots the real game headless (launcher -> world) for a few hundred frames and prints any script errors.
cd /home/claude/game
WASTELAND_NO_UPDATE=1 WASTELAND_AUTOPLAY=1 VEG_OFF=1 timeout 300 /home/claude/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after 400 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed|at: res://" | sort | uniq -c | head -30
echo "smoke done"
