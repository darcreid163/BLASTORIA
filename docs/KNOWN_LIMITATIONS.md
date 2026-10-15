# Known limitations — 0.4

| Priority | Finding | Next action |
| --- | --- | --- |
| P1 validation gap | New executable exported but not run on native Windows; only older 0.2 owner screenshots exist | Windows acceptance before release |
| P2 validation gap | No rendered-window/audio/gamepad QA in this environment | Check layouts, occlusion, map/camera edges, sound and physical devices |
| P2 content | One large technical Adventure level and three Classic stages | Authored first-world rooms and levels; then full 40/50-stage scope |
| P2 content | One of ten secrets implemented; nine require future mechanics/worlds | Chain-heart and crown next; do not claim all ten work |
| P2 Classic fidelity | Timer tempo/penalty counts/score/death policy are explicit BLASTORIA choices, not certified NES emulation | Historical preset verification; bonus rounds and life bank |
| P2 controls | Two gamepads fixed to devices 0/1; keyboard maps configurable | Device assignment and 2–4 player UX |
| P2 visuals | Temporary original geometric characters, simple effects, no quality presets/music | Graphics Alpha and original world audio |
| P2 AI | Bounded spatial pursuit and conservative hazard avoidance, no temporal planner | Gameplay balancing and richer profiles |
| P2 design | Eight guaranteed powers clustered in a test strip; compass tested using developer fixture, not organic human discovery | Authored distribution and human playtest |
| P3 saves | Collection/settings/legacy progress/Arcade records persist; no mid-level or Classic series save | Versioned Adventure/Classic progression |
| Release gate | No measured rendering FPS, Steam integration, commercial/IP clearance | Hardware/performance and release checklist |

182 behavioral/integration checks passed with no reproduced blocking defect in those scenarios.
Headless tests are not proof of usability, absence of all bugs or Windows runtime compatibility.
Map remains live during exploration; Esc pauses. Single-attempt prototype uses manual retries.
Old builds remain archived; profile v4 is protected from overwrite by older versions with the future-schema guard.
