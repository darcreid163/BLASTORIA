# Known limitations / risk register

| Priority | Finding | Status / next action |
| --- | --- | --- |
| P1 validation gap | Windows executable has not been run on Windows | Owner acceptance required before calling Windows build verified |
| P2 | Visual readability/layout have not been inspected in a rendered window | Test desktop resolutions and camera occlusion |
| P2 | AI is conservative spatial search, may still trap itself | Add time-aware escape and enemy profiles |
| P2 | Keyboard rebinding and gamepad assignment UI absent | Planned 0.3; current devices fixed to indices 0/1 |
| P2 | No audio feedback, music or final character art | Planned; geometry is provisional |
| P2 | Three seeded technical levels, no authored tutorial/bosses | Planned Alpha content |
| P2 | Save schema future migrations not implemented | Preserve v1 identity and add tested migration when schema changes |
| P3 | HUD shows player-1 stats; no arena series score | Add dual HUD and round settings |
| Release gate | No Steam SDK, online play, Remote Play certification or 60 FPS measurements | Not claimed |
| Release gate | Name/trademark clearance and commercial plan not researched yet | Review before commercial release |

No known reproduced P0/P1 gameplay defect remains in the executed headless suite.
This does not certify absence of defects, Windows compatibility or gamepad usability.
No purchases, paid CI, Steam publication, access grants or repository visibility changes performed.
