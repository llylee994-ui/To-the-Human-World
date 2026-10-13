"""Integration check using the existing explicit Lua/UI/time/File harness."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'scripts/debug'))
from content_test_runtime import run
import run_b1
original = run_b1.LuaRuntime
def isolated(*args, **kwargs):
    lua = original(*args, **kwargs)
    lua.execute('package.loaded["ui.landscape.DevChecks"]={hotspots=false,nativeProbe=false,hitFeedback=false,seasideProbe=false,homeHudProbe=false}')
    return lua
if __name__ == '__main__':
    run_b1.LuaRuntime = isolated
    raise SystemExit(run('ui.landscape.tests.HomeHudTest'))
