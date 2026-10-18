"""Isolated responsive contracts. Never launches a window or accesses player saves."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / 'scripts/debug'))
from content_test_runtime import run
import run_b1

original = run_b1.LuaRuntime
def runtime(*args, **kwargs):
    lua = original(*args, **kwargs)
    lua.execute('package.loaded["ui.landscape.DevChecks"]={}')
    return lua

if __name__ == '__main__':
    run_b1.LuaRuntime = runtime
    raise SystemExit(run('ui.landscape.tests.ResponsiveTest'))
