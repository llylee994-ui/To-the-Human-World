"""Explicitly distinguish current shop contract from archived vertical UI checks.

The shop suite retains every business assertion, changes its removed tab selector
to the ship, and uses the new view navigation API. Legacy/mobile suites load the
fixed pre-r3 PlayView only inside the test Lua runtime; they do not accept r3 UI.
"""
from pathlib import Path
import argparse
import subprocess
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'scripts/debug'))
import run_b1
from content_test_runtime import run

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('suite', choices=['shop', 'legacy', 'mobile'])
    mode = p.parse_args().suite
    module = {'shop':'debug.NumericV02ShopTest', 'legacy':'debug.PlayFlowTest', 'mobile':'debug.MobileFrontendTest'}[mode]
    patches = {}
    if mode == 'shop':
        source = (ROOT / 'scripts/debug/NumericV02ShopTest.lua').read_text(encoding='utf-8')
        assert 'click("tab_shop")' in source and 'lockedView.model.Navigate("shop")' in source
        patches[module] = source.replace('click("tab_shop")', 'click("home.merchantShip")').replace('lockedView.model.Navigate("shop")', 'lockedView.Open("shop")')
        print('[Current r3 shop] two navigation selectors adapted; business assertions unchanged', flush=True)
    else:
        patches['ui.PlayView'] = subprocess.check_output(['git','show','e4d2862:scripts/ui/PlayView.lua'],cwd=ROOT).decode('utf-8')
        print('[ARCHIVED UI ONLY] fixed e4d2862 PlayView; checks backend compatibility, NOT new r3 UI', flush=True)
    original = run_b1.LuaRuntime
    def runtime(*args, **kwargs):
        lua = original(*args, **kwargs)
        for name, source in patches.items():
            lua.execute('local name,source=...; package.preload[name]=assert(load(source,"@explicit-test-adapter/"..name,"t"))', name, source)
        return lua
    run_b1.LuaRuntime = runtime
    try: return run(module, '3dbca09' if mode == 'legacy' else None)
    finally: run_b1.LuaRuntime = original

if __name__ == '__main__': raise SystemExit(main())
