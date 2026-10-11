"""Import only referenced home assets, byte-for-byte. Does not modify the export."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parents[4]


def lua(value, indent=0):
    pad = '    ' * (indent + 1)
    if isinstance(value, dict):
        return '{\n' + ',\n'.join(pad + '[' + lua(k) + ']=' + lua(v, indent + 1) for k, v in value.items()) + '\n' + '    ' * indent + '}'
    if isinstance(value, list):
        return '{\n' + ',\n'.join(pad + lua(v, indent + 1) for v in value) + '\n' + '    ' * indent + '}'
    if value is True: return 'true'
    if value is False: return 'false'
    if value is None: return 'nil'
    return json.dumps(value, ensure_ascii=False)


def main(source):
    source = Path(source).resolve()
    raw = (source / 'project.json').read_bytes()
    project = json.loads(raw)
    page, = project['pages']
    assert (project['revision'], page['revision'], page['width'], page['height'], len(page['layers']), len(project['assets'])) == (201, 189, 1920, 1080, 11, 39)
    assets = {a['id']: a for a in project['assets']}
    names = ['background', 'tray', 'net', 'case-file', 'merchant-ship', 'letter-paper', 'lily-vase', 'amber-jar', 'herb-jar', 'glass-bottle', 'stove']
    dest = ROOT / 'assets/image/home-entry-r3'
    dest.mkdir(parents=True, exist_ok=True)
    layers = []
    for layer, name in zip(page['layers'], names):
        asset = assets[layer['assetId']]
        file = source / asset['file']
        assert file.resolve().is_relative_to(source)
        digest = hashlib.sha256(file.read_bytes()).hexdigest()
        assert digest == asset['sha256'], asset['name']
        out = dest / (name + '.png')
        if out.exists(): assert out.read_bytes() == file.read_bytes(), 'Refusing to replace different runtime art'
        else: shutil.copyfile(file, out)
        row = {k: layer[k] for k in ('id', 'assetId', 'name', 'x', 'y', 'width', 'height', 'rotation', 'visible')}
        row.update(key=name, path='image/home-entry-r3/' + out.name, sha256=digest)
        layers.append(row)
    # Local centers/sizes are fractions of the original untrimmed image rectangle.
    def rect(cx, cy, w, h, rotation=0): return dict(kind='rect', cx=cx, cy=cy, w=w, h=h, rotation=rotation)
    def ellipse(cx, cy, w, h, rotation=0): return dict(kind='ellipse', cx=cx, cy=cy, w=w, h=h, rotation=rotation)
    objects = [
        dict(id='home.drawer', label='来信抽屉', layer=1, target='letters', minTouch=44,
             regions=[ellipse(.581, .840, .040, .048), ellipse(.684, .944, .045, .053)]),
        dict(id='home.journal', label='故事记录', layer=1, target='journal', minTouch=44,
             regions=[ellipse(.809, .782, .147, .125, -12)]),
        dict(id='home.tray', label='分类词条', layer=2, target='words', minTouch=40,
             regions=[ellipse(.414, .582, .60, .32)]),
        dict(id='home.net', label='海边捕捞', layer=3, target='seaside', minTouch=44,
             regions=[ellipse(.378, .126, .372, .239), ellipse(.424, .268, .225, .260), rect(.598, .696, .085, .59, -18)]),
        dict(id='home.caseFile', label='案件板', layer=4, target='case', minTouch=40,
             regions=[ellipse(.54, .50, .76, .59, -16)]),
        dict(id='home.merchantShip', label='商队商店', layer=5, target='shop', minTouch=44,
             regions=[ellipse(.480, .458, .40, .47), ellipse(.478, .687, .50, .14), rect(.489, .123, .052, .205)]),
        dict(id='home.letterPaper', label='阅读信件', layer=6, target='paper', minTouch=44,
             regions=[ellipse(.52, .50, .72, .60, -12)]),
        dict(id='home.stove', label='炼药工作区', layer=11, target='brew', minTouch=44,
             regions=[ellipse(.50, .478, .56, .423), rect(.50, .744, .17, .16)]),
    ]
    manifest = dict(version='C-HOME-ENTRY-20261010-r3-v01', projectRevision=201, pageRevision=189,
                    sourceSha256=hashlib.sha256(raw).hexdigest(), sourcePageId=page['id'], width=1920, height=1080,
                    background=page['background'], layers=layers, objects=objects)
    (ROOT / 'scripts/ui/landscape/LayoutManifest.lua').write_text(
        '-- Generated from project 201 / home 189. Visual transforms are unmodified.\n'
        '-- Regions describe subjects; art bounds, glow, shadows and water are not buttons.\n'
        '''---@class HomeRegion
---@field kind string
---@field cx number
---@field cy number
---@field w number
---@field h number
---@field rotation number
---@class HomeLayer
---@field id string
---@field assetId string
---@field name string
---@field key string
---@field path string
---@field sha256 string
---@field x number
---@field y number
---@field width number
---@field height number
---@field rotation number
---@field visible boolean
---@class HomeObject
---@field id string
---@field label string
---@field layer integer
---@field target string
---@field minTouch number
---@field regions HomeRegion[]
---@type {version:string,projectRevision:integer,pageRevision:integer,sourceSha256:string,sourcePageId:string,width:number,height:number,background:string,layers:HomeLayer[],objects:HomeObject[]}
'''
        'local manifest=' + lua(manifest) + '\nreturn manifest\n', encoding='utf-8')
    (dest / 'source-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Imported 11 unchanged images; source SHA256=' + manifest['sourceSha256'])


if __name__ == '__main__': main(sys.argv[1])
