"""Real Lua business with isolated File/UI adapters; no player progress or engine launch."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / 'scripts/debug'))
from content_test_runtime import run
import run_b1
_runtime = run_b1.LuaRuntime
def isolated_runtime(*args, **kwargs):
    lua = _runtime(*args, **kwargs)
    lua.execute('package.loaded["ui.landscape.DevChecks"]={}')
    return lua
if __name__ == '__main__':
    run_b1.LuaRuntime = isolated_runtime
    raise SystemExit(run('ui.landscape.tests.BrewWorkbenchTest'))
