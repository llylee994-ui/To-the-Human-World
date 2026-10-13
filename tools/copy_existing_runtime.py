"""Copy the existing Runtime distribution, excluding all user/log/cache state."""
from pathlib import Path
import zipfile,hashlib,json,datetime
root=Path(__file__).resolve().parents[1]
source=Path(r'C:\Users\YINGYI\.taptap-maker\runtime\runtime-55daebeb-793b-4258-9b0e-9ca63cd33351')
out=root/'.runtime'
assert not out.exists(), 'Do not overwrite an existing runtime copy'
entries=['UrhoXRuntime.exe','shaderc.dll','d3dcompiler_47.dll','Autoload/Data.pak','Autoload/CoreData.pak','Autoload/Res.pak','Res/shadercache_runtime/shadercache_dx11.pak','build.json']
rows=[]
with zipfile.ZipFile(source/'UrhoXRuntime.zip') as z:
    assert sorted(z.namelist())==sorted(entries)
    for name in entries:
        data=z.read(name); src=source/name
        assert src.read_bytes()==data, name+' differs from existing distribution'
        dest=out/name
        assert dest.resolve().is_relative_to(root.resolve())
        dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(data)
        rows.append({'source':str(src),'destination':str(dest),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
record={'copied_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'purpose':'Existing Runtime copy only. No installer, account, credential, save, preview-session, User, logs or ResCache copied. Subsequent engine-relative outputs stay within lab.','files':rows}
(root/'docs/evidence/3d-lab-r3/runtime-copy.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'files':len(rows),'bytes':sum(r['bytes'] for r in rows),'root':str(out)}))
