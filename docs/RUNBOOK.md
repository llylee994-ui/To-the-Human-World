# 当前状态：v035 完整场景已运行，人工验收暂停（2026-10-13）

以本段和 [实际运行报告](D3-v035-native-acceptance-report.md) 为最新事实；下文旧小样、暂停及未启动说明为历史记录。

完整包 90 网格 / 3,209,455 三角面 / 10,790 源物件已在游戏显示；官方 prepare 的 150 资源核验通过。attempt 06，PID 56268，session 46ffe50f-e458-49ab-8cff-855a9dcac2c0；114.005 秒完成场景加载，相机及 8/8 程序入口通过。用户已暂时暂停人工测试，自动鼠标操作停止；真实点击全覆盖和业务验收尚未完成。存档为 Lab 纯内存，正式 2D 未改，未推送。

启动使用根目录 Start-3D.cmd，已运行时返回现有 PID，不重复启动。当前持续运行，退出码尚不存在；未把离线或程序化结果当作人工验收。

以下旧 run 命令有十分钟时限；普通完整 3D 版请用根目录 Start-3D.cmd。

# 运行与续接

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
