"""Explicit source and staging output; never overwrite live runtime resources."""
from pathlib import Path
import os
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
MAPPINGS = HERE / 'mappings'

def output_dir():
    value = os.environ.get('D3_BLENDER_OUTPUT')
    if not value:
        raise RuntimeError('Set D3_BLENDER_OUTPUT to a staging directory under this checkout/.windows-runs/blender/')
    target = Path(value).resolve()
    boundary = (REPO / '.windows-runs/blender').resolve()
    if not boundary.is_relative_to(REPO) or not target.is_relative_to(boundary) or target == boundary:
        raise RuntimeError('Blender output must be an explicit subdirectory of this checkout/.windows-runs/blender/')
    target.mkdir(parents=True, exist_ok=True)
    return target

def source_blend():
    value = os.environ.get('D3_BLENDER_SOURCE')
    if not value:
        raise RuntimeError('Set D3_BLENDER_SOURCE to your existing .blend source; it is opened with use_scripts=False and never saved')
    source = Path(value).resolve()
    if not source.is_file() or source.suffix.lower() != '.blend':
        raise RuntimeError('D3_BLENDER_SOURCE must be an existing .blend file')
    if source.is_relative_to(output_dir()):
        raise RuntimeError('Source must be outside the staging output directory')
    return str(source)

def mapping(name):
    target = (MAPPINGS / name).resolve()
    if not target.is_relative_to(MAPPINGS.resolve()) or not target.is_file():
        raise RuntimeError('Missing mapping: ' + name)
    return str(target)
