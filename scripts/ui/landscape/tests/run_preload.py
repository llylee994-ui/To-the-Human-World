"""启动预加载专项；Lua 端口测试 + 清单文件存在性检查，不读玩家存档。"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'scripts/debug'))
sys.path.insert(0, str(ROOT / '.tmp' / 'b1-python'))
from content_test_runtime import run

SUITES = ('catalog', 'loader', 'entry', 'navigation')


def manifest_paths():
    from lupa.lua54 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    scripts = (ROOT / 'scripts').as_posix()
    lua.execute("package.path = ... .. '/?.lua;' .. ... .. '/?/init.lua;' .. package.path", scripts, scripts)
    module = lua.eval('require')('ui.landscape.PreloadManifest')
    if isinstance(module, tuple):
        module = module[0]
    entries = module.AllEntries()
    rows = []
    for i in range(1, len(entries) + 1):
        entry = entries[i]
        rows.append((entry.path, entry.type))
    return rows


def check_files():
    missing = []
    for path, kind in manifest_paths():
        local = ROOT / 'assets' / path
        if not local.exists():
            missing.append(str(local))
        elif not (ROOT / 'assets' / (path + '.meta')).exists():
            missing.append(str(local) + '.meta')
    if missing:
        raise SystemExit('missing preload assets:\n' + '\n'.join(missing))
    print('[PreloadCatalog] PASS manifest files and meta exist')


def run_suite(suite):
    if suite == 'catalog':
        code = run('ui.landscape.tests.PreloadTest', flags={'PRELOAD_SUITE': 'catalog'})
        if code == 0:
            check_files()
        return code
    if suite == 'loader':
        return run('ui.landscape.tests.PreloadTest', flags={'PRELOAD_SUITE': 'loader'})
    return run('ui.landscape.tests.LoadingEntryTest', flags={'PRELOAD_SUITE': suite})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=SUITES + ('all',), default='all')
    args = parser.parse_args()
    suites = SUITES if args.suite == 'all' else (args.suite,)
    failed = False
    for suite in suites:
        print('[Preload] suite=' + suite, flush=True)
        if run_suite(suite) != 0:
            failed = True
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
