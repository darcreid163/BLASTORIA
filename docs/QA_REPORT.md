# BLASTORIA Development Report

Date: 2026-10-15. Version: 0.2.1-dev. Stage: Prototype.
Test engine: Godot 4.5.1.stable.official.f62fdbde1, Linux x86_64, headless.

| Check | Result | Evidence |
| --- | --- | --- |
| Original master prompt bytes | Verified exact match to attachment | Byte comparison during packaging |
| Import existing working project | PASS | qa/import.txt |
| Import fresh source without .godot cache | PASS | qa/clean_import.txt |
| Automated behavioral/integration suite | 83 passed / 0 failed | qa/tests.txt |
| Main scene startup, 120 frames | PASS headless | qa/smoke.txt |
| Windows x86_64 release export | PASS | qa/export_windows.txt |
| Windows binary format | PE32+ GUI x86_64 | file inspection during export |
| Linux QA release export | PASS | qa/export_linux.txt |
| Exported Linux binary startup | PASS headless, no editor required | qa/exported_linux_smoke.txt |
| Previous 0.2 Windows startup/rendering | CONFIRMED by owner screenshots | Menu and active game scene visible |
| New 0.2.1 Windows startup and playthrough | NOT TESTED | No Windows / Wine runtime available |
| Rendered 0.2 screenshots reviewed | Partial | Owner attachments: menu and board; lower-wall occlusion observed |
| 0.2.1 visual acceptance | NOT TESTED | No X display; lower walls changed in source |
| Physical gamepads | NOT TESTED | No connected hardware |
| FPS / hardware performance | NOT MEASURED | Headless execution is not rendering performance |

Automated scope: hazard boundaries, blast blockers, chain reactions, one-time crate destruction,
limits, moves, independent actors, pause, defeat/victory/draw, finite campaign, pickups,
100 seeded arena topologies, deterministic replay, 25 seeded simulations, saves/backup,
actual menu scene and ten world restarts, translations.
Arcade adds 36 checks: ownership/deduplication of score, timed bonuses, active-time accounting,
three-stage totals, failed/completed records, v1 migration, invalid/future data, actual scene flow. See TEST_PLAN.md for manual acceptance.
Procedural reachability checks do not prove gameplay quality, controller usability or fair balance.

Fixed during this iteration: original frame-driven scheduling replaced; wall-blind AI danger
replaced; recursive chain processing removed; terminal state and reset made explicit;
backup corruption recovery preserves the valid backup on subsequent save. Initial export preset
was missing a Linux include_filter key; fixed and import/export rerun successfully.
Records loaded from JSON are normalized to integers after an initial round-trip test found
a numeric-type mismatch; the corrected suite passes.
No reproduced P0/P1 remains in executed scenarios. Windows validation remains a release blocker.

Implemented: solo Arcade with cumulative points/time and local records; three-level technical campaign, two-player arena, three powerups, menu/pause/results,
bounded AI escape search, RU/EN, basic D-pad/A input and profile recovery.
Not implemented: sound/music, final art, authored full campaign, bosses, online, Steam SDK,
custom key rebinding, full settings and match-series scoring.

Next: actual Windows and rendered play acceptance → fix observed defects → authored tutorial,
sound feedback, controller/settings work. Full commercial readiness is not asserted.
Owner involvement: run Windows archive and follow TEST_PLAN.md; no payment or account action needed.
