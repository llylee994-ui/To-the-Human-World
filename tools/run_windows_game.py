"""Launch the complete candidate with a verified, already installed Windows runtime.

No install, network, credential copy, player-save copy, or OS input automation.
Use --check for read-only validation without copying files or starting a game.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '20260923-1717-bf3316f'
EXE_SHA256 = '116e3309d52873044d7832ad153cd88c3adcca17289baa22497994234f817ee2'
FONT_SHA256 = 'e051009b42b454352a90ae0c9b8adb58bbdbcd168768750b35bc3357510de141'
FILES = (
    'UrhoXRuntime.exe', 'shaderc.dll', 'd3dcompiler_47.dll',
    'Autoload/Data.pak', 'Autoload/CoreData.pak', 'Autoload/Res.pak',
    'Res/shadercache_runtime/shadercache_dx11.pak', 'build.json',
)
FONT = 'Res/Fonts/MiSans-Regular.ttf'


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def local_path(relative):
    path = (ROOT / relative).resolve()
    require(path.is_relative_to(ROOT), 'Output must remain inside this checkout')
    return path


def installed_runtime():
    explicit = os.environ.get('URHOX_RUNTIME')
    if explicit:
        exe = Path(explicit).expanduser().resolve()
        require(exe.name.lower() == 'urhoxruntime.exe' and exe.is_file(),
                'URHOX_RUNTIME must point to the existing official UrhoXRuntime.exe')
        return exe.parent
    matches = []
    for build_file in (Path.home() / '.taptap-maker/runtime').glob('*/build.json'):
        build = json.loads(build_file.read_text(encoding='utf-8-sig'))
        if build.get('platform') == 'windows' and build.get('version') == VERSION:
            matches.append(build_file.parent)
    require(len(matches) == 1,
            'Expected one installed official runtime ' + VERSION +
            '; set URHOX_RUNTIME to its EXE if needed. No installation was attempted.')
    return matches[0]


def verified_files(source):
    archive = source / 'UrhoXRuntime.zip'
    require(archive.is_file(), 'The existing official runtime ZIP is required for verification')
    data = {}
    with zipfile.ZipFile(archive) as bundle:
        require(set(bundle.namelist()) == set(FILES), 'Unexpected official ZIP contents')
        for name in FILES:
            content = bundle.read(name)  # zipfile validates CRC on each read.
            require((source / name).read_bytes() == content,
                    'Installed file differs from its distribution ZIP: ' + name)
            data[name] = content
    build = json.loads(data['build.json'])
    require(build.get('platform') == 'windows' and build.get('version') == VERSION,
            'This launcher is validated for Windows runtime ' + VERSION)
    require(sha(data['UrhoXRuntime.exe']) == EXE_SHA256, 'Runtime EXE hash mismatch')
    data[FONT] = (source / FONT).read_bytes()
    require(sha(data[FONT]) == FONT_SHA256, 'Required installed MiSans font hash mismatch')
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    require(sys.platform == 'win32', 'Use this launcher on Windows only')
    for name in ('scripts/main.lua', 'assets/v035-full/manifest.json', 'urhox-libs/UI/init.lua'):
        require((ROOT / name).is_file(), 'Missing candidate resource: ' + name)
    source = installed_runtime()
    payload = verified_files(source)
    runtime = local_path('.runtime-windows')
    command = [str(runtime / 'UrhoXRuntime.exe'), 'scripts/main.lua',
               '-tapcode_dir=' + str(ROOT), '-skip_login', '-p=Res', '-w',
               '-width=1170', '-height=658']
    receipt = {'version': VERSION, 'source': str(source), 'cwd': str(ROOT),
               'command': command, 'storage': 'isolated in-memory d3_lab_v035',
               'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)}
                         for name, data in payload.items()]}
    # Existing binaries/fonts are verified, never silently overwritten.
    for name, data in payload.items():
        target = local_path('.runtime-windows/' + name)
        if target.exists():
            require(target.read_bytes() == data, 'Existing runtime differs; preserve and inspect: ' + name)
    if args.check:
        print(json.dumps({'ok': True, 'launched': False, **receipt}, ensure_ascii=False, indent=2))
        return
    for name, data in payload.items():
        target = local_path('.runtime-windows/' + name)
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream:
                stream.write(data)
    out = local_path('.windows-runs/' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    out.mkdir(parents=True, exist_ok=False)
    temporary = out / 'tmp'
    temporary.mkdir()
    env = os.environ.copy()
    for key in ('D3_CLOUD_OUTPUT', 'D3_CLOUD_CAPTURE', 'LIBGL_ALWAYS_SOFTWARE', 'EGL_PLATFORM'):
        env.pop(key, None)
    env.update(TEMP=str(temporary), TMP=str(temporary))
    with (out / 'stdout.log').open('wb') as stdout, (out / 'stderr.log').open('wb') as stderr:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr,
                                   creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
    receipt.update(pid=process.pid, utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (out / 'launch.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Game process started; wait for the complete room. PID:', process.pid)
    print('Logs:', out)
    print('Progress is in memory only and resets when the game closes.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile) as error:
        print('Windows launch stopped:', error, file=sys.stderr)
        sys.exit(1)
