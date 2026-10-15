# Test plan

Automated: `python tools/verify.py --godot <Godot 4.5.1>`.
This runs the importer, actual GDScript behavioral tests and a 120-frame scene startup.
Fail on nonzero process exit, engine SCRIPT ERROR/ERROR/FAIL output or missing test summary.

Coverage: walls/crates, blast reach, fuse/fire boundaries, duplicate placement, owner capacity,
three-bomb chains, same-tick terrain snapshot, damage and draws, independent players, pause,
restart, exits, final campaign result, pickups/caps, 100 map seeds, AI blockers/escape,
replay equality, 25 simulation runs, save/backup recovery, actual menu and world lifecycle,
RU/EN translations. Seed checks establish connectivity with crates destructible; they are not
proofs of difficulty or that every generated map is fun to play.

Manual Windows gate (all pending):
1. Extract and start EXE without Godot installed; record Windows version, CPU/GPU/driver.
2. Start campaign, walk around corners and test walls. Place bomb, escape; retry after death.
3. Destroy crate, collect each pickup; confirm limit and visual feedback.
4. Beat all three levels, reach exits; return to menu, relaunch and continue unlocked level.
5. Start arena: move both players, test survivor and simultaneous-death results, rematch.
6. Pause near detonation; wait ten seconds; resume without elapsed in-game time.
7. Switch RU/EN, fullscreen/windowed; inspect 1280×800 and 1920×1080 layouts.
8. Test two physical controllers, independent D-pads/A and Start pause; check menu focus.
9. Play at least ten rounds; capture crashes, visual overlaps or unfair AI behaviors.
10. Only then mark runtime/visual/gamepad gates Verified; FPS needs a measured profile.
