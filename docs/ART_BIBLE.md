# Art Bible — provisional

Status: Planned visual direction; temporary geometric implementation exists.
Style: stylized 3D viewed from a fixed-angle elevated orthographic camera with smooth position tracking in Adventure. One logical cell = one world unit.
Palette for prototype jungle ruins: dark green floor, desaturated moss stone, warm wooden crates.
Player 1 cyan crystal scout; player 2 golden scout; enemies coral. Geometric crystal silhouettes
are temporary original placeholders, not approved final character models.
Bombs dark blue with amber fuses. Fire is orange with a pale core, occupying the exact logical cell.
Locked exit muted; unlocked exit green. Pickups use text marks in addition to color.

Model names snake_case; actors should fit approximately 0.7 × 0.7 cell footprint, below 1 unit tall.
Avoid walls that occlude adjacent hazards. Use shared materials; no photographic textures or
third-party assets have been added. Final models, animation rigs, textures, particles and camera
accessibility settings remain Planned. Do not market temporary meshes as final artwork.

Visual acceptance: inspect 1280×800 and 1920×1080; verify HUD fits, danger cells remain visible,
actors can be distinguished, and wall occlusion never hides bombs. Not performed in this session.

0.4: static floor/wall meshes use MultiMesh batches. Three inlaid rune motifs and an original
eight-segment compass model are code-native geometry. Purple Wardens differ from coral enemies.
The animated compass badge is UI vector drawing. No external character or item artwork copied.
