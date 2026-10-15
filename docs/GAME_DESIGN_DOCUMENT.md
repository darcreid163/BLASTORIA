# Game Design Document — Prototype 0.2

Vision: original tactical maze arcade, equal attention to campaign and local battles.
Long-term target is BLASTORIA: Worlds of Chaos on Windows/Steam. Full scope remains in MASTER_PROMPT_RU.md.

Core loop: read the maze → place a bomb → retreat → exploit opened paths / drops → eliminate threats.
Controls must stay readable; blast footprint is a cross and walls stop it.

Current playable scope: three repeatable seeded expeditions, one local two-player arena generator.
Campaign grows from 1 to 3 bomber enemies. Defeat every enemy and reach the exit.
These are technical levels, not the promised 40-level authored campaign.
Arena: last survivor wins; same-tick simultaneous death is a draw. Retry repeats the map;
return to menu and reenter arena advances the map seed. No round scoreboard yet.

| Parameter | Default / cap |
| --- | --- |
| Grid | 15 × 11 |
| Bomb fuse | 2.5 s |
| Fire lifetime | 0.5 s |
| Range | 2 / 6 cells |
| Capacity | 1 / 5 bombs |
| Move period | 9 / minimum 5 simulation ticks |
| Enemy move period | 25 ticks |
| Crate drop probability | 30% |

The three drops are +B capacity (blue), +R radius (orange), +S speed (violet).
Labels provide a cue beyond color. They last until collected, survive fire and become visible when safe.
Basic stats reset on each level/round; progression saves the highest unlocked level.

Planned: first authored jungle level and tutorial, sound feedback, rebinding, device assignment,
several distinct enemy profiles, 10-level Alpha; only then world art/boss vertical slice.
Full campaign target: jungle, ice fortress, volcano and cybercity; 10 levels and one boss per world.
No online, co-op, treasure hunt, alternate bomb types, Steam achievements or store monetization yet.
No pay-to-win or ads. Price is a future product decision, not a commitment from this prototype.
