from pathlib import Path
import datetime
root=Path(__file__).resolve().parents[1]; now=datetime.datetime.now(datetime.timezone.utc).isoformat()
runbook=r'''# 运行与续接

D3-LAB-20261012-r3-v01。唯一任务 `01a12c24-a725-712b-ba7d-df58430f5098`；不要再建执行任务。正式工程只读。先读 LAB_STATUS、REPORT、行动记录及 NATIVE_ACCEPTANCE。

## 当前本机入口

脚本入口 `scripts/main.lua`；`scripts/lab/QAConfig.lua` 必须为 `return {enabled=false}` 才是普通样片。默认不会自动收信/购买/剪词。现有独立app已成功绑定，不能复制正式配置或再次init。应用/官方登录缓存授权已解决，无需再询问。

从Lab目录执行：

```powershell
& .\tools\run_preview.ps1 -Action status
# 用户明确要打开预览，或者记录清楚的授权测试时：
& .\tools\run_preview.ps1 -Action run
# 仅对仍存活、已核实为本Lab的预览：
& .\tools\run_preview.ps1 -Action refresh
& .\tools\run_preview.ps1 -Action logs
```

封装实际调用本机 Node 与已安装 Maker0.0.36 的 `dist/maker.js preview run --target-dir D:\taptap\To-the-Human-World-3D-Lab --runtime D:\taptap\To-the-Human-World-3D-Lab\.runtime\UrhoXRuntime.exe --duration-ms 600000 --json`。**最后预览已按十分钟时限结束，目前没有本任务预览存活；不要自动重开。用户停止的预览不得自行重启。** refresh会重启本轮Runtime并丢失内存进度，只能用于确认存活的试验session，不是恢复玩家存档。

运行库为现有同版本8文件副本，未安装；`runtime-copy.json`有来源/hash。脚本只设置进程环境：TAPTAP_MAKER_HOME=Lab/.preview-home，TEMP/TMP=Lab/tools/tmp，已安装Python绝对路径。保留Lab本身的独立绑定，不新建/改绑。首次prepare缺配置时已由官方仅补齐受管理副本，没有手写平台身份或替换正式main.lua。

官方run因公共资源ERROR返回FAIL；这与Lua程序已启动/业务断言通过并不矛盾，不能把总体工具状态改成PASS。保留 Day/Dusk DDS 和 themis DLL 的未解决问题。

## 实际操作

1. Home点门边网兜→镜头穿过左门到码头；顶部返回药铺。门口没有额外点击入口。
2. 点海上同一帆船→商店，余额/库存/价格来自真实查询。海盐5金币，初始30。
3. 码头“捕捞来信”→明确按“开始捕捞”才触发真实Receive并扣次数。关闭/导航不自动收信。
4. 返回Home点纸→真实信件；向下滚到委托要求及剪词区。剪同一位置一次，关闭重开保留剪口；词卡面板可查。
5. 点炉子→同一桌面Brew，顶部返回。进镜头不投料/熬制/结算。当前仅保留独立锅口测试与未来接口。

## 可复跑验证

```powershell
$env:PYTHONIOENCODING='utf-8'
& C:\Python313\python.exe tools/run_checks.py
& C:\Python313\python.exe tools/check_lsp.py
& C:\Python313\python.exe tools/finalize_evidence.py
```

70项业务/路径/适配检查；LSP诊断保留Warning。不要重跑snapshot_source覆盖Panels适配。原生程序测试需显式启用QAConfig，并在本任务记录原因/会话/期间；完成必须关闭QA并重新验证默认零业务写入。每轮只有一套GameSession和PlayModel。

原生尺寸通过Maker实际window.json格式设置：`python tools/set_preview_size.py 960 540`，然后只刷新已确认存活的本试验。已验证960×540、1260×540、840×630，最终配置恢复960×540。Graphics:SetMode在此Runtime返回nil/false，不能依赖它。配置只改Lab预览尺寸，不改应用身份。

`tools/capture_lab_window.ps1 -RuntimeId <已核实本Lab PID> -Frames 120 -IntervalMs 700 -Series <本地系列名>` 只读取该进程且标题匹配的HWND；不发送系统输入/焦点/窗口移动。原始PNG与UTC保留；PrintWindow=true不自动代表可见场景（加载首帧曾黑），须实际查看。引擎SavePNG失败路径已从普通入口移除，不重复尝试。

`tools/collect_native.py --session <真实ID> --reload <整数> --label <证据目录>` 只读官方日志。历史session新一轮后不可再用当前CLI取日志时，用 `--saved`解析已保存原件，不能冒充实时状态。Maker将业务tokenId识别成token并截断过一条Cut返回；汇总保留完整PASS断言头、原始截断行，未恢复被遮蔽字段。

## 下轮精确起点

四图官方Windows材料化失败，references/incoming仍无可读图；按照reference-map已有Library ID与当前受支持materialization路线恢复，不重新上传输入、不猜URL、不改helper、不用历史图。实际逐张看像素后再修正布局/炉/网/船、手绘材质和暖光。当前截图仅证明默认样片实际运行。

随后排查公共Day/Dusk环境贴图及themis错误，补人工输入分发/遮挡边缘、触控与手机性能。不要安装新软件、改系统设置或联系A2/C/创意窗口。报告/截图/审查ZIP已有Library身份，修改输出应guarded replace，不能重复create。素材生成尚未使用create_3d_asset，无待continue或付费任务。

审查包包含源码、证据、104张选取的未改动原生帧、gallery和来源hash；为避免凭据和大规模冗余，不包含绑定、.git、.preview-home、Runtime发行文件和全部重复原始帧。完整原始帧及本机可运行Runtime保留Lab。
'''
(root/'docs/RUNBOOK.md').write_text(runbook,encoding='utf-8')
handoff=f'''# 同一任务续接状态 · {now}

唯一任务 `01a12c24-a725-712b-ba7d-df58430f5098`。最新事实以 LAB_STATUS / REPORT / NATIVE_ACCEPTANCE 为准，旧绑定预检已解除。默认QA=false；最后session `9148828c-4727-49f8-9f2b-41b66fcf1d0b` reload3，在官方600000ms上限结束，当前无本任务运行进程；不要自动重开。

已原生：同空间三镜头、三比例各31检查、真实购买与失败原子性、读信剪词幂等/重开、默认两个5秒窗口零业务写入。70项离线通过，LSP0Error/92Warning，395来源hash未变。104张选取原生时间帧见native/gallery；完整原始帧留Lab。普通入口scripts/main.lua，启动脚本tools/run_preview.ps1。

未解决：四张最新版参考未材料化/未见像素；Day/Dusk DDS缺失、themis DLL加载错误；人工/手机/正常速度录屏未验。当前几何/材质是文字约束默认值，未审美验收或A2通过。

新增明确授权已执行：独立Maker app绑定与官方现有登录缓存更新。无安装/发布/远端构建/系统输入/子代理。初轮Runtime日志缓存曾写安装目录，后改用Lab/.runtime副本；不可宣称从未发生工具外部写入。正式存档从未接入，SaveSystem仅内存。

Library输出：报告libfile_2b7899edaabc819199c5b25a46bd693c；ZIP libfile_a96a3b502d5c8191a8fab49a5d70d685；四张原生图片回执deliverables/library-native-images-20261012.json。以最后replace回执确认版本，勿再次create。Windows xattr回写仍失败，上传成功本身已由Library确认。

下一步：恢复官方Windows参考传递→实际看四图→对图修正/资源排查→人工及手机验证。保留已有代码/证据，不新建任务或生成重复素材。
'''
(e:=root/'docs/evidence/3d-lab-r3/HANDOFF_STATE.md').write_text(handoff,encoding='utf-8')
for name in ('BLOCKERS.md','BINDING_PREFLIGHT_20261012.md'):
    path=root/'docs/evidence/3d-lab-r3'/name; old=path.read_text(encoding='utf-8')
    note='> 2026-10-12 原生阶段更新：本文件以下为历史核查原件。独立应用绑定与官方现有登录缓存更新均已明确获授权并成功完成，Runtime已运行。当前仅Library参考传递、公共资源错误与人工/手机证据缺口；详见REPORT和NATIVE_ACCEPTANCE。首次Runtime安装目录日志/缓存副作用已记录，后续已改为Lab内运行副本。\n\n'
    if not old.startswith(note): path.write_text(note+old,encoding='utf-8')
action=root/'docs/actions/2026-10-12-3d-lab-r3.md'
with action.open('a',encoding='utf-8') as f:
    f.write(f'''\n\n## {now} 原生验证收口\n- P0真实模型/材质/暖光/中文已显示并实际查看。Windows原生Home、Brew、读信剪口、商店PNG已上传Library，见deliverables/library-native-images-20261012.json。只读自己的Runtime窗口，无系统输入。\n- session99526466... reload1真实业务39条断言通过（后续SetMode尺寸测试失败另列）：购买扣5、UNKNOWN_ID/SHOP_STOCK_SHORT/CURRENCY_SHORT原子失败、明确Receive扣1、Read/Cut/重复剪/重开保留、导航不改业务。原始重复剪返回的业务tokenId触发Maker日志token脱敏并截断JSON，汇总只解析完整PASS头，保留原件，未恢复任何被遮蔽内容。\n- Graphics:SetMode两参数/完整签名分别nil/false，转用Maker安装源码确认的window.json配置格式，仅改Lab尺寸，再走官方refresh。session9148828c... reload0/1/2分别960×540、1260×540、840×630，每组31断言、COMPLETE且无FAIL；长文滚到底、三镜头往返均有原生帧。\n- QAConfig已恢复enabled=false，reload3普通入口两个5秒窗口均Home、memoryWrites=0；十分钟时限结束，未重开。三次run均由自己设置的CLI时限收口，没有用户停止事件。默认入口移除失败的自动SavePNG尝试，RuntimeEvidence.lua作为实验代码保留但不加载。\n- 最后70项离线检查通过；59文件Lua编译；LSP0Error/92Warning；395正式来源hash无变化、正式绑定hash一致。实际查看21:9 Home和4:3 Home/长列表；加载最早一帧曾黑，未作为已显示证据。\n- 原生规模146实例/15材质/25唯一模型/5206顶点/25620索引/0项目纹理。GPU RTX4060Laptop，D3D11。119个5秒Update窗口均值16.84–17.58ms，最大TimeStep85.69ms；不是GPU时间或流畅性证明。\n- 资源缺失仍为Day/Dusk环境DDS和themis DLL；已查Lab ResCache仅有shader缓存，未把缺失改成通过、不安装补件。四参考PNG官方材料化失败仍在，没有再重试同一失败、不用旧图替代。\n- 104张原图及连续时序帧选入审查包，原始字节未修改；native/selected/manifest记录来源/UTC/hash，gallery可本地打开。工具状态ERROR仍使preview run总体FAIL，与独立业务断言状态分别保留。\n- 当前无审批等待；整体未审美验收、未A2审查、未手机验证。最小下一步为同一任务恢复官方参考传递并实际逐图查看，再修正视觉/资源与补人工证据。\n''')
print('Updated RUNBOOK, handoff, historical blocker notices and append-only action record.')
