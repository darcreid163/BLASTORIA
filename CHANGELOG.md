# Changelog

## 0.2.1-dev — 2026-10-15

- Added solo Arcade with three fixed levels, one life, cumulative score and active-time clock.
- Added player-owned destruction credit, bounded time bonuses and exactly-once results.
- Added score record and independent fastest complete run, separated by rules version.
- Added profile v1 → v2 migration, record validation and future-schema write protection.
- Added localized rules/results screens and Arcade HUD.
- Lowered walls and front border after reviewing owner screenshots of 0.2.
- 83 automated checks including 36 new scoring, timing, persistence and Arcade integration cases.

## 0.2.0-dev — 2026-10-15

- Preserved original approved master prompt and unmodified prototype 0.1 in Git history.
- Split simulation, board, bombs, enemy decisions, presentation, input, HUD, configuration and saves.
- Integer 60 Hz simulation with 150-tick fuse and 30-tick fire lifetime.
- Iterative chain resolver, stable IDs, shared same-tick terrain snapshot, unique crate destruction.
- Main menu, pause/resume, deterministic retry, campaign progression and two-player arena.
- Three seeded campaign levels; rotationally symmetric arena generation.
- Capacity/range/speed pickups with limits and HUD feedback.
- Wall-aware AI danger map and bounded escape search before placement.
- RU/EN translations, keyboard bindings and basic device-separated D-pad/A bindings.
- Versioned save with temporary write and backup recovery; save errors surfaced.
- 47 automated checks, import validation, scene smoke test; Windows x86_64 export.

## 0.1 — imported unchanged

Four source files supplied by the owner; single-script prototype with procedural 3D geometry.
