"""Background-only real Lua logic with isolated file/UI adapters; not device acceptance."""
import sys
sys.dont_write_bytecode = True
from content_test_runtime import run
if __name__ == '__main__':
    module='debug.LandscapeFlowTest'
    if '--numeric' in sys.argv: module='debug.LandscapeNumericFlowTest'
    if '--migration' in sys.argv: module='debug.SaveV3MigrationTest'
    if '--entry' in sys.argv: module='debug.LandscapeEntryTest'
    raise SystemExit(run(module))
