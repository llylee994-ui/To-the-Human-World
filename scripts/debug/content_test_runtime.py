"""Read a committed data snapshot for isolated tests without changing the workspace."""
import subprocess
import sys
sys.dont_write_bytecode = True
import run_b1

def run(entrypoint, content_ref=None, flags=None):
    modules = {}
    if content_ref:
        def git(*args):
            return subprocess.check_output(['git', *args], cwd=run_b1.ROOT).decode('utf-8')
        sha = git('rev-parse', '--verify', content_ref + '^{commit}').strip()
        paths = git('ls-tree', '-r', '--name-only', sha, '--', 'scripts/data').splitlines()
        for path in paths:
            if path.endswith('.lua'):
                modules[path[len('scripts/'):-4].replace('/', '.')] = git('show', sha + ':' + path)
        if not modules:
            raise ValueError('No data Lua modules at ' + sha)
        print('[Content snapshot] committed data=' + sha + '; workspace scripts unchanged; NOT deployed content', flush=True)
    original = run_b1.LuaRuntime
    def runtime(*args, **kwargs):
        lua = original(*args, **kwargs)
        for name, source in modules.items():
            lua.execute('''
                local name,source=...
                package.preload[name]=assert(load(source,"@committed-snapshot/" .. name,"t"))
            ''', name, source)
        for key, value in (flags or {}).items():
            lua.globals()[key] = value
        return lua
    run_b1.LuaRuntime = runtime
    try:
        return run_b1.main([], entrypoint)
    finally:
        run_b1.LuaRuntime = original
