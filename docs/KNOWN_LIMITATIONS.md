# Known limitations / risk register

| Priority | Finding | Status / next action |
| --- | --- | --- |
| P1 validation gap | New 0.2.1 executable has not been run on Windows; screenshots confirm 0.2 menu/board | Owner acceptance required before calling Windows build verified |
| P2 | Visual readability/layout have not been inspected in a rendered window | Test desktop resolutions and camera occlusion |
| P2 | AI is conservative spatial search, may still trap itself | Add time-aware escape and enemy profiles |
| P2 | Keyboard rebinding and gamepad assignment UI absent | Planned 0.3; current devices fixed to indices 0/1 |
| P2 | No audio feedback, music or final character art | Planned; geometry is provisional |
| P2 | Three seeded technical levels, no authored tutorial/bosses | Planned Alpha content |
| P2 | Migration v1 → v2 tested; future versions protected from overwrite | Add another tested migration on the next schema change |
| P3 | HUD shows player-1 stats; no arena series score | Add dual HUD and round settings |
| Release gate | No Steam SDK, online play, Remote Play certification or 60 FPS measurements | Not claimed |
| Release gate | Name/trademark clearance and commercial plan not researched yet | Review before commercial release |

No known reproduced P0/P1 gameplay defect remains in the executed headless suite.
This does not certify absence of defects, Windows compatibility or gamepad usability.
No purchases, paid CI, Steam publication, access grants or repository visibility changes performed.

Arcade records are local, editable profile data, not an online anti-cheat leaderboard.
Current Arcade is three technical maps, with no mid-run save/resume. Scoring balance remains provisional.
