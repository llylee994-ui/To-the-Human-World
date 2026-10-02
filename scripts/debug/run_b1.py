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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--config-failure", choices=("load", "c1", "stage1"))
    mode.add_argument("--debug-isolation", choices=(
        "existing", "missing", "flow_missing", "v2_corrupt",
        "auto_write", "auto_read", "auto_read_flow_missing", "auto_read_v2_corrupt",
    ))
    args = parser.parse_args()
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
        lua.execute('''
            package.preload["urhox-libs/UI"] = function() return require "debug.fixtures.HeadlessUI" end
            graphics = {}
            function SubscribeToEvent(...) end
            KEY_Z, KEY_F6, KEY_F7, KEY_F8 = 1, 2, 3, 4 -- 仅替身枚举
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
        result = lua.eval("RunB1Checks")()
        print("[B1 runner] Lua", lua.eval("_VERSION"), "File/UI=TEST ADAPTERS result=", result)
        return 0 if result else 1


if __name__ == "__main__":
    raise SystemExit(main())
