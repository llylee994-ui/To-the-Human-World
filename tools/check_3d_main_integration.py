"""Real Lua business and UI callbacks with explicit headless adapters, never OS input.

Uses the existing isolated test dependency in .tmp/b1-python (lupa 2.6).
No game entry, native engine, disk save API, or player save is executed.
"""
from pathlib import Path
import argparse
import json
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tmp/b1-python'))
from lupa.lua54 import LuaRuntime, lua_type


def run(module):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def plain(value):
        if lua_type(value) != 'table':
            return value
        keys = list(value.keys())
        if keys and set(keys) == set(range(1, len(keys) + 1)):
            return [plain(value[i]) for i in range(1, len(keys) + 1)]
        return {str(k): plain(v) for k, v in value.items()}

    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value

    lua.globals().cjson = lua.table_from({
        'encode': lambda value: json.dumps(plain(value), ensure_ascii=False, allow_nan=False),
        'decode': lambda value: table(json.loads(value)),
    })
    lua.globals().print = lambda *args: print(*args, flush=True)
    lua.execute("package.path = ... .. '/scripts/?.lua;' .. ... .. '/?.lua;' .. ... .. '/?/init.lua'",
                ROOT.as_posix(), ROOT.as_posix(), ROOT.as_posix())
    lua.execute('''
        File=function() error("DISK SAVE API FORBIDDEN") end
        fileSystem=setmetatable({}, {__index=function() error("FILESYSTEM API FORBIDDEN") end})
        package.preload["urhox-libs/UI"]=function() return require "debug.fixtures.HeadlessUI" end
        package.loaded["debug.DeveloperMode"]=false
        local data=require "data.content"
        local ok,errors=data.Load();assert(ok,table.concat(errors or {},"\\n"))
        ok,errors=data.ValidateStage1();assert(ok,table.concat(errors or {},"\\n"))
    ''')
    entry = lua.eval('require')(module)
    if isinstance(entry, tuple):
        entry = entry[0]
    assert entry.Run(), module + ' returned failure'
    print('[PASS]', module, '(headless callbacks, not native acceptance)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--module', default='v035.lab35.tests.MainIntegration')
    run(parser.parse_args().module)
