"""Read-only local resource/dependency and first-run log privacy audit.
Never emits log values, credential contents, private session JSON, or raw URLs.
"""
from pathlib import Path
import json,re,hashlib,datetime,struct
root=Path(__file__).resolve().parents[1]; out=root/'docs/evidence/3d-lab-r3/resource-followup'; out.mkdir(exist_ok=True)
install=Path(r'C:\Users\YINGYI\.taptap-maker\runtime\runtime-55daebeb-793b-4258-9b0e-9ca63cd33351')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def meta(path):
    s=path.stat(); return {'path':str(path),'bytes':s.st_size,'modified_utc':datetime.datetime.fromtimestamp(s.st_mtime,datetime.timezone.utc).isoformat()}
index=[]
for p in (next((root/'.preview-home/preview').iterdir())/'public-index-cache').glob('engine-res-*.json'):
    j=json.loads(p.read_text(encoding='utf-8')); hits=[]
    for row in j.get('files',[]):
        if any(x in row.get('fs_path','') for x in ('SpecularHDR','LightGroup/Dusk','LightGroup/Day')):
            hits.append({k:v for k,v in row.items() if k in ('uuid','ext','hash','size','hash@windows','size@windows','fs_path')})
    index.append({'file':str(p),'sha256':sha(p),'file_count':len(j.get('files',[])),'matches':hits})
# Read only the PE import names from the existing copied executable.
b=(root/'.runtime/UrhoXRuntime.exe').read_bytes(); pe=struct.unpack_from('<I',b,0x3c)[0]
assert b[pe:pe+4]==b'PE\x00\x00'
nsections=struct.unpack_from('<H',b,pe+6)[0]; optional_size=struct.unpack_from('<H',b,pe+20)[0]; opt=pe+24
magic=struct.unpack_from('<H',b,opt)[0]; directories=opt+(112 if magic==0x20b else 96)
sections=[]
for i in range(nsections):
    off=opt+optional_size+i*40; virtual_size,rva,raw_size,raw=struct.unpack_from('<IIII',b,off+8)
    sections.append((rva,max(virtual_size,raw_size),raw))
def offset(rva):
    for start,size,raw in sections:
        if start<=rva<start+size:return raw+rva-start
    raise ValueError('RVA outside sections')
def cstring(off): return b[off:b.index(b'\0',off)].decode('ascii','replace')
import_rva,import_size=struct.unpack_from('<II',b,directories+8); imports=[]
if import_rva:
    off=offset(import_rva)
    while b[off:off+20]!=bytes(20):
        imports.append(cstring(offset(struct.unpack_from('<I',b,off+12)[0])));off+=20
strings=[x.decode('ascii','replace') for x in re.findall(rb'[\x20-\x7e]{6,100}',b) if b'themis' in x.lower()]
distribution=json.loads((root/'.runtime/build.json').read_text(encoding='utf-8'))
dependencies={'executable_sha256':hashlib.sha256(b).hexdigest(),'static_import_dlls':imports,'themis_is_static_import':any('themis' in x.lower() for x in imports),'themis_binary_strings':strings,'shipped_files':[x['name'] for x in distribution.get('files',[])],'themis_shipped':any('themis' in x['name'].lower() for x in distribution.get('files',[])),'installed_themis_exists':(install/'themis_x64.dll').exists(),'lab_themis_exists':(root/'.runtime/themis_x64.dll').exists(),'scope':'Static dependencies and distribution metadata only. Dynamic feature purpose remains unknown without official documentation.'}
patterns={
 'authentication_assignment':re.compile(r'''(?i)(?:authorization|access[_-]?token|refresh[_-]?token|id[_-]?token|session[_-]?token|api[_-]?key|client[_-]?secret|password)["' ]*[:=]["' ]*([^\s,}]+)'''),
 'bearer_value':re.compile(r'(?i)bearer\s+([^\s,}]+)'),
 'jwt_shape':re.compile(r'([A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,})'),
 'signed_or_token_query':re.compile(r'(?i)(?:[?&](?:x-amz-signature|sig|signature|token|access_token|key))=([^&\s]+)'),
 'private_identifier_field':re.compile(r'''(?i)(?:user[_-]?id|device[_-]?id|open[_-]?id|machine[_-]?id)["' ]*[:=]["' ]*([^\s,}]+)'''),
}
logs=[]
for folder in ('game','lua'):
    for p in (install/'logs'/folder).glob('*'):
        if not p.is_file() or not re.search(r'2026-10-12 12_(?:20|30)_',p.name):continue
        text=p.read_text(encoding='utf-8',errors='replace'); findings=[]
        for number,line in enumerate(text.splitlines(),1):
            for category,pattern in patterns.items():
                for match in pattern.finditer(line):
                    value=match.group(1)
                    findings.append({'line':number,'category':category,'value_length':len(value),'already_redacted':any(x in value.lower() for x in ('redacted','***','<masked>'))})
        logs.append({**meta(p),'sha256':sha(p),'contains_lab_marker':'D3-LAB' in text,'contains_lab_app_id':'52356e67-6bfa-415e-862d-8203b5fcffc9' in text,'contains_lab_path':'To-the-Human-World-3D-Lab' in text,'findings':findings,'raw_content_exported':False})
related=[]
for folder in ('User','ResCache'):
    for p in (install/folder).rglob('*'):
        if p.is_file(): related.append(meta(p))
report={'utc':now,'public_indexes':index,'dependencies':dependencies,'first_run_install_logs':logs,'related_metadata_only':related,'privacy_scope':'Only named first-run/reload log files read. User state and login/credential file contents were not read or copied. No deletion or install-directory writes. Pattern scan cannot prove absence of every possible sensitive format. Metadata alone does not attribute other workers files to this task.'}
(out/'read-only-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'index_matches':[len(x['matches']) for x in index],'themis_static_import':dependencies['themis_is_static_import'],'themis_shipped':dependencies['themis_shipped'],'themis_binary_strings':strings,'logs':[{'path':x['path'],'bytes':x['bytes'],'lab_marker':x['contains_lab_marker'],'findings':x['findings']} for x in logs],'related_metadata_file_count':len(related)},ensure_ascii=False))
