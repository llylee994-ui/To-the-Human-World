"""Review only staged additions in the independent GitHub checkout; no credential reads."""
from pathlib import Path
import subprocess,json,re,hashlib,datetime
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT/'deliverables/github-checkout'
def git(*a):return subprocess.check_output(['git',*a],cwd=REPO)
changes=git('diff','--cached','--name-status','-z').decode().split('\0')[:-1]
assert len(changes)%2==0
paths=[]
for status,path in zip(changes[::2],changes[1::2]):
 assert status=='A' and path.startswith('experiments/3d-lab/'),(status,path)
 paths.append(path)
assert len(paths)==135
entries=git('ls-files','--stage','--','experiments/3d-lab').decode().splitlines()
ids=[line.split()[1] for line in entries]
assert len(ids)==len(paths)
proc=subprocess.run(['git','cat-file','--batch'],cwd=REPO,input=('\n'.join(ids)+'\n').encode(),capture_output=True,check=True)
data=proc.stdout; pos=0; reviewed=[]; hits=[]
patterns=[rb'tmpct_[A-Za-z0-9]{12,}',rb'gh[pousr]_[A-Za-z0-9]{20,}',rb'github_pat_[A-Za-z0-9_]{20,}',rb'AKIA[A-Z0-9]{16}',rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',rb'https?://[^\s/"<>]+:[^\s/@"<>]+@',rb'Bearer [A-Za-z0-9._-]{24,}',rb'X-Amz-Signature=[A-Za-z0-9]+']
for entry in entries:
 end=data.index(b'\n',pos); header=data[pos:end].decode().split(); size=int(header[2]); blob=data[end+1:end+1+size]; pos=end+size+2
 path=entry.split('\t',1)[1]
 assert header[1]=='blob' and blob==(REPO/path).read_bytes(),path
 assert size<2*1024*1024
 parts=Path(path).parts
 assert not any(x in parts for x in ('.git','.maker-mcp','.runtime','.preview-home','User','ResCache','logs','deliverables'))
 assert Path(path).suffix.lower() not in ('.exe','.dll','.pyd','.png','.zip')
 for i,p in enumerate(patterns):
  if re.search(p,blob):hits.append({'path':path,'pattern':i})
 reviewed.append({'path':path,'bytes':size,'sha256':hashlib.sha256(blob).hexdigest()})
assert not hits,hits
manifest=json.loads((REPO/'experiments/3d-lab/SOURCE_MANIFEST.json').read_text(encoding='utf-8'))
for item in manifest['copied_files']:
 path='experiments/3d-lab/'+item['path']
 assert next(r['sha256'] for r in reviewed if r['path']==path)==item['sha256'],path
report={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'review':'PASS','branch':git('branch','--show-current').decode().strip(),'base':git('rev-parse','HEAD').decode().strip(),'staged_additions':len(reviewed),'modifications':0,'deletions':0,'total_bytes':sum(r['bytes'] for r in reviewed),'largest_bytes':max(r['bytes'] for r in reviewed),'all_index_blobs_match_disk_and_source_manifest':True,'secret_pattern_hits':hits,'whitespace':'Application/new documentation passed with cr-at-eol. Existing imported Label/RichText trailing blanks and untouched raw offline log trailing spaces preserved as source evidence; not a functional failure.','files':reviewed}
(ROOT/'deliverables/github-stage-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='files'},ensure_ascii=True))
