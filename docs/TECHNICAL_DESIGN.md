# Technical Design — 0.2.1

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
Exit requires no living enemies; three levels end in a terminal completion screen.
Restart reconstructs logical state and removes the old visual world. Pausing stops the model clock.

RNG is seeded; same build, seed and command sequence produce equal snapshots in tests.
Cross-engine / cross-platform lockstep, rollback netcode and online determinism are NOT certified.
Actor-ID collision priority is deterministic, but future competitive balance needs review.

AI danger respects walls and crates. BFS is bounded by map cells and conservative fuse deadlines.
It has no future-space-time simulation, no guaranteed survival, and no advanced enemy profiles yet.

Save schema v2: version, unlocked (0..2), language (ru/en), records by arcade rules ID.
v1 migrates in memory, preserving campaign/language. Reads at most 16 KiB; invalid primary
falls back to backup. Write temp → flush → backup valid prior primary → replace. After recovery,
corrupt primary is never copied over the valid backup. This is recovery-oriented, not a proof
against every OS/power failure. Unknown future versions block writes; invalid record entries are ignored.
ArcadeRun accepts each terminal stage once, accumulates active ticks/score and finalizes once.
Score records may come from defeat; fastest time requires complete success. Menu/pauses do not
advance ticks. Exiting to menu abandons the run. See ARCADE_ADDENDUM_RU.md for exact rules.

Next separation only as needed: typed ActorState, data-authored LevelDefinition, AudioManager,
settings/rebinding. Do not add empty managers merely to match the long-term specification.
