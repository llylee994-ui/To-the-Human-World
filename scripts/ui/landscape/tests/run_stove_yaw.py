"""Compatibility command: verify direct stove entry after removal of its yaw."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "scripts/debug"))
from content_test_runtime import run
import run_b1

# An alive native preview may temporarily enable its opt-in evidence driver.
# Headless main initialization must retain the normal player flags.
original_runtime = run_b1.LuaRuntime
def isolated_runtime(*args, **kwargs):
    lua = original_runtime(*args, **kwargs)
    lua.execute('package.loaded["ui.landscape.DevChecks"]={hotspots=false,nativeProbe=false,hitFeedback=false,yawProbe=false,yawProbeAuto=false,stoveYawAuto=false}')
    return lua

if __name__ == "__main__":
    run_b1.LuaRuntime = isolated_runtime
    raise SystemExit(run("ui.landscape.tests.StoveYawEntryTest"))
