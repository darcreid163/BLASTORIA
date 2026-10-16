#!/usr/bin/env python3
"""Run the real Godot importer, behavioral suite, and scene smoke test."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--godot', default='godot')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
logs = root / 'docs' / 'qa'
logs.mkdir(exist_ok=True)
stages = [
    ('import', ['--import']),
    ('parse_tests', ['--check-only', '--script', 'tests/run_tests.gd']),
    ('tests', ['--script', 'tests/run_tests.gd']),
    ('smoke', ['--quit-after', '120']),
]
for name, flags in stages:
    try:
        result = subprocess.run([args.godot, '--headless', '--path', str(root), *flags],
                                capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
    output = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + result.stderr)
    (logs / (name + '.txt')).write_text(output, encoding='utf-8')
    failed = result.returncode != 0 or any(x in output for x in ['SCRIPT ERROR:', 'ERROR:', 'FAIL:'])
    if name == 'tests' and not re.search(r'RESULT: \d+ passed, 0 failed', output):
        failed = True
    print(f'{name}: {"FAIL" if failed else "PASS"}')
    if failed:
        print(output)
        sys.exit(1)
print('All verification stages passed.')
