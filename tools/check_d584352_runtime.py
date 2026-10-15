"""Production Lua schema and lifecycle checks with explicit native stubs, not OS input."""
from pathlib import Path
import copy
import json
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tmp/b1-python'))
from lupa.lua54 import LuaRuntime
from PIL import Image
from audit_v035_resources import audit


def check():
    result = audit()
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('package.path = ... .. "/scripts/?.lua;" .. ... .. "/?.lua;" .. package.path', ROOT.as_posix(), ROOT.as_posix())
    for name in result['literalRequireClosure']:
        lua.execute('assert(load(...))', (ROOT / name).read_text(encoding='utf-8-sig'))
    def table(value):
        if isinstance(value, dict):
            return lua.table_from({k: table(v) for k, v in value.items()})
        if isinstance(value, list):
            return lua.table_from([table(v) for v in value])
        return value
    prepare = lua.eval('''function(raw)
        local catalog=require('v035.lab35.ScenePackage').Catalog({meshFiles=raw.meshFiles})
        local header=require('v035.lab35.ProbeAdapter').Convert(raw,{meshCatalog=catalog})
        return require('v035.lab35.MeshContract').Prepare(header,{meshCatalog=catalog,maxExpandedVertices=12000000})
    end''')
    raw = json.loads((ROOT / 'assets/v035-full/scene.json').read_text(encoding='utf-8'))
    prepare(table(raw))
    legacy = json.loads(subprocess.check_output(['git', '--no-optional-locks', '-C', str(ROOT),
                       'show', '135334dc997023a1bbbc35c1b994364a24504c3a:assets/v035-full/scene.json']))
    prepare(table(legacy))
    passed = ['current scene schema', 'prior scene schema compatibility']
    cases = [
        ('reject sRGB packed map', 'lantern.wood', 'textureColorSpaces', {'roughMetalOcclusionTexture': 'sRGB'}),
        ('reject traversal map path', 'lantern.wood', 'roughMetalOcclusionTexture', '../escape.png'),
        ('reject unlit packed map', 'lantern.wood', 'unlit', True),
    ]
    emissive = next(m for m in raw['materials'] if m.get('emissiveTexture'))
    cases.append(('reject emission without factor', emissive['id'], 'emissiveFactor', None))
    for label, material_id, key, value in cases:
        bad = copy.deepcopy(raw)
        material = next(m for m in bad['materials'] if m['id'] == material_id)
        if value is None:
            material.pop(key)
        else:
            material[key] = value
        try:
            prepare(table(bad))
        except Exception:
            passed.append(label)
        else:
            raise AssertionError(label)
    textures = {m[f] for m in raw['materials'] for f in ['baseColorTexture', 'normalTexture', 'roughMetalOcclusionTexture', 'emissiveTexture'] if m.get(f)}
    for path in textures:
        with Image.open(ROOT / 'assets/v035-full' / path) as image:
            image.verify()
    # Fire must clean its allocated node on a failed native constructor, and Stop is idempotent.
    lua.execute('''
        local function noop() end
        cache={GetResource=function() return {} end}
        Material={new=function() return {SetTechnique=noop,SetTexture=noop,SetShaderParameter=noop,SetCullMode=noop} end}
        Color=function(...) return {...} end;Vector3=Color;Vector2=Color;Variant=function(x) return x end
        TU_DIFFUSE=0;CULL_NONE=0;TRIANGLE_LIST=0
        local F=require 'v035.lab35.KenneyCauldronFire'
        for _,failure in ipairs({'CreateComponent','Commit','none'}) do
            local removed,vertices,commits=0,0,0
            local geometry={SetMaterial=noop,SetDynamic=noop,BeginGeometry=noop,DefineColor=noop,DefineTexCoord=noop,
                DefineVertex=function() vertices=vertices+1 end,
                Commit=function() commits=commits+1;if failure=='Commit' then error('INJECTED Commit') end end}
            local root={CreateComponent=function() if failure=='CreateComponent' then error('INJECTED CreateComponent') end;return geometry end,
                Remove=function() removed=removed+1 end}
            local ok,fire=pcall(F.New,{CreateChild=function() return root end},'v035-full')
            if failure=='none' then
                assert(ok);fire.Update(1/60);fire.Stop();fire.Stop();fire.Update(1/60)
                assert(vertices==36 and commits==2)
                assert(geometry.viewMask==0x80000000, 'effect geometry must be excluded from object picking')
            else assert(not ok and tostring(fire):find('INJECTED '..failure,1,true)) end
            assert(removed==1, 'allocated fire node must be removed exactly once')
        end
    ''')
    passed.append('fire constructor failures and idempotent lifecycle (native stubs)')
    return {'status': 'PASS', 'layer': 'static/real Lua with native stubs; not rendering or OS interaction',
            'luaFilesCompiled': len(result['literalRequireClosure']), 'texturesDecoded': len(textures),
            'checks': passed, 'resourceAudit': result}


if __name__ == '__main__':
    result = check()
    output = ROOT / 'docs/evidence/d584352-integration/runtime-checks.json'
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'resourceAudit'}, ensure_ascii=False))
