"""Apprentice presentation through real transactions with explicit headless adapters."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'debug'))
from content_test_runtime import run
if __name__ == '__main__':
    raise SystemExit(run('ui.landscape.tests.ApprenticeViewTest'))
