"""Letter drawer through the real query/session; isolated widget host."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'scripts/debug'))
from content_test_runtime import run
if __name__ == '__main__':
    raise SystemExit(run('ui.landscape.tests.LetterDrawerTest'))
