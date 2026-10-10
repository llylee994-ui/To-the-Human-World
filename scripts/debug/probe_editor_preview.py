"""Run a separate editor and standard preview prepare without opening any windows."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--node', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    local = root / 'scripts/layout-editor/.local'
    local.mkdir(exist_ok=True)
    # Only this temporary editor is owned by the probe. Existing servers/data are untouched.
    with tempfile.TemporaryDirectory(prefix='preview-probe-', dir=local) as directory:
        log_path = root / 'logs/2026-10-10-probe-editor.log'
        with log_path.open('w', encoding='utf-8') as log:
            editor = subprocess.Popen([sys.executable, '-B', '-u', str(root / 'scripts/layout-editor/server.py'),
                                       '--no-browser', '--port', '0', '--data-dir', directory],
                                      stdout=log, stderr=subprocess.STDOUT,
                                      creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                url = None
                for _ in range(100):
                    match = re.search(r'http://127\.0\.0\.1:\d+', log_path.read_text(encoding='utf-8'))
                    if match:
                        url = match.group(0)
                        break
                    if editor.poll() is not None:
                        raise RuntimeError('Probe editor failed to start')
                    time.sleep(0.1)
                assert url, 'Editor did not become ready'
                def health():
                    with urllib.request.urlopen(url + '/api/health', timeout=3) as response:
                        return json.load(response)
                before = health()
                result = subprocess.run([args.node, args.bundle, 'preview', 'prepare', '--target-dir', str(root), '--json'],
                                        capture_output=True, text=True, encoding='utf-8', timeout=240,
                                        creationflags=subprocess.CREATE_NO_WINDOW)
                (root / 'logs/2026-10-10-editor-open-prepare.json').write_text(result.stdout, encoding='utf-8')
                assert result.returncode == 0, result.stderr[-1000:]
                prepared = json.loads(result.stdout)
                assert prepared.get('ok'), prepared.get('error')
                source = Path(prepared['source_directory'])
                assert not (source / 'scripts/layout-editor/.local').exists()
                assert (source / 'scripts/layout-editor/server.py').is_file()
                assert (source / 'scripts/main.lua').read_bytes() == (root / 'scripts/main.lua').read_bytes()
                assert health() == before, 'Editor health/identity changed'
                assert editor.poll() is None, 'Editor was stopped by preparation'
                print('PASS standard preview prepare while real editor holds lock; source intact, .local excluded, editor still healthy; no Runtime launched')
            finally:
                if editor.poll() is None:
                    editor.terminate()
                editor.wait(timeout=10)


if __name__ == '__main__':
    main()
