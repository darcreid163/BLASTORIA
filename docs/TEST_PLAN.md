# Test plan

Automated: `python tools/verify.py --godot <Godot 4.5.1>`.
This runs the importer, test-script parse preflight, actual GDScript behavioral tests and a 120-frame scene startup.
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


Arcade acceptance (0.2.1): open its menu, verify rules/records, play a run and check that pausing
freezes the displayed clock. Destroy a crate, kill an enemy with your bomb and collect an item;
check +10/+100/+25. Next level must preserve totals. Retry starts from level 1 with zero totals.
On defeat only score may improve; fastest time requires all levels. Relaunch to verify records
persist and old campaign progress remains. Check lowered walls, especially bottom-row hazards.
Automated new suite: tests/test_arcade.gd; includes v1 migration and actual three-stage UI flow.


0.3 acceptance (all manual checks pending):
1. Finish Training: blue checkpoint, bomb beside the gateway crate, safe retreat, pickup, exit.
2. Listen for movement, placement/fuse/explosion, crate, pickup, death, victory/defeat and UI.
   Confirm no clipping or stuck sound on pause/retry/menu, and acceptable simultaneous explosions.
3. Adjust all three sliders; zero Master must silence everything, zero SFX must leave menu audio.
4. Rebind both players; reject duplicate/reserved keys, cancel with Esc, reset defaults.
   Back and Save, restart EXE, confirm volumes, keys, fullscreen and old records/progress persist.
5. Open settings from pause near a bomb; spend ten seconds there and resume with no time advance.
6. Inspect every menu at 1280×800 and 1920×1080, RU/EN, keyboard/mouse and physical controllers.
Automated tests/test_polish.gd adds 40 checks for actual tutorial commands, audio dispatch/assets,
validated settings, v2 migration and the actual scene's pause/settings/rebinding lifecycle.
Headless tests do not play sound or certify graphical layout.
