"""Release rules with real Lua modules and isolated File/UI adapters; no game startup.

Use --lua-deps for an existing lupa installation, --engine-libs for existing
read-only urhox-libs when running UI checks. No dependency installation or player save IO.
"""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=('gates', 'route', 'flow', 'endings', 'saves', 'closing', 'ui', 'calendar', 'presentation', 'presentation-ui', 'audit', 'reuse', 'storage', 'purchases', 'schedule'), default='gates')
    parser.add_argument('--lua-deps', type=Path, default=ROOT / '.tmp/b1-python')
    parser.add_argument('--engine-libs', type=Path, default=ROOT)
    parser.add_argument('--filter', help='Run matching named scenarios (endings/UI only)')
    args = parser.parse_args()
    if args.filter and args.suite not in ('endings', 'ui'):
        parser.error('--filter is only supported for endings/UI scenarios')
    sys.path.insert(0, str(args.lua_deps.resolve()))
    from lupa.lua54 import LuaRuntime, lua_type

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("package.path = ... .. '/scripts/?.lua;' .. package.path", ROOT.as_posix())
    lua.execute("package.path = package.path .. ';' .. ... .. '/?.lua'", args.engine_libs.resolve().as_posix())

    def plain(value):
        if lua_type(value) != 'table':
            return value
        keys = list(value.keys())
        if keys and set(keys) == set(range(1, len(keys) + 1)):
            return [plain(value[i]) for i in range(1, len(keys) + 1)]
        return {str(key): plain(value[key]) for key in keys}

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({key: table(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(item) for item in value])
        return value

    lua.globals().cjson = lua.table_from({
        'encode': lambda value: json.dumps(plain(value), ensure_ascii=False, allow_nan=False),
        'decode': lambda raw: table(json.loads(raw)),
    })
    lua.globals().print = lambda *values: print(*values, flush=True)
    lua.globals().RELEASE_ENDING_FILTER = args.filter
    lua.globals().RELEASE_UI_FILTER = args.filter
    lua.execute('''
        package.preload["urhox-libs/UI"] = function() return require "debug.fixtures.HeadlessUI" end
        package.loaded["debug.DeveloperMode"] = false
        graphics = {}
        local Data=require "data.content"
        local ok,errors=Data.Load();assert(ok,table.concat(errors or {},";"))
        local ready,problems=Data.ValidateStage1();assert(ready,table.concat(problems or {},";"))
    ''')
    modules = {'gates': 'ReleaseDayGateTest', 'route': 'ReleaseDayGateTest', 'flow': 'ReleaseFlowTest',
               'endings': 'ReleaseEndingTest', 'saves': 'ReleaseEndingSaveTest',
               'closing': 'ReleaseClosingIntegrationTest', 'ui': 'ReleaseUITest', 'calendar': 'CalendarIntegrationTest',
               'presentation': 'EndingPresentationTest', 'presentation-ui': 'EndingPresentationUITest',
               'audit': 'LetterTokenAuditTest',
               'reuse': 'ValidationReuseTest',
               'storage': 'SaveLatencyCompatibilityTest',
               'purchases': 'ReleasePurchaseTest', 'schedule': 'ReleaseScheduleTest'}
    print(f'[ReleaseRules] suite={args.suite}; filter={args.filter or "all"}; adapter checks, not native acceptance', flush=True)
    lua.execute('local name,method=...;assert(require(name)[method]())',
                'debug.' + modules[args.suite], 'RunFull' if args.suite == 'route' else 'Run')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
