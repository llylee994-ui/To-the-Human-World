"""Run official synthetic UI input QA in an isolated cloud HOME; record process memory.
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
assert not (out / 'interaction-report.json').exists(), 'Choose a fresh evidence directory; never accept a stale QA report'
(out / 'home/cache').mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(HOME=str(out / 'home'), XDG_CACHE_HOME=str(out / 'home/cache'),
           MESA_SHADER_CACHE_DIR=str(out / 'home/cache'), LIBGL_ALWAYS_SOFTWARE='1',
           EGL_PLATFORM='surfaceless', D3_CLOUD_OUTPUT=str(out))
command = [str(runtime), 'scripts/cloud_interaction_check.lua', '-tapcode_dir=' + str(root),
           '-skip_login', '-tool_mode', '-graphicssurfaceless', '-recompile_shader',
           '-nosound', '-x', '1170', '-y', '658']
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
               resolution=[1170, 658], renderer='Mesa software EGL/GLES surfaceless')
(out / 'process-metrics.json').write_text(json.dumps(metrics, indent=2))
report_path = out / 'interaction-report.json'
assert code == 0 and report_path.is_file(), 'Native QA did not finish; inspect runtime.log'
report = json.loads(report_path.read_text())
print(json.dumps({'metrics': metrics, 'report': report}, ensure_ascii=False, indent=2))
assert report.get('status') == 'PASS', 'Native QA failed; inspect interaction-report.json'
