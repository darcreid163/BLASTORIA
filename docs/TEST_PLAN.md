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


## 0.4 / master prompt 2.0

Automated tests/test_worlds.gd adds 59 checks to the existing 123:
Classic concealment/reveal/punishment/deduplication, timer boundaries/pause, both contact directions,
all eight power effects and combined pickups, remote chains, temporary immunity boundary,
40 large-map seeds and objective reachability, off-screen bombs/enemies, deterministic replay,
last-observed fog, camera footprint at four aspect ratios, secret positives/negatives/one-time reward,
completion return fixture, old JSON key migration/collision safety, artifact persistence,
actual main scene modes/map/camera/carry/retry/reinforcement views. Source tool export_smoke.gd
is excluded from release PCK and is invoked externally against the Linux release executable.

Windows manual acceptance, still pending:
1. Extract complete 0.4 archive and run BLASTORIA.exe. Check main menu RU/EN and controls.
2. Adventure: enter 41×31 ruins, move across sectors and all four edges; camera must scroll smoothly
   without losing hero, bomb cells or exit behind geometry/HUD. Inspect Full HD and 1280×800.
3. Tab/Select cycle hidden/mini/expanded map. Unexplored areas remain hidden; remembered terrain
   does not update remotely. The world continues while map is open; Esc must pause it.
4. Place a bomb, move camera away, return: blast and destruction must have occurred. Observe distant enemies.
5. Classic: uncover exit, leave enemy alive, verify lock. Hit already open exit and count two new Wardens.
   At timer zero verify warning and four Wardens, no unexplained immediate death. Complete all three stages.
6. Collect each marked power (+B/+R/+S/RC/WP/BP/FP/IV), test stacking/pass/fire/contact rules, pause immunity,
   remote input (E / gamepad B), and death/next-stage policy. Rebind remote key and relaunch.
7. Developer/owner secret scenario: follow SECRET_DESIGN.md, satisfy compass eligibility organically,
   finish, return to niche, collect. Check result arrow/score, restart EXE, check collection and no duplicate.
8. Recheck unchanged Arcade run/records and old campaign Continue from inside Adventure menu.
9. Save/relaunch with old profile; inspect settings/records. Report Windows/CPU/GPU/driver and failures.

No full 60 FPS claim without a measured graphical run. No tests for nine unimplemented secrets are claimed.
