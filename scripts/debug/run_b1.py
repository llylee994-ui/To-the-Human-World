"""Lua 5.4 tests with explicit File/cjson/UI adapters; NOT an engine/UI test.

Dependency (isolated): python -m pip install --target .tmp/b1-python lupa==2.6
Run from any directory: python scripts/debug/run_b1.py
"""
from pathlib import Path
import json
import sys
import tempfile
import argparse

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".tmp" / "b1-python"))
from lupa.lua54 import LuaRuntime, lua_type


def main(argv=None, entrypoint=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--b6-acceptance', action='store_true', help='Check real entry binds every debug operation to a B6 slot')
    parser.add_argument('--numeric-v02-startup', action='store_true', help='Check default trial startup protects old slot1')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--config-failure", choices=("load", "c1", "stage1"))
    mode.add_argument("--debug-isolation", choices=(
        "existing", "missing", "flow_missing", "v2_corrupt",
        "auto_write", "auto_read", "auto_read_flow_missing", "auto_read_v2_corrupt",
    ))
    args = parser.parse_args(argv)
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("package.path = ... .. '/scripts/?.lua;' .. package.path", ROOT.as_posix())

    def from_lua(value):
        if lua_type(value) != "table":
            return value
        keys = list(value.keys())
        if keys and set(keys) == set(range(1, len(keys) + 1)):
            return [from_lua(value[i]) for i in range(1, len(keys) + 1)]
        return {str(k): from_lua(value[k]) for k in keys}

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({k: to_lua(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(v) for v in value])
        return value

    with tempfile.TemporaryDirectory(prefix="b1-files-", dir=ROOT / ".tmp") as directory:
        storage = Path(directory).resolve()
        assert storage.is_relative_to((ROOT / ".tmp").resolve()), "test cleanup must stay in project .tmp"

        class TestFile:
            def __init__(self, name, mode=0):
                assert "/" not in name and "\\" not in name, "only isolated flat test paths"
                self.path = storage / name
                self.open = mode == 1 or self.path.exists()
                if mode == 1:
                    self.path.write_text("", encoding="utf-8")
            def IsOpen(self): return self.open
            def WriteString(self, text):
                self.path.write_text(text, encoding="utf-8")
                return True
            def ReadString(self): return self.path.read_text(encoding="utf-8")
            def Close(self): self.open = False
            def Flush(self): pass

        class TestFileSystem:
            def FileExists(self, name): return (storage / name).exists()
            def Delete(self, name):
                (storage / name).unlink(missing_ok=True)
                return True

        g = lua.globals()
        g.File, g.FILE_READ, g.FILE_WRITE = TestFile, 0, 1
        g.fileSystem = TestFileSystem()
        g.cjson = lua.table_from({
            "encode": lambda v: json.dumps(from_lua(v), ensure_ascii=False, allow_nan=False),
            "decode": lambda s: to_lua(json.loads(s)),
        })
        g.print = lambda *args: print(*args, flush=True)
        g.B1_CONFIG_FAILURE = args.config_failure
        g.B1_ISOLATION_SCENARIO = args.debug_isolation
        g.B6_ACCEPTANCE_CHECK = args.b6_acceptance
        if args.b6_acceptance:
            (storage / 'save_slot1.json').write_text('B6 default-slot canary', encoding='utf-8')
        if args.numeric_v02_startup:
            (storage / 'save_slot1.json').write_text('old progress canary', encoding='utf-8')
        lua.execute('''
            package.preload["urhox-libs/UI"] = function() return require "debug.fixtures.HeadlessUI" end
            graphics = {}
            function SubscribeToEvent(...) end
            KEY_Z, KEY_F6, KEY_F7, KEY_F8 = 1, 2, 3, 4 -- 仅替身枚举
            if B6_ACCEPTANCE_CHECK then
                package.loaded["debug.B6RunRequest"] = "b6_acceptance_test"
            end
            if B1_ISOLATION_SCENARIO then
                B1_ISOLATION_CONTEXT = require("debug.DebugIsolationTest").Prepare(B1_ISOLATION_SCENARIO, true)
            end
            if B1_CONFIG_FAILURE then
                local Data = require "data.content"
                if B1_CONFIG_FAILURE == "load" then
                    Data.Load = function() return false, {"B1 injected Data.Load failure"} end
                elseif B1_CONFIG_FAILURE == "c1" then
                    Data.stage1.initialEconomy.currency = nil
                else
                    Data.ValidateStage1 = function() return false, {"B1 injected Data.ValidateStage1 failure"} end
                end
            end
            require "main"
            Start()
        ''')
        if args.numeric_v02_startup:
            lua.execute('''
                local state = GetGameSession().state
                assert(state.GetStatus().status == "new")
                assert(state.NextDay().ok)
                assert(state.ReloadCurrent())
                assert(state.GetStatus().status == "loaded")
                assert(state.GetSnapshot().live.gameFlow.day == 2)
            ''')
            assert (storage / 'save_slot1.json').read_text(encoding='utf-8') == 'old progress canary'
            assert not list(storage.glob('save_slot1_*.json'))
            assert list(storage.glob('save_numeric_v02_trial_*.commit'))
            print('[NumericV02 startup] PASS real main default slot + save/reload; old progress unchanged; File/UI adapters')
            return 0
        if args.b6_acceptance:
            lua.execute('''
                local session = GetGameSession()
                local state = session.state
                assert(state.GetStatus().status == "new")
                local before = state.GetSnapshot().live.gameFlow.day
                assert(state.NextDay().ok)
                local root = require("urhox-libs/UI").root
                root:FindById("debugSaveButton"):GetProps().onClick()
                root:FindById("debugLoadButton"):GetProps().onClick()
                assert(state.GetStatus().status == "loaded")
                assert(state.GetSnapshot().live.gameFlow.day == before + 1)
                assert(state.ReloadCurrent())
                assert(root:FindById("debugTitleLabel"):GetText():find("b6_acceptance_test",1,true))
                print("[B6 entry] PASS startup + NextDay + debug save/load + reload bind same slot")
            ''')
            assert (storage / 'save_slot1.json').read_text(encoding='utf-8') == 'B6 default-slot canary'
            assert not list(storage.glob('save_slot1_*.json')), 'must not create default-slot snapshots'
            assert list(storage.glob('save_b6_acceptance_test_*.commit')), 'B6 must write real SaveSystem commits'
            print('[B6 entry] PASS default slot unchanged; isolated File/UI adapters, not V13')
            return 0
        if args.debug_isolation:
            lua.execute('''
                require("debug.DebugIsolationTest").Run(B1_ISOLATION_CONTEXT,
                    function(key) HandleKeyDown("KeyDown", {Key={GetInt=function() return key end}}) end,
                    function() HandleUpdate("Update", {TimeStep={GetFloat=function() return 0.016 end}}) end,
                    require("urhox-libs/UI").root)
            ''')
            return 0
        if args.config_failure:
            lua.execute('''
                local data, status = LoadProgress("b1_config_guard")
                local expectedPath = ({load="Data.Load",c1="stage1.initialEconomy.currency",stage1="Data.ValidateStage1"})[B1_CONFIG_FAILURE]
                assert(data == nil and status.status == "config_error" and status.error.path == expectedPath)
                local root = require("urhox-libs/UI").root
                assert(root:FindById("saveStatusLabel"):GetText():find(status.error.message, 1, true))
                local day = require("core.GameFlow").GetDay()
                for _, id in ipairs({"debugSaveButton", "debugNextDayButton"}) do
                    local props = root:FindById(id):GetProps()
                    assert(props.disabled == true)
                    props.onClick() -- 即使绕过按钮禁用，协调器仍须拦截。
                end
                assert(require("core.GameFlow").GetDay() == day)
                print("[B1 startup gate] PASS " .. B1_CONFIG_FAILURE .. " diagnostic+load+save+nextDay")
            ''')
            assert not list(storage.glob("save_slot1*")), "configuration failure must not write default slot"
            return 0
        if entrypoint:
            if "." not in entrypoint:
                return 0 if lua.eval(entrypoint)() else 1
            test_module = lua.eval("require")(entrypoint)
            if isinstance(test_module, tuple): test_module = test_module[0]
            return 0 if test_module.Run() else 1
        result = lua.eval("RunB1Checks")()
        print("[B1 runner] Lua", lua.eval("_VERSION"), "File/UI=TEST ADAPTERS result=", result)
        return 0 if result else 1


if __name__ == "__main__":
    raise SystemExit(main())
