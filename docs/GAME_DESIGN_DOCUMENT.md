# BLASTORIA — Prototype 0.4

Active specification: MASTER_SPEC.md (Master Development Prompt 2.0), preserved verbatim.
Original 2.5D tactical bomb arcade: cross-shaped explosions, destructible maze, safe retreat,
enemies, powerups, concealed exits and exploration. Final character/world assets remain original-art work ahead.

| Mode | Implemented slice | Rules document |
| --- | --- | --- |
| Training | Authored tutorial, no enemies | TEST_PLAN.md |
| Adventure | One 41×31 ruins maze, six enemies, discovery map, Ghost Compass | LEVEL_DESIGN.md / SECRET_DESIGN.md |
| Classic | Three 21×15 stages, eight powerups, hidden exit, timed penalty | CLASSIC_RULES.md |
| Arcade | Three legacy fixed stages, one life, score/time records | ARCADE_ADDENDUM_RU.md |
| Arena | Two local players, symmetric generated board | TECHNICAL_DESIGN.md |
| Legacy 0.3 campaign | Three technical 15×11 maps, old progress retained | Available inside Adventure menu |

The main Continue button currently restarts the available Adventure level; it does not restore
mid-level state. The legacy campaign has a separate Continue entry inside Adventure.
Classic power carry/death policy and per-stage score rollback are explicit in CLASSIC_RULES.md.
Four worlds × ten authored levels, four bosses, fifty Classic stages/bonus rounds, all ten secrets,
four-player arena, co-op, final art/audio and Steam integration remain roadmap goals.
No pay-to-win or secret purchases. Commercial pricing and publication require later review.
