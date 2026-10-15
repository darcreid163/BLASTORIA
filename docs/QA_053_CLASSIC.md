# BLASTORIA 0.5.3 — Classic Campaign 100: status / QA
Date: 2026-10-15. Base: 0.5.2 draft PR #5. This update is stacked; main is not changed.

## What is implemented in this branch
- 100 indexed Classic Campaign configurations / deterministic seeds; first 50 prize numbers exactly match the owner's eight category lists; stages 51–100 have a proposed fixed balanced continuation.
- Per-stage enemy count (2→9), AI step interval and map area (21×15→61×41), timer (200→380).
- Exactly one guaranteed sealed prize per Classic stage, instead of eight; ordinary random drops suppressed for this Classic preset. Adventure's own eight drops remain unchanged.
- Subsequent bomb blast hitting an already exposed uncollected prize removes it and adds two penalty enemies. Existing exposed-exit penalty remains.
- Timeout upgrades remaining Classic foes to aggressive fast wardens and adds the configured reinforcements once.
- Campaign menu starts/continues Classic 100; no duplicate Classic item on main menu; legacy 3-stage test campaign remains reachable through old Adventure action.
- Durable Classic progress (`user://classic_100_v1.json`): start with 3 lives, +1 each first stage clear (cap 9), −1 on death, carry ability rules, reserve .bak, recover from backup; show lives in HUD.
- Added a new Classic 100 regression group, rewrote prior tests assuming eight treasures per Classic stage, and updated the menu smoke expected results.
- Added the owner-facing v2.5 prompt at `docs/specs/MASTER_PROMPT_2_5_RU.md`, amended `docs/MASTER_SPEC.md`.

## Tests and limits
- Static integrity audit PASS: 100 configs, 50 pinned early awards, unique seeds, progressive enemy counts, stage-100 terminator, linked lives/HUD/QA, main menu route, single-prize behavior in source.
- **Godot runtime tests NOT EXECUTED** in this chat: no Godot executable and no internet access to install it. Do not report the preceding 0.5.1 baseline's 243 passes as a result for 0.5.3.
- No Windows/Linux export created for 0.5.3; no hardware run, no art pass or gameplay acceptance.
- 100 configuration rows are not 100 separately authored polished maps. They generate deterministic grid stages; each requires layout/tactical playtesting and final environmental artwork.
- Bonus rounds (every fifth stage) have markers in the data plan but dedicated mechanics are NOT yet implemented.
- Updated save system and Godot typed GDScript have not received parser/execution validation; treat as draft until tests run.

## Mandatory Work follow-up
1. Check out PR #6 head (0.5.3), run clean Godot import plus `godot --headless --path . --script res://tests/run_tests.gd` and menu smoke, repair any parser/runtime errors.
2. Verify existing PR #1–#5 regression suite. New tests cover 100-stage plan, pinned prizes, one sealed award, exposed-prize penalty, timeout AI, campaign lives and persistence.
3. Run a staged gameplay pass at levels 1, 5, 10, 25, 50, 75, 100, check repeated attempts, death and chapter balance.
4. Finalize original 2.5D artwork, manual geometry and bonus-round rules. Do not merge stacked draft PRs blindly.
