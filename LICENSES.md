# Resource provenance and license register

| Resource | Origin | Status |
| --- | --- | --- |
| Prototype 0.1 code | Owner-supplied ZIP, imported unchanged | Preserved in initial commit |
| 0.2–0.7.4 code, docs, procedural meshes and palettes | Created with AI assistance in this development session | No external game assets copied |
| Seventeen milestone SVG badges | Original geometric vectors generated in this session; locked state uses tint | Temporary original UI assets; no external icon pack |
| Ten WAV effects in assets/audio | Original mathematical synthesis via tools/generate_audio.py, deterministic noise, revised in 0.7.3 with per-cue envelopes and headroom checks; no sampled external recordings | Created with AI assistance; provisional sound design |
| Master prompts 1, 2.0, 2.3 and 2.4 | Owner-supplied texts | Exact archives retained; consolidated 2.5 with privacy and 0.6.0 addenda active |
| Godot 4.5.1 engine and export templates | Official godotengine/godot-builds release | Engine MIT notice in third_party/GODOT_LICENSE.txt |
| Engine bundled dependencies and default font | Official Godot distribution | Notices in third_party/GODOT_COPYRIGHT.txt |

Upstream notice sources:
https://raw.githubusercontent.com/godotengine/godot/4.5.1-stable/LICENSE.txt
https://raw.githubusercontent.com/godotengine/godot/4.5.1-stable/COPYRIGHT.txt

No third-party art/music/models were added, and no external art was copied. The 0.6.1 visual concept preview was created with the built-in image-generation tool; it is not bundled in the game.
There is no new open-source license grant for BLASTORIA project code in this change;
the owner's project licensing decision remains pending. Engine licensing is separate.
Name/trademark clearance and Steam AI disclosures require review before commercialization.

## Added text fonts in 0.7.0

Noto Sans, Noto Sans Arabic, Noto Sans Devanagari and Noto Sans Thai are distributed
under SIL Open Font License 1.1. Full notice: assets/fonts/OFL.txt. Official sources:
https://github.com/notofonts/noto-fonts/tree/main/hinted/ttf

Noto Sans CJK Japanese/Korean/Simplified Chinese are subset for bundled UI text;
modified families are renamed BLASTORIA Interface jp/kr/sc. License and copyright:
assets/fonts/OFL-CJK.txt. https://github.com/notofonts/noto-cjk/tree/main/Sans
Reproduction: tools/subset_ui_fonts.py --source-dir <official regular OTF directory>.
Hashes: docs/qa/font_sources.json. Subsets do not cover arbitrary user CJK text.
Include both OFL notices in player archives alongside Godot notices.

GuideBadge vector silhouettes (0.7.2) are original code-native drawings based on this project's procedural item/monster shapes; created with AI assistance, no external icon pack.
