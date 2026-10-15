"""Check imported scene data, materials, placement and stable interaction ownership (no engine)."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/v035-full'


def check():
    scene = json.loads((ASSETS / 'scene.json').read_text(encoding='utf-8'))
    manifest = json.loads((ASSETS / 'manifest.json').read_text(encoding='utf-8'))
    hashes = json.loads((ASSETS / 'runtime-assets.sha256.json').read_text(encoding='utf-8'))
    for name, expected in hashes.items():
        path = (ASSETS / name).resolve()
        assert path.is_relative_to(ASSETS) and path.is_file(), name
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, name
    material_ids = {m['id'] for m in scene['materials']}
    assert len(material_ids) == len(scene['materials']) == manifest['materials']
    texture_refs = set()
    for material in scene['materials']:
        for field in ['baseColorTexture', 'normalTexture', 'roughMetalOcclusionTexture', 'emissiveTexture']:
            if material.get(field):
                assert material[field] in hashes, (material['id'], field)
                texture_refs.add(material[field])
        if material.get('roughMetalOcclusionTexture'):
            assert material.get('normalTexture') and material['textureColorSpaces']['roughMetalOcclusionTexture'] == 'linear'
        if material.get('emissiveTexture'):
            assert material.get('emissiveFactor') and material['textureColorSpaces']['emissiveTexture'] == 'sRGB'
    meshes = {}
    triangles = vertices = 0
    bounds = {}
    for row in scene['meshFiles']:
        assert row['id'] not in meshes and row['file'] in hashes
        path = ASSETS / row['file']
        data = json.loads(path.read_text(encoding='utf-8'))
        assert data['id'] == row['id'] and data['materialId'] == row['materialId']
        assert data['materialId'] in material_ids
        vertex_count = len(data['positions']) // 3
        triangle_count = len(data['indices']) // 3
        assert len(data['positions']) == vertex_count * 3 == len(data['normals'])
        assert len(data['uv0']) == vertex_count * 2
        assert len(data['indices']) == triangle_count * 3
        assert vertex_count == row.get('vertices', row.get('vertexCount'))
        assert triangle_count == row.get('triangles', row.get('triangleCount'))
        assert min(data['indices']) >= 0 and max(data['indices']) < vertex_count
        assert all(math.isfinite(v) for v in data['positions'])
        triangles += triangle_count
        vertices += vertex_count
        meshes[row['id']] = row
        if row['id'].startswith(('clock.', 'selected-lamp.', 'ingredient.')):
            bounds[row['id']] = {'min': [min(data['positions'][i::3]) for i in range(3)],
                                 'max': [max(data['positions'][i::3]) for i in range(3)]}
    assert len(meshes) == manifest['meshCount'] == 138
    assert triangles == manifest['triangles'] == scene['triangles']
    assert vertices == manifest['vertices']
    expected_routes = {'home.drawer': 'letters', 'home.journal': 'journal', 'home.tray': 'words',
                       'home.net': 'seaside', 'home.caseFile': 'case', 'home.merchantShip': 'shop',
                       'home.letterPaper': 'paper', 'home.stove': 'brew'}
    assert {p['id']: p['target'] for p in scene['interactionProxies']} == expected_routes
    proxy_ids = {p['id'] for p in scene['proxyMeshes']}
    for p in scene['interactionProxies']:
        assert p['proxyMeshId'] in proxy_ids
        assert p['visibleMeshIds'] and set(p['visibleMeshIds']) <= set(meshes)
        assert len(p['screenAnchor']) == 2 and all(0 <= n <= 1 for n in p['screenAnchor'])
    clock = [v for k, v in bounds.items() if k.startswith('clock.')]
    clock_min = [min(v['min'][i] for v in clock) for i in range(3)]
    clock_max = [max(v['max'][i] for v in clock) for i in range(3)]
    assert abs(clock_min[2] - 2.4205) < .001, 'Clock must contact confirmed third visible shelf'
    assert abs(clock_max[0] - clock_min[0] - .60) < .005, 'Clock width must match confirmed enlarged model'
    lamp = [v for k, v in bounds.items() if k.startswith('selected-lamp.')]
    assert abs(min(v['min'][2] for v in lamp) - 1.852) < .001, 'Lamp must contact desktop'
    techniques = []
    for name in hashes:
        if name.endswith('.xml') and '/techniques/' in '/' + name:
            assert ET.parse(ASSETS / name).getroot().tag == 'technique', name
            techniques.append(name)
    return {'status': 'PASS', 'layer': 'static resources, not native/visual acceptance',
            'resourceHashes': len(hashes), 'meshes': len(meshes), 'triangles': triangles, 'vertices': vertices,
            'textureReferences': len(texture_refs), 'techniques': techniques, 'stableInteractionRoutes': expected_routes,
            'clockBoundsBlender': {'min': clock_min, 'max': clock_max}, 'confirmedClockWidth': .60,
            'lampDesktopContactZ': 1.852, 'ingredientAndSelectedObjectBounds': bounds}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = check()
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'ingredientAndSelectedObjectBounds'}, ensure_ascii=False))
