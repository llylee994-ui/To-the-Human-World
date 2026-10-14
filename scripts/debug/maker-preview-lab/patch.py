"""Generate a reversible local candidate; never overwrite the installed Maker."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil

SOURCE = Path('C:/Users/YINGYI/.taptap-maker/mcp-runtime/0.0.36/dist/maker.js')
EXPECTED = '62deb6cd7adc3975d23ce5750be53116f02ef7b9b5b9d49e5ace44fbbc144652'
DEST = Path('D:/taptap/.mpv/cli')
HERE = Path(__file__).resolve().parent


def build():
    original = SOURCE.read_bytes()
    if hashlib.sha256(original).hexdigest() != EXPECTED:
        raise RuntimeError('Installed Maker changed; inspect new version before patching.')
    text = original.decode('utf-8')
    replacements = [
        ('import fs28 from "node:fs";', 'import { openPersistentPreview } from "./persistence.mjs";\nimport fs28 from "node:fs";'),
        ('async function startPreviewAssetServer(source, signal) {', 'async function startPreviewAssetServer(source, signal, persistence) {'),
        ('const prefix = "/" + randomBytes(32).toString("hex") + "/";', 'const prefix = "/" + (persistence ? persistence.token : randomBytes(32).toString("hex")) + "/";'),
        ('server.setTimeout(3e4, (socket) => socket.destroy());\n  await new Promise((resolve, reject) => {\n    server.once("error", reject);\n    server.listen(0, "127.0.0.1", () => {', 'server.setTimeout(3e4, (socket) => socket.destroy());\n  await new Promise((resolve, reject) => {\n    server.once("error", reject);\n    server.listen(persistence ? persistence.port : 0, "127.0.0.1", () => {'),
        ('return { url: "http://" + host + prefix, close };', 'try { if (persistence) persistence.commitPort(address.port); } catch (error) { await close(); throw error; }\n  return { url: "http://" + host + prefix, close };'),
        ('this.assets = await startPreviewAssetServer(source, this.abort.signal);', 'this.persistence = openPersistentPreview(project, classification.network_required);\n          this.assets = await startPreviewAssetServer(source, this.abort.signal, this.persistence);'),
        ('cacheRoot = process.platform === "win32" ? this.temporaryCache', 'cacheRoot = this.persistence ? this.persistence.cacheRoot : process.platform === "win32" ? this.temporaryCache'),
        ('clearAssetCache() {\n        if (this.temporaryCache)', 'clearAssetCache() {\n        if (this.persistence) { this.persistence.retain(); return; }\n        if (this.temporaryCache)'),
    ]
    for old, new in replacements:
        if text.count(old) != 1:
            raise RuntimeError(f'Patch boundary is not unique: {old[:90]}')
        text = text.replace(old, new)
    # Refuse redirected destinations; no recursive deletes or moves.
    for folder in [DEST.parent, DEST, DEST/'dist']:
        if folder.exists() and (folder.is_symlink() or folder.resolve() != folder):
            raise RuntimeError('Lab destination is redirected')
        folder.mkdir(exist_ok=True)
    (DEST/'package.json').write_text('{"type":"module","private":true}\n', encoding='utf-8')
    backup = DEST/'maker.original.js'
    if backup.exists() and backup.read_bytes() != original:
        raise RuntimeError('Existing original backup differs')
    backup.write_bytes(original)
    (DEST/'dist/maker.js').write_text(text, encoding='utf-8', newline='\n')
    shutil.copyfile(HERE/'persistence.mjs', DEST/'dist/persistence.mjs')
    diff = ''.join(difflib.unified_diff(original.decode().splitlines(True), text.splitlines(True), fromfile='official/maker.js', tofile='candidate/maker.js'))
    (DEST/'candidate.patch').write_text(diff, encoding='utf-8')
    result = {'source':str(SOURCE),'original_sha256':EXPECTED,'candidate_sha256':hashlib.sha256(text.encode()).hexdigest(),'candidate':str(DEST/'dist/maker.js'),'replacement_count':len(replacements)}
    (DEST/'manifest.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    build()
