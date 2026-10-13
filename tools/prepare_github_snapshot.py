"""Export only the isolated lab snapshot into an already inspected independent checkout.
Never reads live formal project files, credentials, Git configuration, or runtime caches.
"""
from pathlib import Path
import datetime, hashlib, json, re, shutil, subprocess

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT/'deliverables/github-checkout'
PREFIX='experiments/3d-lab'
DEST=REPO/PREFIX
UTC=datetime.datetime.now(datetime.timezone.utc).isoformat()
def git(*args):
    return subprocess.check_output(['git',*args],cwd=REPO,text=True,encoding='utf-8').strip()
assert git('branch','--show-current')=='experiment/3d-lab'
assert not DEST.exists(), 'Do not overwrite an existing branch snapshot'
baseline=git('rev-parse','HEAD')
assert baseline=='d1b2d06cb31948a33b1e8d7bfbadb858550255af'
assert not git('status','--porcelain'), 'Independent checkout must be clean'
DEST.mkdir(parents=True)
records=[]
def copy(relative):
    source=ROOT/relative; target=DEST/relative
    assert source.resolve().is_relative_to(ROOT) and not source.is_symlink()
    data=source.read_bytes(); digest=hashlib.sha256(data).hexdigest()
    target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
    assert source.read_bytes()==data==target.read_bytes()
    records.append({'path':relative,'lab_source':relative,'bytes':len(data),'sha256':digest,'copied_utc':UTC})
for folder in ('scripts','urhox-libs'):
    for p in sorted((ROOT/folder).rglob('*.lua')):
        if p.name not in ('ResourceProbe.lua','RuntimeEvidence.lua'):
            copy(p.relative_to(ROOT).as_posix())
for relative in ('tools/run_checks.py','docs/3d-interface-map.md','docs/evidence/3d-lab-r3/offline-checks.json','docs/evidence/3d-lab-r3/offline-checks.log'):
    copy(relative)
snapshots=[]
for filename in ('source-snapshot.json','library-snapshot.json'):
    old=json.loads((ROOT/'docs/evidence/3d-lab-r3'/filename).read_text(encoding='utf-8-sig'))
    for item in old['files']:
        dst=Path(item['destination'])
        if dst.is_relative_to(ROOT):
            rel=dst.relative_to(ROOT).as_posix()
            if any(r['path']==rel for r in records):
                snapshots.append({'path':rel,'formal_source_relative':str(item['source']).replace('D:\\taptap\\To-the-Human-World\\','').replace('\\','/'),'initial_source_sha256':item['sha256'],'initial_copy_utc':item['copied_at']})
native=json.loads((ROOT/'docs/evidence/3d-lab-r3/NATIVE_ACCEPTANCE.json').read_text(encoding='utf-8'))
native.pop('formal_binding_sha256',None)
native['note']='Historical native validation of the coarse experimental build. Program-driven checks and timed still frames, not human UI dispatch, video smoothness, mobile acceptance or visual approval. User rejected this art direction. Reference inspection progressed afterward; see README.'
(DEST/'docs/evidence/3d-lab-r3/native-summary.json').write_text(json.dumps(native,ensure_ascii=False,indent=2),encoding='utf-8')
(DEST/'SOURCE_MANIFEST.json').write_text(json.dumps({'artifact':'D3-LAB-20261012-r3-v01','export_utc':UTC,'remote_base':baseline,'formal_head_at_initial_snapshot':'c59c59044218e6be626edb86f66dc950f6943bd2','source_is_dirty_worktree_snapshot_not_git_commit':True,'source':'Existing isolated Lab files only; no newly changed formal 2D files were read/copied for this export.','copied_files':records,'original_source_provenance':snapshots},ensure_ascii=False,indent=2),encoding='utf-8')
(DEST/'.gitignore').write_text('''.git/
.maker-mcp/
.project
.runtime/
.preview-home/
.tmp/
tools/tmp/
tools/vendor/
__pycache__/
*.pyc
*.pyd
*.dll
*.exe
*.zip
User/
ResCache/
logs/
deliverables/
''',encoding='utf-8')
(DEST/'README.md').write_text('''# 寄往人间 · 独立 3D 试验（美术未验收）

版本：`D3-LAB-20261012-r3-v01`。本分支仅在 `experiments/3d-lab/` 新增隔离样片，根目录的 2D 项目沿用远程基线，未替换入口、绑定、素材或业务文件。正在开发的 Windows 2D 工作区没有切分支、提交或 stash。

本快照来自现有 `D:\\taptap\\To-the-Human-World-3D-Lab`，业务源最初复制自正式项目当时的未提交工作树，不能仅用旧 Git HEAD 表示该来源。逐文件哈希、复制时间及远程基线见 `SOURCE_MANIFEST.json`。此提交只保存当前已实现成果，不包含随后计划的美术改进。用户已明确否定当前粗糙画面，不能视为风格通过。

## 已实现与验证

- 同一 3D 房间的 Home、Seaside、Brew 固定镜头；网兜去码头、炉子去桌面、返回经过同一空间。
- 一套真实 GameSession / PlayModel；真实商店、失败不扣款、读信、剪词与重复剪口保护。核心业务没有重写。
- SaveSystem 使用白名单内存存储；不访问正式玩家存档。关闭或刷新即丢失会话，未验证跨进程恢复。
- 70 项离线检查通过。历史 Windows 原生测试包含真实业务回调及 960×540、1260×540、840×630 每组 31 项检查；证据摘要在 `docs/evidence/3d-lab-r3/`。
- 历史原生证据是程序驱动的拾取/面板回调及带时间截图，不是用户手动操作、完整 UI 事件链、正常速度录屏或手机验收。

## 运行与复现

使用已安装的 TapTap Maker CLI / UrhoX Runtime；本仓库不会安装软件、自动绑定应用或自动启动预览。**不要以仓库根目录或正式 2D 项目作为 3D 的 target-dir。**

1. 保持现有 2D 目录原样；在本独立检出中将 `experiments/3d-lab` 作为试验目录。入口为 `scripts/main.lua`，普通使用保持 `scripts/lab/QAConfig.lua` 的 `enabled=false`。
2. 该目录没有应用绑定或个人认证文件。使用官方本地准备流程，并为该独立目录取得自己的明确授权配置；禁止复制正式绑定或玩家存档。若 CLI 要求创建/绑定应用，先取得所有者授权。
3. 已具备独立配置后运行 `maker preview prepare --target-dir <独立试验目录>`；随后按已安装 CLI 支持的官方 `maker preview run --target-dir <独立试验目录> --runtime <独立 Runtime 副本> --duration-ms 600000 --json`。Runtime 使用专用可写目录；`TAPTAP_MAKER_HOME`、`TEMP`、`TMP` 也指定到试验目录内，避免安装目录产生日志/缓存。
4. 已存在专用预览时先 `maker preview status --target-dir <独立试验目录> --json`，确认仍存活再 refresh。用户停止后不得自动重启。不操纵系统鼠标键盘或其他窗口。
5. 已有 Python 与 Lupa（Lua 5.4）时，从此目录运行 `python tools/run_checks.py`。不随仓库传送本机 Python 扩展、Runtime 二进制或自动安装依赖。该检查是离线逻辑验证，不是原生渲染证明。

## 当前限制与后续

当前 146 个程序几何实例、15 个基础材质；画面比例、材质纹理、物件细节和暖光层次都需重做。接下来只改一版 Home，并交实际引擎截图供方向确认后再扩展。

四个 Library 输入在 Windows 官方材料化流程中失败。后续只读查到同名本地原图并看过像素：主页、炉子、船扣除 PNG 的 caBX 辅助块后，其尺寸和字节数与附件记录完全匹配，但尚无远端像素哈希证明；捞网仍是版本未确认候选。此快照不包含这些输入图，也未按它们修改模型。

原生运行仍报 Day / Dusk 环境贴图与 themis_x64.dll 缺失。诊断已确认官方索引具有 QualityLow 环境贴图，但此快照尚未应用修复；不可把工具运行错误标成全部通过。完整原始日志、应用绑定、凭据、玩家存档、缓存、安装日志和大截图包均未提交。未创建 PR、未合并 main、未发布游戏、未通过 A2 独立审查。

真实接口和后续投料/熬制/重置/发货映射见 `docs/3d-interface-map.md`。
''',encoding='utf-8')
patterns=[rb'tmpct_[A-Za-z0-9]{12,}',rb'gh[pousr]_[A-Za-z0-9]{20,}',rb'github_pat_[A-Za-z0-9_]{20,}',rb'AKIA[A-Z0-9]{16}',rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',rb'https?://[^\s/"<>]+:[^\s/@"<>]+@',rb'Bearer [A-Za-z0-9._-]{24,}',rb'X-Amz-Signature=[A-Za-z0-9]+']
allfiles=[p for p in DEST.rglob('*') if p.is_file()]
hits=[]
for p in allfiles:
    b=p.read_bytes()
    assert len(b)<2*1024*1024,(p,'unexpected large file')
    for index,pattern in enumerate(patterns):
        if re.search(pattern,b): hits.append({'path':p.relative_to(DEST).as_posix(),'pattern_index':index})
assert not hits,json.dumps(hits)
report={'utc':UTC,'destination':str(DEST),'branch':'experiment/3d-lab','remote_base':baseline,'files':len(allfiles),'total_bytes':sum(p.stat().st_size for p in allfiles),'largest_bytes':max(p.stat().st_size for p in allfiles),'secret_pattern_hits':hits,'source_was_lab_only':True,'remote_files_modified_or_deleted':False}
(ROOT/'deliverables/github-snapshot-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=True))
