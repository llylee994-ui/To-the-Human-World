"""Scoped hit/feedback checks using the existing isolated Lua/File harness."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'scripts/debug'))
from content_test_runtime import run
import run_b1

# The foreground Maker may be recording evidence with its opt-in probe enabled.
# This isolated process has no native UI and must always test the player flags.
original_runtime = run_b1.LuaRuntime
def isolated_runtime(*args, **kwargs):
    lua = original_runtime(*args, **kwargs)
    lua.execute('package.loaded["ui.landscape.DevChecks"]={hotspots=false,nativeProbe=false,hitFeedback=false}')
    return lua

if __name__ == '__main__':
    run_b1.LuaRuntime = isolated_runtime
    if '--home' in sys.argv:
        raise SystemExit(run('ui.landscape.tests.HomeEntryTest'))
    raise SystemExit(run('ui.landscape.tests.HitFeedbackTest'))
