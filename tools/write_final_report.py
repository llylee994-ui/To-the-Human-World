"""Write current handoff only after native evidence and safe default are verified."""
from pathlib import Path
import json,re,datetime,hashlib
root=Path(__file__).resolve().parents[1]; e=root/'docs/evidence/3d-lab-r3'
def read(name): return json.loads((e/name).read_text(encoding='utf-8-sig'))
aspects={key:read(f'aspect-{key}-official/summary.json') for key in ('16x9','21x9','4x3')}
assert all(x['complete'] and not x['failures'] and not x['unparsed_qa'] for x in aspects.values())
assert 'enabled=false' in (root/'scripts/lab/QAConfig.lua').read_text(encoding='utf-8')
default=read('default-native-official/summary.json')
assert len(default['frame_logs'])>=2 and all('memoryWrites=0' in x and 'camera=Home moving=false' in x for x in default['frame_logs'])
assert not default['native_qa']
offline=read('offline-checks.json'); lsp=read('lsp/diagnostics.json'); integrity=read('integrity.json')
assert offline['status']=='PASS' and len(offline['results'])==70 and not integrity['offline_test_source_mismatches']
assert not integrity['source_changed_since_copy'] and lsp['app_errors']==0
binding=Path(r'D:\taptap\To-the-Human-World\.maker-mcp\config.json')
formal_hash=hashlib.sha256(binding.read_bytes()).hexdigest()
assert formal_hash=='5f8318d48947e5f45f983d911f3e97d0f870ab4ab4505beea5db392eb7741b6f'
business=read('native-qa-r1-official/summary.json')
passed={x['name'] for x in business['native_qa'] if x['status']=='PASS'}
for name in ('purchase debits exact price','unknown purchase atomic','stock rejection atomic','funds rejection atomic','explicit Receive spends one','cut creates exactly one card','same span duplicate safe','reopen retains gap','Brew reached no auto brew','separate rim'): assert name in passed,name
allframes=business['frame_logs']+default['frame_logs']+[v for a in aspects.values() for v in a['frame_logs']]
measurements=[tuple(map(float,m)) for line in allframes for m in re.findall(r'meanMs=([\d.]+) worstMs=([\d.]+)',line)]
perf={'mean_window_ms_min':min(x[0] for x in measurements),'mean_window_ms_max':max(x[0] for x in measurements),'worst_observed_timestep_ms':max(x[1] for x in measurements),'windows':len(measurements),'scope':'5-second Update TimeStep aggregates while program-driven QA and own-window capture run; not GPU timing or smoothness proof.'}
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
device=read('device.json'); device.update(native_lab_run=True,native_lab_resolutions=[[1304,734],[960,540],[1260,540],[840,630]],native_lab_frame_measurements=perf,selected_gpu='NVIDIA GeForce RTX 4060 Laptop GPU',renderer='Direct3D 11',hardware_source='Native Runtime logs; CPU CIM query remains unavailable',engine='bf3316fd2 / binary 1032014 / engine-res maker_validate_window.0923',updated_utc=now)
(e/'device.json').write_text(json.dumps(device,ensure_ascii=False,indent=2),encoding='utf-8')
native_summary={'version':'D3-LAB-20261012-r3-v01','utc':now,'business_checks_passed':sorted(passed),'aspects':{k:{'complete':v['complete'],'pass_count':v['pass_count'],'session_id':v['session_id'],'reload_id':v['reload_id']} for k,v in aspects.items()},'default_no_automatic_business':True,'formal_binding_sha256':formal_hash,'performance':perf,'reference_pixels_viewed':False,'overall':'PARTIAL_ACCEPTANCE_REFERENCE_AND_HUMAN_REVIEW_PENDING'}
(e/'NATIVE_ACCEPTANCE.json').write_text(json.dumps(native_summary,ensure_ascii=False,indent=2),encoding='utf-8')
report=f'''# 《寄往人间》独立 3D 试验交付报告

**D3-LAB-20261012-r3-v01｜已有实际可运行样片；整体仍需修改及补充证据，未宣称审美验收或 A2 通过。**

更新：{now}。唯一执行任务 `01a12c24-a725-712b-ba7d-df58430f5098`；来源线程 `01a100a3-a73b-744f-9fcc-4080f267b036`。本机目录 `D:\\taptap\\To-the-Human-World-3D-Lab`。旧 r3 中间报告保留于 `deliverables/history`；初次检查没有既有 r1/r2 成果，未覆盖未知内容。

## 模块定位、本轮工作与原因

这是独立 UrhoX 药铺样片，用来验证同一空间三镜头和既有业务的复用成本。正式 2D 计划不变，不自动合入，不扩展为整款 3D 游戏。

建立真实几何的房间、左门、无台阶木码头、右桌/后沿架、炉、网、纸和同一帆船；146 个网格实例、15 个 PBR 材质，暖色方向光与炉火点光。Home→网兜→穿门到 Seaside，Home→炉子→同一工作台 Brew，均可返回。外观网格与稳定触控 ID 分离，模态/拖拽/镜头过渡阻挡场景输入，结构盒与 native 三角射线处理遮挡。

只复用一套真实 GameSession/PlayModel；通过 `SaveSystem.New(memory)` 注入五种试验存储键白名单，无磁盘回退。真实商店、信件正文/委托和剪词已接通。投料、熬制、重置、发货只交接口映射与独立锅口区域，未重写经济/订单。代码入口 `scripts/main.lua`，默认 `QAConfig.enabled=false`，默认不会自动购买、捕捞或剪词。

## 完成依据与阶段结果

| 阶段 | 判定 | 实际证据及边界 |
|---|---|---|
| P0 | 显示通过，资源问题保留 | 官方 prepare / Runtime 启动成功；已实际看见模型、材质、暖光和中文。`native/20261012-lab-window-r0.png` |
| P1 | 程序驱动原生通过；人工输入未验 | 三固定镜头同空间往返；三比例 native 拾取/目标位置/返回均完成。`aspect-*-official/summary.json` 与连续帧 |
| P2 | 首轮可看，需修改 | 木、墙、金属、陶罐、海面、暖光已显示；四张最新参考未材料化，所有比例与造型仍是文字约束默认值 |
| P3 | 程序驱动原生通过 | 真实商店购买/原子失败、Receive、Read、Cut/重复剪/重开；`native-qa-r1-official`。不是人工触控或跨进程恢复证明 |
| P4 | 部分完成 | 三比例、原生日志、时间帧、规模与帧耗时、哈希/接口/限制齐备；没有正常速度录屏、手机测试或人工操作证据 |

所有证据相对根目录 `docs/evidence/3d-lab-r3/`。原生总索引 `NATIVE_ACCEPTANCE.json`；离线 **70项通过**，{offline['syntax_files']}个应用 Lua 文件编译通过；LSP 默认级别 **{lsp['app_errors']} Error / {lsp['app_warnings']} Warning**，保留诊断，不声称 Maker 严格零警告。

真实业务：初始金币30，海盐5金币，按钮购买扣5；`UNKNOWN_ID`、`SHOP_STOCK_SHORT`、`CURRENCY_SHORT` 均不增加保存写次数、不改变失败前快照。测试进度用真实 Receive 准备，明确扣一次捕捞；Read 真实信件后首剪 `body:1` 产一张卡，重复剪 `changed=false`，重开保留剪口。导航及面板开关不自动收信/奖励/熬制。测试模式与普通入口分开，关闭QA后的原生多窗口帧日志保持 Home、memoryWrites=0。

三比例实际 client 尺寸：960×540（16:9）、1260×540（21:9）、840×630（4:3）。各完成Home五物件射线、读信长文滚到底、网兜→码头→返回、炉子→Brew→返回、导航状态不变、正式存储键被拒绝。每组 {aspects['16x9']['pass_count']}/{aspects['21x9']['pass_count']}/{aspects['4x3']['pass_count']} 条原生日志断言。原生回调为程序调用，不是系统鼠标/键盘事件，未证明完整UI命中分发或手机触控。

## 实际画面与运行条件

- [原生主页](https://chatgpt.com/api/library/files/libfile_82e9f28d044081918b3035560115c100/download)
- [同一炉子近景](https://chatgpt.com/api/library/files/libfile_7f835f5979fc81918c2fd2f46f3bda66/download)
- [真实读信剪口](https://chatgpt.com/api/library/files/libfile_c3026fc13f6c8191a53ce30c94736ce6/download)
- [真实商店](https://chatgpt.com/api/library/files/libfile_1b4bf42b4d948191bd0f64098f355a39/download)

本机 Windows 10.0.26100；Runtime 选择 NVIDIA GeForce RTX 4060 Laptop GPU、Direct3D11；CPU型号查询未获结果。UrhoX bf3316fd2 / binary1032014；Maker0.0.36；prepare builder a6a4145ac8be26d9385f3a318032cc79009f8a79。25个唯一程序模型合计5206顶点、25620索引；146为实例数，不是GPU draw call数。项目纹理0，另使用公共引擎材质/字体资源。

已采集{perf['windows']}个5秒窗口的Update TimeStep：均值范围 {perf['mean_window_ms_min']:.2f}–{perf['mean_window_ms_max']:.2f}ms，最大单次 {perf['worst_observed_timestep_ms']:.2f}ms。包含自动测试/截图开销，不是GPU计时，不能据此保证流畅度。帧由仅针对已确认Lab HWND的PrintWindow读取，无桌面或其他窗口采集、无输入/焦点/位置控制。`native/gallery.html` 与 `native/selected/manifest.json` 提供未改动PNG、UTC与SHA256；带时间静态连续帧不能证明正常速度播放流畅。桌面结果不代表手机。

## 已解决问题、真实阻塞与必须修改项

1. 独立应用绑定和官方现有登录缓存更新已按新增明确授权完成。首次token请求超时，确认无绑定后仅重试一次成功，app=`52356e67-6bfa-415e-862d-8203b5fcffc9`。devkit下载fetch failed，已有代码/库仍能运行。未再安装、发布或远端构建。init自动创建Lab自身.git，未提交/推送。
2. 引擎截图TakeScreenShot=true但SavePNG=false；不重复声称保存成功，改用只读本试验窗口取证。两参数及完整参数Graphics:SetMode未改变尺寸，改用已安装Maker的window.json配置格式与官方refresh，三比例实际生效。原生测试脚本误用测试替身GetProps已改为真实Widget.props；失败证据保留。
3. **仍需修复资源完整性**：公共 `Cube/Day/DaySpecularHDR.dds`、`Cube/Dusk/DuskSpecularHDR.dds` 缺失，以及启动 `themis_x64.dll` 加载错误。样片可显示，但官方run按ERROR日志返回FAIL，不能冒称零错误通过。未安装新组件或用其它引擎替代，未伪造资源。
4. **最新版参考仍阻塞P2验收**：官方Windows Library helper四图各一次材料化均因`os.setxattr`不存在失败；目标目录实查为空。五个附件映射保留在reference-map.json，四图均未实际看像素，没有历史图片替代。需官方受支持的Windows传递路线恢复；不需要重传Library输入或新增多视图才能启动。
5. 必须补充人工点击/触控、完整UI输入分发与关闭穿透、长文手感、遮挡边缘和手机性能验收；本轮只验证程序调用及实际画面。锅/船/网比例、手绘纹理、水面、金属高光和炉口细节待真实参考修正。当前大面积木板条纹、简化岸线与金属高光属于可调整默认值。

## 隔离、操作步骤与审计边界

正式当前工作树基线HEAD=`c59c59044218e6be626edb86f66dc950f6943bd2`仅表示提交标识，395个复制来源逐文件哈希复核未变；正式绑定SHA256=`{formal_hash}`。只改试验副本Panels以隐藏后续玩法，核心/系统/数据/PlayModel未改。未复制正式.git、玩家存档、凭据、绑定或预览状态。

首轮官方Runtime曾自动向其安装目录写日志/缓存，不能说完全无工具侧外部写入。已将现有发行包8个引擎文件（105087790字节）逐字节核对并复制到Lab/.runtime，排除User/logs/ResCache；后续自身输出留Lab。Maker HOME=.preview-home，TEMP/TMP=tools/tmp。官方init已有缓存写回是用户另行明确授权，未读取/输出/复制其内容。保存只是单会话内存，刷新/关闭即丢失；同内存Reload不等于跨进程恢复。

启动或刷新命令详见 `docs/RUNBOOK.md`，可直接使用 `tools/run_preview.ps1`。入口默认QA关闭。操作：网兜去码头，海上同船开店；明确“捕捞来信”才收信；返回点信纸读/剪；炉子去Brew，顶部返回。不增加门外入口、自由相机、人物、战斗或抽屉连续动画。官方run有十分钟上限；本轮前两次均为工具时限结束，用户停止后不得自行重启。

## 待用户决定、A2材料与后续成本

当前无待审批操作，也无新增工具/安装/账户请求。**待用户决定：暂不提出新的审美选择。** 先解决已有参考的官方传递缺口并对图修正，再请用户判断是否继续3D；当前默认风格不算用户接受。

A2材料：本报告、`docs/3d-interface-map.md`、`docs/RUNBOOK.md`、行动记录、NATIVE_ACCEPTANCE、原生日志/失败历史、三比例连续帧与gallery、70项离线检查/LSP/源及Runtime哈希。由用户转发，本任务未联系A2/C/创意窗口；执行复核不等于独立审查。

可复用：固定镜头路线、几何/代理/稳定ID、输入适配、隔离存储、真实业务闭环和原生验证工具。继续成本主要是参考驱动的模型/纹理/光照修正、公共资源问题排查、真实触控/跨比例细化与移动端性能；后续投料/炼药可沿现有PlayModel接入，无需重写库存/经济。最小下一步是在同一任务恢复四图受支持材料化并实际逐张查看，再修正上述视觉与资源问题，补人工/手机证据；不另开任务或重复生成资产。
'''
(root/'REPORT.md').write_text(report,encoding='utf-8')
status=f'''# 寄往人间 — 独立 3D 试验

**D3-LAB-20261012-r3-v01｜已有可运行样片，整体部分验收；参考/资源/人工与手机验证待补。** 更新 {now}。

唯一任务 `01a12c24-a725-712b-ba7d-df58430f5098`，来源 `01a100a3-a73b-744f-9fcc-4080f267b036`。正式工程只读，所有实现留Lab。不创建子代理或其他执行任务、不联系其它窗口、不提交/推送/安装/远端构建、不使用系统输入。

P0实际几何/光照/中文显示通过，资源错误保留；P1三比例三镜头程序驱动原生通过；P2首轮已可看但四图未见像素；P3真实购买/失败/读信/剪词原生通过，内存隔离；P4已有日志/带时间帧，未有正常速度录屏、人工或手机结果。

70项离线检查通过；LSP {lsp['app_errors']} Error/{lsp['app_warnings']} Warning；395来源哈希未变。app=`52356e67-6bfa-415e-862d-8203b5fcffc9`，独立绑定及官方已有登录缓存更新已授权且完成，正式绑定不变。当前没有审批等待。旧“绑定授权阻塞”记录是历史。

普通入口 `scripts/main.lua`；`QAConfig.enabled=false`，关闭QA后原生日志验证Home、memoryWrites=0。单套真实GameSession/PlayModel，SaveSystem内存slot d3_lab_r3，无磁盘回退，不证明跨进程恢复。运行程序 `.runtime/UrhoXRuntime.exe`，Maker HOME `.preview-home`、TEMP/TMP `tools/tmp`。首轮Runtime安装目录日志/缓存副作用已记录并改正。

真实阻塞/待办：四张Library参考因官方Windows os.setxattr错误未落盘，未看像素；Day/Dusk环境贴图及themis DLL报错；人工UI输入/遮挡边缘/手机测试未完成。默认形状和材质不是用户确认的审美。

最小下一步：同一任务读REPORT、行动记录和reference-map，恢复官方支持材料化→实际逐张看四图→对图修正→资源/人工/手机验收。只刷新经确认存活的试验session；用户停止后不得重启，不自动重开预览。

交付：REPORT.md；docs/3d-interface-map.md；docs/RUNBOOK.md；docs/evidence/3d-lab-r3/NATIVE_ACCEPTANCE.json；native/gallery.html；deliverables审查ZIP与Library回执。A2未审查、用户未接受最终审美、正式2D范围不变。
'''
(root/'LAB_STATUS.md').write_text(status,encoding='utf-8')
print(json.dumps({'report_bytes':len(report.encode()),'performance':perf,'formal_binding_unchanged':True},ensure_ascii=False))
