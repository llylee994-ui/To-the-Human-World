"""Project regression batch with individual receipts; no engine, cloud, or player saves."""
from pathlib import Path
import json
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
LOGS = ROOT / 'logs/home-entry-r3'
RECEIPT = ROOT / 'docs/验证/evidence/home-entry-r3/regression.json'
COMMANDS = [
    ('home-entry', ['scripts/ui/landscape/tests/run_home_entry.py']),
    ('landscape-flow-migration', ['scripts/debug/run_landscape_flow.py']),
    ('landscape-entry', ['scripts/debug/run_landscape_flow.py', '--entry']),
    ('landscape-numeric', ['scripts/debug/run_landscape_flow.py', '--numeric']),
    ('numeric-runtime', ['scripts/debug/run_numeric_v02.py']),
    ('numeric-flow-schema2', ['scripts/debug/run_numeric_v02.py', '--flows']),
    ('numeric-shop', ['scripts/ui/landscape/tests/run_ui_contracts.py', 'shop']),
    ('numeric-startup', ['scripts/debug/run_numeric_v02.py', '--startup']),
    ('numeric-data-check', ['scripts/debug/generate_numeric_v02.py', '--check']),
    ('numeric-intervals', ['scripts/debug/check_numeric_runtime.py']),
    ('historical-order', ['-c', 'import sys;sys.path.insert(0,"scripts/debug");from content_test_runtime import run;raise SystemExit(run("debug.OrderFlowTest","3dbca09"))']),
    ('historical-single-use', ['scripts/debug/run_single_use_words.py', '--content-ref', '3dbca09']),
    ('historical-story', ['scripts/debug/run_story_content.py', '--content-ref', '3dbca09']),
    ('archived-vertical-ui-backend-only', ['scripts/ui/landscape/tests/run_ui_contracts.py', 'legacy']),
    ('archived-mobile-ui-backend-only', ['scripts/ui/landscape/tests/run_ui_contracts.py', 'mobile']),
]

def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, args in COMMANDS:
        start = time.monotonic()
        result = subprocess.run([sys.executable, '-X', 'utf8', '-B', *args], cwd=ROOT, capture_output=True)
        log = LOGS / (name + '.log')
        log.write_bytes(result.stdout + result.stderr)
        row = dict(name=name, command=args, exitCode=result.returncode, seconds=round(time.monotonic()-start, 2), log=log.relative_to(ROOT).as_posix())
        rows.append(row)
        print(name + ': ' + ('PASS' if result.returncode == 0 else 'FAIL') + ' ' + str(row['seconds']) + 's', flush=True)
        RECEIPT.write_text(json.dumps(dict(version='C-HOME-ENTRY-20261010-r3-v01', baseline='e4d2862', results=rows), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    return 0 if all(r['exitCode'] == 0 for r in rows) else 1

if __name__ == '__main__': raise SystemExit(main())
