"""Capture the complete native scene in an isolated cloud HOME; record process memory.
Requires the same verified official Linux runtime as run_cloud_capture.sh.
This is graphical GLES QA, not OS/human mouse or target-device performance QA.
"""
import json
import os
from pathlib import Path
import resource
import subprocess
import time

root = Path(__file__).resolve().parents[1]
out = Path(os.environ['D3_CLOUD_OUTPUT']).resolve()
runtime = Path(os.environ['URHOX_RUNTIME']).resolve()
assert runtime.is_file(), 'Set URHOX_RUNTIME to the official installed Linux executable'
(out / 'home/cache').mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env['D3_CLOUD_CAPTURE'] = str(out / 'baseline.png')
env.update(HOME=str(out / 'home'), XDG_CACHE_HOME=str(out / 'home/cache'),
           MESA_SHADER_CACHE_DIR=str(out / 'home/cache'), LIBGL_ALWAYS_SOFTWARE='1',
           EGL_PLATFORM='surfaceless', D3_CLOUD_OUTPUT=str(out))
entry = os.environ.get('D3_CAPTURE_ENTRY', 'scripts/cloud_capture.lua')
entry_path = (root / entry).resolve()
assert entry_path.parent == root / 'scripts' and entry_path.name.startswith('cloud_') and entry_path.suffix == '.lua' and entry_path.is_file(), 'Capture entry must be an existing cloud diagnostic script in this repository'
command = [str(runtime), entry, '-tapcode_dir=' + str(root),
           '-skip_login', '-tool_mode', '-graphicssurfaceless', '-recompile_shader',
           '-nosound', '-x', os.environ.get('D3_WIDTH', '1170'), '-y', os.environ.get('D3_HEIGHT', '658')]
started = time.monotonic()
metrics = {}
with (out / 'runtime.log').open('w') as log:
    child = subprocess.Popen(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
    while child.poll() is None:
        try:
            for line in Path('/proc/{}/status'.format(child.pid)).read_text().splitlines():
                key = line.split(':')[0]
                if key in ('VmHWM', 'VmRSS', 'VmPeak'):
                    metrics[key + 'KiB'] = max(metrics.get(key + 'KiB', 0), int(line.split()[1]))
        except FileNotFoundError:
            pass
        if time.monotonic() - started > 900:
            metrics['timedOut'] = True
            child.terminate()
            break
        time.sleep(.5)
    try:
        code = child.wait(timeout=10)
    except subprocess.TimeoutExpired:
        child.kill()
        code = child.wait()
metrics.update(exitCode=code, wallSeconds=time.monotonic() - started,
               rusageMaxRssKiB=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
               resolution=[int(os.environ.get('D3_WIDTH', '1170')), int(os.environ.get('D3_HEIGHT', '658'))], renderer='Mesa software EGL/GLES surfaceless')
(out / 'process-metrics.json').write_text(json.dumps(metrics, indent=2))
image = out / 'baseline.png'
assert code == 0 and image.is_file(), 'Native capture did not finish; inspect runtime.log'
frame_path = out / 'baseline.png.metrics.json'
assert frame_path.is_file(), 'Capture frame timing report missing'
print(json.dumps({'process': metrics, 'frames': json.loads(frame_path.read_text())}, indent=2))
