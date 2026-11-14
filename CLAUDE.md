# Instructions for Claude sessions on this repo

1. Read `TODO.md` first. It is the user's master to-do list and he reads it on GitHub. Before every patch release,
   tick what shipped (with the patch number), add anything new he asked for, and push it with the patch.
2. Read `docs/HANDOVER.md` for the workspace bootstrap (Godot path, working copy at /home/claude/game, push clone at
   /home/claude/wasteland-strip), the test scripts and the release script.
3. Decisions already made are in `docs/DESIGN_0.3.md` and `docs/HANDOVER.md` section 5. Don't re-ask them.
4. Self-test before handing over: `tools/smoke.sh`, then `tools/check_export.sh`; screenshots with `tools/run_shots.sh`.
5. The user plays on a GTX 1650 Ti. Keep an eye on draw calls and frame rate.
