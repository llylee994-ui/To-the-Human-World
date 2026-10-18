"""新手引导隔离回归；无头布局/状态，不宣称原生画面或手机验收。"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'scripts/debug'))
from content_test_runtime import run

if __name__ == '__main__':
    raise SystemExit(run('ui.landscape.tests.OnboardingTest'))
