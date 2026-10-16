# 0.7.3-dev — hazard and event feedback

- Ordinary bombs display four remaining-fuse divisions; remote bombs have a distinct
  cyan antenna and steady markers instead of a misleading countdown.
- View-only animated fire stays exactly on logical hazardous cells and disappears
  when those cells expire. Signal materials retain readable colors under lighting.
- Short local crate/pickup/death cues are capped at 24 groups, freeze with simulation
  time and clear on restart. Added restrained actor/item motion.
- Re-synthesized ten original PCM effects with quieter steps, a double fuse tick,
  clearer result/pickup phrases and checked fade boundaries. No third-party samples.
- Eight-voice pool evicts the oldest least-important cue; steps/fuses cannot cut
  higher-priority result/death/UI cues. Volume buses and settings remain effective.
- No map/rule/save-schema changes. Existing chapter input replays retain exact score
  and active ticks. Automated PCM format/headroom/reproducibility checks join verify.py.

# 0.7.2-dev — 2026-10-16

- Field guide: eight bonus silhouettes/effects and four current enemy roles; available
  from home Training and pause, preserving the active attempt.
- Arcade HUD now displays active powers, capacity/range and the configured remote key;
  pickup explanations use a readable panel, and retries clear old notifications.
- Result breakdown shows actual destroyed crates, kills, pickups and completion/time
  bonuses; real fatal events supply blast/contact/time-limit explanations.
- Player-one controller X quickly repeats a result. Other controller input cannot
  reset the solo attempt. This is synthetic event QA, not physical hardware approval.
- Co-op chasers/wardens now pursue the surviving human after player one dies.
- Import verification uses Godot --import to wait for asset jobs before quitting.
- New texts covered in all 14 languages. Human balance/localization/Windows acceptance
  remains pending. Authored stages, official score rules and record fingerprints unchanged.

# 0.7.1-dev — 2026-10-16

- Seven new fixed authored Arcade maps complete chapter one (stages 1–10).
- Existing stages 1–3 are byte-for-byte preserved; record keys remain compatible.
- Stage selection is a ten-tile grid with locked progression and focus on the latest available stage.
- All ten titles localized into 14 languages; bundled CJK coverage regenerated.
- Seven successful ordinary-input replays with live enemy AI verify reachability, exact score/time,
  independent records, replay determinism and progression; no actor/board mutations during replay.
- Automated completion is not a human balance or target-device acceptance claim.

# 0.7.0-dev — 2026-10-16

- Three primary modes: Arcade, Arena, Adventure; saved Journey inside Adventure.
- Separate Workshop: solo, co-op, duel and solo vs bots; public format 2 without private
  fields; legacy map reads and exports remain compatible. Shared co-op scoring/contact.
- Fourteen text languages, searchable native/localized names, persistent choice, RTL,
  Noto font subsets and localized file picker; no map text/undo reset on language change.
- Original miner and four monster role models, eight distinct item shapes, light/shadows,
  three-card home menu and styled HUD. Procedural prototype, not final production art.
- Official local discoveries now function in all three modes; Workshop isolated.
- 431 checks and actual Linux exported-package QA pass; Windows export succeeds.
  Native Windows/controller and linguistic acceptance remain pending.
- Steam market comparison, price proposal and launch checklist are documentation;
  no Steam publication or pricing change performed.

# 0.6.1-dev — 2026-10-16

- Решение владельца: 51 уровень в первом релизе, оставшиеся 49 — последующие обновления.
- Общая граница официальных последовательностей; Кампания заканчивается на 51-м,
  прямой старт 52-го запрещён. Старые профили выше границы сохраняются без обрезания.
- Исправлены числа в меню/результатах; запланированное не названо готовым.
- Зафиксированы логика режимов, оригинальный шахтёр, восемь монстров, восемь бонусов.
- Новая десятка пасхалок ИИ/посвящение создателям жанра заменяет прежний проектный список;
  условия, визуалы, подсказки и границы реализации в docs/design. В player export отсутствует.
- Внешность и новые испытания пока дизайн; текущие модели/прототип секрета сохранены.
- 336 поведенческих проверок проходят, включая восемь новых проверок релизной границы.

# 0.6.0-dev — 2026-10-16

- Add seventeen event-derived local achievements, original SVG badges, paged UI and notifications.
- Save encrypted offline progress/pending sync queue with delta deduplication and recovery.
- Track actual player actions/credit and causal bomb chains; independent fuses are separate chains.
- Qualify Arena matches and separate user-map/test events from official mastery counters.
- Ship active public definitions only; future/hidden definitions remain in developer sources.
- Combine runtime content into a padded encrypted bundle; seal display text separately and remove semantic item hints from runtime names.
- Preserve v5 collection and Campaign/Arcade/Workshop behavior. Steam/server remain unconnected.

# 0.5.5-dev — 2026-10-16

- Continue from 0.5.4, preserving ten authored Campaign stages and rules 2.5.
- Consolidate full owner prompt 2.4 and anti-spoiler requirements with latest specification.
- Encrypt active secret/milestone data and owned-artifact storage; migrate legacy collection IDs/backups.
- Exclude plaintext secret/achievement registries and developer spoilers from player distribution.
- Show only discovered public names/descriptions; remove pre-discovery localization metadata and totals.
- Authenticate before decrypting; corrupted/missing data cannot grant awards or overwrite existing collection.
- Independently check crypto interoperability and exported package from an empty folder.

# 0.5.1-dev — 2026-10-15

- Установлен согласованный порядок десяти пунктов главного меню.
- Добавлен отдельный вход в существующую Кампанию с началом/продолжением.
- Исправлены перепутанные RU/EN столбцы строк Classic/Adventure/Secret collection и связанных текстов.
- Названия меню сокращены до согласованных; Мастерская получила ключ локализации.

# 0.5.0-dev — 2026-10-15

- Adopt consolidated Master Prompt 2.3; archive exact 2.0/2.3 attachments.
- Add three authored official Arcade stages, ten-theme/100-slot registry, sequential unlocks,
  per-stage rules fingerprints, no-exit victory and fixed planned secret registry.
- Add base Workshop generator/editor, local map library, strict .blastmap import/export,
  shared-simulation playtests and isolated custom records/duels.
- Default player one to arrows; migrate unchanged defaults while preserving custom keys.
- Fix JSON integer/float fingerprint mismatch found by file roundtrip tests.
- Planned levels, official secrets and Steam Workshop remain explicitly incomplete.

# Changelog

## 0.4.0-dev — 2026-10-15

- Adopted verbatim owner Master Development Prompt 2.0, preserved prior spec and builds.
- Added Classic preset: three stages, range 1, concealed exit, contacts, 200-second timer and Wardens.
- Added all eight power mechanics, remote controls, carry/death policy and score rollback on retry.
- Added 41×31 Adventure with seeded sector spines, six enemies and instanced static geometry.
- Added clamped smooth camera, explored-area minimap/expanded map and off-screen simulation checks.
- Added Ghost Compass conditions, return-to-niche phase, original model, cosmetic badge and collection.
- Added profile v4 migration; fixed numeric key collision handling for old JSON profiles.
- Original Arcade rules/records remain separate; old technical campaign remains accessible.
- Nine other secrets, full campaign, 50 Classic stages, bonus rounds and final art remain planned.

## 0.3.0-dev — 2026-10-15

- Added authored tutorial with safe bomb lesson, guaranteed pickup and gated exit.
- Added ten original synthesized sound effects and pooled audio playback.
- Added master/SFX/UI volume, saved fullscreen and keyboard rebinding for both players.
- Added profile v3 migration preserving campaign progress and Arcade records.
- Added localized settings/tutorial UI and controls reflected in the HUD.
- 123 automated checks; headless execution validates assets/events, not audible output.
- Windows runtime, hearing, rendered layout and physical gamepad acceptance remain pending.

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
