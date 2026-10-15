# BLASTORIA 0.4 development report

Date: 2026-10-15. Stage: prototype, first Classic Core / Large Worlds slice under master prompt 2.0.
Engine: Godot 4.5.1.stable.official.f62fdbde1, Linux x86_64, headless.

| Check | Actual result | Evidence |
| --- | --- | --- |
| New MASTER_SPEC.md attachment bytes | Exact match | qa/spec_sha256.txt |
| Previous MASTER_PROMPT_RU.md | Preserved unchanged, exact original attachment match | qa/spec_sha256.txt |
| Source import and test parser | PASS | qa/import.txt, qa/parse_tests.txt |
| Behavioral/integration tests | 182 passed / 0 failed | qa/tests.txt |
| Main scene startup | PASS, 120 frames headless | qa/smoke.txt |
| Fresh source import without .godot | PASS | qa/clean_import.txt |
| Windows x86_64 release export | PASS; PE32+ GUI executable | qa/export_windows.txt, qa/binary_sha256.txt |
| Linux release export and startup | PASS | qa/export_linux.txt, qa/exported_linux_smoke.txt |
| Exported Adventure/Classic/Training/Arcade entry and dynamic actors | PASS, external QA script, headless | qa/exported_modes.txt |
| Native Windows 0.4 run | NOT TESTED | No Windows/Wine runtime |
| Rendered camera/layout/art and audible sound | NOT TESTED | No graphical desktop or listening validation |
| Physical controllers / hardware FPS | NOT TESTED / NOT MEASURED | Headless tests do not substitute hardware |

59 new checks cover Classic rules/abilities, 40 large-map seeds, off-screen simulation, fog,
camera projection constraints, compass conditions and developer completion fixture, profile v4
migration and live-scene UI/mode transitions. The previous 123 Arcade/tutorial/save/core checks remain.
The secret integration fixture supplies exploration history to test transitions; it is not an organic
human playthrough of the full secret. Audio playback is disabled in headless mode; asset/event/bus
validation remains separate from hearing. Camera math and actual Camera3D movement are checked,
but image composition and edge occlusion need Windows visual acceptance.

Fixed during this iteration: legacy JSON float key codes could collide with new integer default keys
and cause custom bindings to reset; normalization and validation now preserve the old layout.
Classic retry now rolls score back to stage entry to prevent repeated-stage score farming.
A contact/immunity test initially put the enemy in lethal fire; the fixture was corrected to isolate
contact semantics. Test-script naming collision was caught by parser preflight before execution.

Implemented: three Classic stages, eight power mechanics, hidden exits/contact/timer/penalty,
one 41×31 Adventure, smooth camera, fog/maps, first secret/collection, compatible settings saves.
Not implemented: 50 Classic stages/bonus rounds, 40 authored Adventure levels/bosses, nine other
secrets, final art/music/quality profiles, four-player/co-op/online, Steam integration.
Previous archives and branch history remain available. No main merge or Steam publication.
Next: owner Windows acceptance → observed fixes → Graphics Alpha and first-world authored content.
