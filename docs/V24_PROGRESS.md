# BLASTORIA 0.5.2 (draft) — v2.4 offline foundation

Base: `codex/menu-ru-0.5.1` (PR #4), stacked on prior development PRs. This is **not** a release and has not been run under Godot in this chat.

## Implemented in this draft
- Existing main menu order (Training, Campaign, Adventure, Classic, Arcade, Workshop, Arena, Secret Collection, Settings, Exit) remains intact.
- Official Arcade selector now has an additional **Stage records** screen. It reads real local records from `ArcadeProgressionManager.save`, shows only authored/playable stages and displays best score and best completion time. No fake world scores.
- Secret Collection opens an optional submenu: **My discoveries**, **First discoverers hall**, **Achievements**.
- My discoveries displays only already collected prototype artifacts; there is no total secret count, unopened slots, or discovery percentage.
- The worldwide hall explicitly reports that verified server-backed discovery is *not yet connected*, and never fabricates its occupants.
- A data-only, versioned registry includes the 37 achievement definitions specified in v2.4: 8 campaign, 8 Arcade, 7 mastery, 5 arena, 5 workshop, 4 hidden secret achievements. Russian and English titles/descriptions are present.
- `AchievementCatalog.player_visible_entries()` filters locked hidden achievements. No Steam achievement has actually been granted.
- Added five Godot regression assertions for registry structure, uniqueness, hidden counts and disclosure behavior.

## Still planned / not claimed
- Actual Steamworks initialization, achievements and leaderboards, physical devices and SteamOS testing.
- Real worldwide leaderboard and an authenticated, audited first-discovery service.
- Verified server-side anti-cheat/replay validation.
- Persistent personal *official* Arcade secret collection (the current collection still contains the Adventure prototype Compass only).
- Godot project import, compile, gameplay and automated test execution of this branch; Godot is unavailable in this chat's shell.
- Authoring Arcade stages 4–100 and adding the first official secret on stage 9.

## Global first-discovery rules (design requirements, not implemented)
- Public APIs return only globally confirmed discoveries; never enumerate secrets not yet discovered.
- Server authenticates player identity; never trust a client-supplied SteamID.
- Verify the run/conditions with an independently trusted source before assigning a world-first record.
- Define a unique database constraint over `secret_id`. Use a transaction and server confirmation time for concurrent claims.
- Offline discoveries may enter a player's local collection but never reserve world-first retroactively.
- Subsequent finders get personal collection entries, not additional world-first records.
- A verified world-first is durable; moderator correction requires a logged, exceptional procedure.
- User-generated maps do not grant official world-first claims or official Arcade leaderboard credit.
- Secret counts are intentionally hidden in the game UI. Asset reverse engineering cannot be fully prevented merely by hiding UI entries.

## Offline records rules
- A record key is a rules-scoped fingerprint of the official authored map, consistent with v0.5.
- Local records are neither worldwide verified scores nor competitive anti-cheat evidence.
- Other future world/friends scopes must not be depicted as connected before Steamworks integration.

## Validation status
- Previous baseline (PR #4): **243 passed / 0 failed** in its own Godot environment. Not rerun here.
- This branch: local source/registry review and integrity assertions only. Newly added Godot tests are **not run** until Godot is available.
- Must run: `godot --headless --path . --script res://tests/run_tests.gd` (use actual installed binary / version), followed by clean import and main scene smoke. Verify exported builds and physical devices separately.

## Next implementation
1. Execute complete Godot regression, inspect runtime UI translations and possible clipping after adding menus.
2. Introduce local `AchievementProgress` and wire events incrementally to real validated game results; keep global first-discovery achievement server-gated.
3. Implement authenticated server proof protocol for first-discoverers before showing a global hall.
4. Continue authoring stages 4–10 and implement the actual stage-9 Compass secret.
