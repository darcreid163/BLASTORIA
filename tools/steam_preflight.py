#!/usr/bin/env python3
"""Source-only Steam readiness preflight. PASS != ready to release."""
import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def inspect():
    errors = []
    checks = {}
    project = read("project.godot")
    checks["godot_4_5"] = '"4.5"' in project
    checks["project_name"] = 'BLASTORIA: Worlds of Chaos' in project
    checks["has_scene"] = (ROOT / "scenes/main.tscn").is_file()
    plan = read("scripts/core/release_plan.gd")
    limit = re.search(r"const LAUNCH_STAGES\s*:=\s*(\d+)", plan)
    checks["launch_scope_51"] = bool(limit and int(limit.group(1)) == 51)

    arcade = json.loads(read("resources/arcade/registry.json"))
    authored_arcade = sum(s.get("status") == "playable" for s in arcade.get("levels", []))
    campaign = json.loads(read("resources/campaign/chapter_one_maps.json"))
    authored_journey = len(campaign.get("maps", []))
    checks["arcade_registry_valid"] = len(arcade.get("levels", [])) == 100
    checks["campaign_authored_valid"] = authored_journey == 10

    locales = json.loads(read("localization/catalog.json"))
    expected = {"ru", "en", "ja", "ko", "zh_CN", "hi", "id", "th", "vi", "fr", "it", "de", "ar", "tr"}
    keys = [set(items) for items in locales.values() if isinstance(items, dict)]
    checks["locales_14"] = set(locales) == expected
    checks["translation_keys_agree"] = len(keys) == 14 and all(k == keys[0] for k in keys)
    checks["translations_nonempty"] = all(isinstance(v, str) and v.strip()
        for item in locales.values() for v in item.values()) if len(keys) == 14 else False

    presets = read("export_presets.cfg")
    checks["both_platform_presets"] = 'name="Windows Desktop"' in presets and 'name="Linux QA"' in presets
    checks["release_export_excludes_tests_and_docs"] = presets.count("docs/*,tests/*,tools/*") == 2
    checks["release_export_excludes_secret_source"] = presets.count("resources/arcade/secrets.json") == 2
    checks["release_export_excludes_private_sources"] = presets.count("resources/private/*") == 2

    for name, ok in checks.items():
        if not ok:
            errors.append(name)

    # The following are honest product gates, not CI assertions. Never infer
    # release readiness from the mere existence of config slots or exports.
    blockers = [
        f"Only {authored_journey} authored Journey layouts and {authored_arcade} playable Arcade stages; first launch targets 51 completed levels",
        "Actual Windows GUI/audio/input/controller/Steam Deck hardware acceptance not evidenced by this source-only audit",
        "Steamworks AppID, upload, storefront, content survey and Valve reviews not verified",
        "Steam Achievements/Cloud/Remote Play integration not verified",
        "Final secrets, localized linguistic review, artwork and end-to-end stage playtests incomplete",
        "Commercial name/trademark and rights clearance must be documented",
    ]
    return {
        "schema_version": 1,
        "build_version": re.search(r'config/version="([^"]+)"', project).group(1),
        "source_hygiene_pass": not errors,
        "checks": checks,
        "errors": errors,
        "scope": {"launch_stages": 51, "author_created_journey_layouts": authored_journey,
                  "playable_arcade_stages": authored_arcade, "text_locales": len(locales)},
        "steam_release_ready": False,
        "remaining_release_gates": blockers,
        "note": "Source-only report: Godot runtime QA, native hardware and Valve checks are separate.",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="steam_preflight_report.json")
    parser.add_argument("--strict-release", action="store_true", help="Fail unless complete commercial release gates are verified")
    args = parser.parse_args()
    report = inspect()
    destination = ROOT / args.output
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Steam preflight source hygiene: {'PASS' if report['source_hygiene_pass'] else 'FAIL'}")
    print(f"Release ready: {report['steam_release_ready']} | authored journey={report['scope']['author_created_journey_layouts']} | arcade={report['scope']['playable_arcade_stages']}")
    print(f"Unmet release gates: {len(report['remaining_release_gates'])}")
    return 1 if (not report["source_hygiene_pass"] or (args.strict_release and not report["steam_release_ready"])) else 0


if __name__ == "__main__":
    sys.exit(main())
