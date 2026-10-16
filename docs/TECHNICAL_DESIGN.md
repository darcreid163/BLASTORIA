# Technical Design — 0.5.0

The retained 0.4 systems are described first; active 0.5 architecture is in the additions section.

Status: Implemented; behavioral verification described in QA_REPORT.md.
Pinned engine: Godot 4.5.1 Standard, GL Compatibility. Target Windows x86_64.
This is a reproducible baseline, not a latest-version claim.

| Component | Responsibility |
| --- | --- |
| GameConfig + default.tres | Gameplay parameters, seed list, limits |
| GameState | Tick state, command execution, damage, pickups, match outcome |
| GridBoard | Typed terrain kinds, generation, blast footprint, connectivity |
| BombSystem | Stable bomb IDs, capacity, scheduled fire, iterative chain resolution |
| EnemyAI | Visible danger analysis, bounded BFS escape, simple wandering bomber |
| BoardView | Procedural Node3D meshes, animation, HUD-independent visual synchronization |
| InputRouter | Converts keyboard / device-specific gamepad input into commands |
| GameHUD | Menus, status and pickup notification; signals semantic UI actions |
| SaveManager | Versioned JSON, temp write, backup and bounded input reading |
| GameSettings | Validated volumes, fullscreen and conflict-free physical key map |
| LevelDefinition + tutorial.tres | Authored tutorial terrain, checkpoint, crate and exit |
| AudioManager | Ten WAVs, eight playback voices, Master/SFX/UI buses |
| main.gd | Scene composition and menu/game transitions |

Simulation uses `_physics_process` at 60 ticks/s. Timers are integer ticks. Visual interpolation
uses `_process` and cannot alter collision cells. GameState and systems are RefCounted and have
no scene references. A Node3D actor is never used as a bomb-owner identity.

Tick order: increment clock → expire old fire → resolve due/chain bombs → spawn drops → damage
→ commands in stable actor-ID order → damage → safe pickups → terminal result.
Bomb placement precedes movement. No diagonal motion. Movement cooldown limits cell transitions.
At the detonation tick an actor cannot evade by moving out before damage. Dead actors cannot act.
Moving into fire is fatal in the same tick. Exiting one's own bomb is permitted; reentry is blocked.

The whole detonation wave reads unchanged terrain; destructible cells are removed after the queue.
This makes coincident rays stop at the same crates. Bombs do not stop rays; they chain.
Destroyed crates produce at most one drop. Drops become visible and collectible after fire expires;
for this prototype they are fireproof. Arcade awards score once per destroyed crate / killed enemy / collected pickup. Fire ownership
tracks an expiry per owner per cell; extending enemy fire cannot extend expired player credit.

Arena tie is evaluated after all damage. Campaign death takes precedence over success.
Exit requires no living enemies. Classic/Adventure additionally require revealed exit and no pending
reinforcements. Three Classic levels or one Adventure level end in a terminal completion screen.
Restart reconstructs logical state and removes the old visual world. Pausing stops the model clock.

RNG is seeded; same build, seed and command sequence produce equal snapshots in tests.
Cross-engine / cross-platform lockstep, rollback netcode and online determinism are NOT certified.
Actor-ID collision priority is deterministic, but future competitive balance needs review.

AI danger respects walls and crates. BFS is bounded by map cells and conservative fuse deadlines.
It has no future-space-time simulation, no guaranteed survival, and no advanced enemy profiles yet.

Save schema v4: version, unlocked (0..2), language (ru/en), records by arcade rules ID, settings, artifact IDs.
v1/v2/v3 migrate in memory, preserving campaign/language/records. Reads at most 16 KiB; invalid primary
falls back to backup. Write temp → flush → backup valid prior primary → replace. After recovery,
corrupt primary is never copied over the valid backup. This is recovery-oriented, not a proof
against every OS/power failure. Unknown future versions block writes; invalid record entries are ignored.
ArcadeRun accepts each terminal stage once, accumulates active ticks/score and finalizes once.
Score records may come from defeat; fastest time requires complete success. Menu/pauses do not
advance ticks. Exiting to menu abandons the run. See ARCADE_ADDENDUM_RU.md for exact rules.

Tutorial is a fixed Resource-authored board without enemies. Exit opens after checkpoint,
lesson crate destruction and guaranteed range pickup; finishing does not unlock campaign progress.
GameState emits feedback events, never plays audio itself. AudioManager routes effects to SFX,
menu clicks to UI, and reserves empty Music/Ambience buses for future content. Low-priority
step/fuse/crate sounds may drop under voice saturation. Headless mode disables playback;
its tests check resources, events and buses. Audible playback requires graphical runtime QA.
Settings clamp finite volumes and validate a complete unique key map. Reserved shortcuts cannot
be rebound. InputRouter reinstalls events without duplicates; gamepads remain devices 0/1.
Settings pause the game; saving uses the existing backup path. No custom gamepad assignment yet.
Do not add empty managers merely to match the long-term specification.

## 0.4 additions

GameConfig Resource presets separate Classic and Adventure from unchanged Arcade v1.
Classic/Adventure enable lethal contact and eight abilities. BombSystem stores remote flag per bomb,
oldest-owner detonation and per-tick hit_cells to distinguish a new blast from lingering fire.
Each wave only punishes an exit already exposed before the wave. The timer uses level_ticks and
configurable ticks_per_game_second. Wardens spawn deterministically on safe distant cells;
queued reinforcement blocks victory. Enemy movement decisions run only when movement is due.
Patrol, bounded 256-node pursuit and crate-crossing Wardens are original behavior profiles.

Exploration owns last-observed terrain; radius-four BFS stops at walls/crates. Recompute on player
cell change or destruction, not every render frame. SecretManager owns order/failure/reveal/award;
threshold/order/reward/niche come from SecretDefinition Resource. State owns completion return phase;
SaveManager persists collection only. No scene reference is needed to reproduce secret conditions.
The completion epilogue clears hazards, disables bomb placement and freezes level_ticks; normal
movement tick continues. Collection emits once. Existing profile ownership disables repeated rewards.

FollowCamera applies exponential interpolation to an orthographic target and clamps the entire
projected ground footprint; aspect ratio contributes to clamp. BoardView batches static geometry
with MultiMesh and creates late-spawned actors on demand. ExplorationMap draws discovered tiles,
observed runes, revealed exit and player; it never drives simulation. Canvas anchors adapt the map
panels to the viewport. CompassBadge draws a rotating cosmetic needle in result/collection menus.

Profile v4 preserves v3 settings and adds validated artifact IDs. Ten old keyboard bindings are
extended with two free remote keys; JSON floats are normalized before duplicate checks. Non-finite
codes are rejected. Future-version write protection and backup recovery remain in place.
Classic carries permanent powers between stages, resets temporary immunity, and rolls retry score
back to stage entry. No mid-stage saves or classic profile progression are implemented yet.

## 0.5 additions — active architecture

MASTER_SPEC.md is now the consolidated 2.3 specification; the earlier text above describes
retained 0.4 behavior. Official Arcade/custom maps use GameState.start_map and GridBoard.load_map,
not procedural GridBoard.generate. BombSystem, EnemyAI, damage and pickup handling remain shared.
The map loader validates before changing the current state. Only explicitly stored bonuses spawn.
No exit mesh is built for these modes. Solo completion counts required enemies; timer and score stop
at terminal result. Custom duel shares the arena outcome rules and times out as a draw.

ArcadeLevelRegistry reads bundled JSON definitions and refuses planned slots. ArcadeProgressionManager
owns only official availability/results and checks the loaded definition fingerprint before accepting
completion. SaveManager is reused with a separate path and 64-KiB limit, leaving legacy profile v4
and its record namespace compatible. Custom records use a third file, capped at 200 versions.

CustomMapGenerator performs seeded Fisher-Yates placement on connected pillar terrain; it never
retries indefinitely. Exact requested counts/types are placed or configuration is rejected.
MapValidationService validates a strict data schema and graph reachability, not arbitrary Godot resources.
CustomMapLibrary bounds file size before JSON parsing, rejects unknown fields/types and path-like IDs,
writes temporary files then renames, and gives imports new local IDs. The editor supplies filesystem
paths only through the user's file chooser; map data cannot designate a destination path.
Fingerprinting recursively normalizes integral JSON floats and sorts dictionary keys before SHA-256.

CustomMapDocument owns bounded undo/redo snapshots and cell transactions. MapPreviewRenderer owns
2D rendering and cursor input. CustomMapEditor owns GUI/configuration/file dialogs, library operations
and playtest requests. main.gd owns transitioning to the common simulation and returning to the unchanged
editor document. No unimplemented Steam adapter or secret manager stub is advertised as working.
Future sharing adapters will call the same validated serialization boundary; no Steam-specific data is
required for a .blastmap file. Format 1 rejects secret payloads until their runtime is implemented.

## 0.5.5 — secret privacy

SealedData uses native AESContext (256-bit CBC + PKCS7), independent HMAC-SHA256 key, random IV,
and purpose separation; authentication precedes decryption. SecretDefinition loads the encrypted
active definition and public display fields; AchievementCatalog loads an encrypted planned catalog.
SaveManager v5 keeps ordinary settings/records in JSON and seals the owned-artifact array in vault.
Legacy identifiers normalize to an opaque token; legacy collection-bearing backups are sanitized
before replacement. Missing content prevents new rewards and blocks writes to an existing collection.
Player export excludes plaintext source registries, old semantic Resource and developer docs.
Keys reside in the offline client; this is not a trust boundary against the owner of the client.
See SECRET_PRIVACY.md for the threat model and empty-cwd exported-package verification.
