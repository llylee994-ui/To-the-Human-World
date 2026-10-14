"""Read-only current candidate hashes and dependency audit; no native acceptance."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def audit():
 assets=ROOT/'assets/v035-full';hashes=json.loads((assets/'runtime-assets.sha256.json').read_text())
 for name,expected in hashes.items():
  target=(assets/name).resolve();assert target.is_relative_to(assets),name
  assert hashlib.sha256(target.read_bytes()).hexdigest()==expected,name
 scene=json.loads((assets/'scene.json').read_text())
 for mesh in scene['meshFiles']:assert mesh['file'] in hashes,mesh['id']
 for material in scene['materials']:
  for field in ('baseColorTexture','normalTexture'):
   if material.get(field):assert material[field] in hashes,material[field]
 queue=['scripts/main.lua'];visited=set();unresolved=set()
 while queue:
  relative=queue.pop()
  if relative in visited:continue
  visited.add(relative);source=(ROOT/relative).read_text(encoding='utf-8-sig')
  for name in re.findall(r'require\s*\(?\s*[\"\x27]([^\"\x27]+)',source):
   stem=name.replace('.','/');choices=[prefix+stem+suffix for prefix in ('scripts/','','urhox-libs/') for suffix in ('.lua','/init.lua')]
   found=next((p for p in choices if (ROOT/p).is_file()),None)
   if found:queue.append(found)
   else:unresolved.add(name)
 expected_optional={'UIInspector','v035.ui.landscape.tests.NativeProbe','v035.ui.landscape.tests.YawNativeProbe'}
 assert unresolved<=expected_optional,unresolved-expected_optional
 required={'scripts/core/GameSession.lua','scripts/data/content.lua','scripts/data/release.lua','scripts/ui/PlayModel.lua','scripts/ui/landscape/ShopView.lua'}
 assert required<=visited,required-visited
 assert not any(p.startswith(('scripts/v035/data/','scripts/v035/systems/')) for p in visited), 'Old business remains reachable'
 assert 'scripts/v035/ui/PlayModel.lua' not in visited
 assert (ROOT/'assets/fonts/HarborHand-Regular.ttf').is_file()
 return {'status':'PASS','layer':'static only','resourceHashes':len(hashes),'meshes':len(scene['meshFiles']),'triangles':scene['triangles'],'interactionProxies':len(scene['interactionProxies']),'literalRequireClosure':sorted(visited),'optionalDeveloperImports':sorted(unresolved),'note':'Dynamic resource use and OS input require separate native gameplay QA.'}
if __name__=='__main__':print(json.dumps(audit(),ensure_ascii=False,indent=2))
