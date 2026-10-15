"""Independent tray/journal material studio using the existing layout editor."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile

from store import FORMAT, VERSION, image_info

PROJECT_ROOT = Path(__file__).resolve().parents[2]
EDITOR_ROOT = Path(__file__).resolve().parent
ASSETS = {
    'cloth':'assets/image/界面_桌布_透明_v01.png',
    'tray':'assets/image/界面_木托盘_透明_v01.png',
    'slip':'assets/image/界面_纸条_折痕_透明_v01.png',
    'tray-flowers':'assets/image/界面_干花束_透明_v01.png',
    'book':'assets/image/界面_记录书_左半厚书_透明_v01.png',
    'flowers':'assets/image/界面_记录书_大朵干花_透明_v01.png',
    'grass':'assets/image/界面_记录书_麦穗干草_透明_v01.png',
    'tab':'assets/image/界面_记录书_索引纸签_透明_v01.png',
    'paper':'assets/image/界面_柔边纸面_透明_v01_20261013070534.png',
    'wood':'assets/image/界面_深木牌_透明_v01_20261013070534.png',
}


def layer(key, asset, x, y, width, height, name, locked=False):
    return {'id':key, 'assetId':'panel-asset-' + asset, 'name':name,
            'x':x, 'y':y, 'width':width, 'height':height, 'rotation':0,
            'visible':True, 'locked':locked, 'groupId':None}


def project_bundle():
    """Build and verify all inputs before a single transactional import."""
    assets, payloads = [], {}
    for key, relative in ASSETS.items():
        path = PROJECT_ROOT / relative
        raw = path.read_bytes()
        meta = {'id':'panel-asset-' + key, 'name':path.stem,
                'sha256':hashlib.sha256(raw).hexdigest(), **image_info(raw)}
        meta['file'] = 'assets/' + meta['id'] + '.' + meta['ext']
        assets.append(meta)
        payloads[meta['file']] = raw
    tray = [layer('tray-cloth','cloth',260,520,520,1040,'底衬 · 桌布（可解锁）',True),
            layer('tray-frame','tray',260,550,444,592,'木托盘')]
    for index in range(3):
        tray.append(layer('tray-category-' + str(index),'slip',104+index*156,145,126,42,'分类纸签 ' + str(index+1)))
    for index in range(6):
        tray.append(layer('tray-slip-' + str(index),'slip',172+(index%2)*176,350+(index//2)*96,162,54,'词条纸条 ' + str(index+1)))
    tray.append(layer('tray-botanical','tray-flowers',116,823,140,210,'托盘现有干花（可换为新大花）'))
    journal = [layer('journal-cloth','cloth',260,520,520,1040,'底衬 · 桌布（可解锁）',True),
               layer('journal-book','book',292,530,430,645,'厚书 · 左半部')]
    for index in range(11):
        journal.append(layer('journal-tab-' + str(index),'tab',58,245+index*44,86,36,'故事索引 ' + str(index+1)))
    journal.extend([layer('journal-grass','grass',464,818,90,135,'干草 · 麦穗与燕麦'),
                    layer('journal-flowers','flowers',150,798,140,210,'大朵干花 · 玫瑰与大丽花')])
    doc = {'format':FORMAT, 'schemaVersion':1, 'appVersion':VERSION,
           'id':'tray-journal-materials', 'name':'托盘与记录书 · 素材排版', 'assets':assets,
           'referenceProfile':{'kind':'tray-journal-v1', 'purpose':'素材位置参考，不自动修改游戏',
                               'sourceAssets':{'panel-asset-'+key:path for key,path in ASSETS.items()}},
           'pages':[{'id':'panel-tray','name':'托盘界面','width':520,'height':1040,'background':'#e6dfd0','revision':0,'layers':tray},
                    {'id':'panel-journal','name':'记录书界面','width':520,'height':1040,'background':'#e6dfd0','revision':0,'layers':journal}]}
    output = io.BytesIO()
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('project.json',json.dumps(doc,ensure_ascii=False,indent=2))
        for name,raw in payloads.items():
            archive.writestr(name,raw)
    return output.getvalue()


def ensure_project(store):
    """Seed a fresh store only. Opening again must preserve every designer edit."""
    doc = store.state()
    fresh = (doc['revision']==0 and not doc['assets'] and len(doc['pages'])==1
             and doc['name']=='寄往人间 · 页面排版' and doc['pages'][0]['name']=='主页'
             and not doc['pages'][0]['layers'])
    if not fresh:
        return False
    bundle = project_bundle()
    store.import_project({'epoch':doc['epoch'],'revision':doc['revision'],'clientId':'panel-studio-seed'},bundle)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port',type=int,default=18767)
    parser.add_argument('--data-dir',type=Path,default=EDITOR_ROOT/'.local'/'panel-materials')
    parser.add_argument('--no-browser',action='store_true')
    args = parser.parse_args()
    from server import main as serve
    argv = ['--port',str(args.port),'--data-dir',str(args.data_dir)]
    if args.no_browser:
        argv.append('--no-browser')
    serve(argv,initialize=ensure_project)


if __name__ == '__main__':
    main()
