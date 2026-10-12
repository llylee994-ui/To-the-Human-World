"""Read-only image inspection + provenance manifest; copies keep original bytes."""
from pathlib import Path
import base64
import hashlib
import json
import uuid
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
DEST = ROOT / 'assets/image/seaside-r1'
SOURCES = {
    'background.png': 'assets/image/海边捕捞_纯背景_v01_20261012054550.png',
    'bottle.png': 'assets/image/海边捕捞_漂流瓶净透明_v02_20261012054934.png',
    'net.png': 'assets/image/海边捕捞_网兜透明_v01_20261012054622.png',
    'merchant-ship.png': 'assets/image/home-entry-r3/merchant-ship.png',
}

def main():
    records = []
    for name, source in SOURCES.items():
        file = DEST / name
        raw = file.read_bytes()
        assert raw == (ROOT / source).read_bytes(), f'Copied asset differs: {name}'
        with Image.open(file) as im:
            record = dict(path=file.relative_to(ROOT).as_posix(), source=source,
                width=im.width, height=im.height, mode=im.mode, sha256=hashlib.sha256(raw).hexdigest())
            if name != 'background.png':
                assert im.mode == 'RGBA' and im.getchannel('A').getextrema()[0] == 0, f'Alpha missing: {name}'
                record['alphaBounds'] = im.getchannel('A').getbbox()
        records.append(record)
    (DEST / 'source-manifest.json').write_text(json.dumps(dict(version='seaside-r1',
        concept='assets/image/海边捕捞_构图稿_v01_20261012053950.png',
        generationRecords='assets/image/seaside-r1/generation-records.json',assets=records),ensure_ascii=False,indent=2),encoding='utf-8')
    paths = list(DEST.glob('*')) + [ROOT / 'scripts/ui/landscape' / name for name in ['SeasideView.lua','SeasideManifest.lua']]
    paths += [ROOT / 'scripts/ui/landscape/tests' / name for name in ['SeasideFlowTest.lua','run_seaside_flow.py','SeasideEvidenceHost.lua','SeasideNativeProbe.lua','export_seaside_evidence.py','prepare_seaside_manifest.py']]
    for path in paths:
        if path.suffix == '.meta' or not path.is_file():
            continue
        meta = path.with_name(path.name + '.meta')
        if not meta.exists():
            meta.write_text(json.dumps({'uuid':base64.urlsafe_b64encode(uuid.uuid4().bytes).decode().rstrip('=')},indent=2),encoding='utf-8')
    print('[SeasideAssets] Four runtime files retain source bytes; RGBA alpha verified; provenance recorded')

if __name__ == '__main__':
    main()
