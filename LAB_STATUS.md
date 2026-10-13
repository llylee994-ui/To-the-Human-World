# 当前状态：v035 完整场景已运行，人工验收暂停（2026-10-13）

当前独立 Lab 本地分支为 `3d`；本地提交仅保存当前成果，不表示人工验收完成。

以本段和 [实际运行报告](docs/D3-v035-native-acceptance-report.md) 为最新事实；下文旧小样、暂停及未启动说明为历史记录。

完整包 90 网格 / 3,209,455 三角面 / 10,790 源物件已在游戏显示；官方 prepare 的 150 资源核验通过。attempt 06，PID 56268，session 46ffe50f-e458-49ab-8cff-855a9dcac2c0；114.005 秒完成场景加载，相机及 8/8 程序入口通过。用户已暂时暂停人工测试，自动鼠标操作停止；真实点击全覆盖和业务验收尚未完成。存档为 Lab 纯内存，正式 2D 未改，未推送。

启动使用根目录 Start-3D.cmd，已运行时返回现有 PID，不重复启动。当前持续运行，退出码尚不存在；未把离线或程序化结果当作人工验收。

# Latest probe status (2026-10-13T12:14:11.849347+00:00)

ZIP and all internal hashes PASS; extracted and actual pictures viewed. Actual probe parsed offline: 6 meshes, 8128 triangles, 8 invisible proxies. Native preview NOT started; latest host changes awaiting compile/staging. No download/connection blocker. See HANDOFF_V035_INDEPENDENT.json.

# Latest gate update (2026-10-13T11:38:43.028443+00:00)

This v035 isolated native preview is explicitly authorized but has NOT started. Required root ZIP `D3-v035-CustomGeometry-import-probe.zip` is absent. Authorization is persisted in HANDOFF_V035_INDEPENDENT.json and remains unused. Do not start old scenes or restart after user stop.

# Latest: v03.5 independent adapter step (2026-10-13T11:07:16.401014+00:00)

Independent code completed: 102 offline checks pass, 97 Lua files compile; real main `1cd0cdbec06487a5c60f109d5fd477198cfc8846` modules used with memory storage. Actual cloud v03.5 NOT loaded; no preview started. Expected probe ZIP absent=True. See `docs/D3-v035-independent-step-report.md` and `docs/evidence/v035-main-interface/HANDOFF_V035_INDEPENDENT.json`. All earlier scene/native evidence below applies only to those earlier versions.

# Latest checkpoint: v03.5 / GitHub main (2026-10-13)

Main pinned to `1cd0cdbec06487a5c60f109d5fd477198cfc8846`; contract and 8 Home targets confirmed from current code. New cloud v03.5 has NOT been imported or wired. Official Windows Library materialization failed at `os.setxattr` after one retry; target ZIP absent. No native preview started. See `docs/v035-export-contract.md` and `docs/evidence/v035-main-interface/checkpoint.json`. Earlier records below describe earlier local scenes and are not evidence for v03.5.

# 寄往人间 — 独立 3D 试验

**D3-LAB-20261012-r3-v01｜已有可运行样片，整体部分验收；参考/资源/人工与手机验证待补。** 更新 2026-10-12T04:57:21.594560+00:00。

唯一任务 `01a12c24-a725-712b-ba7d-df58430f5098`，来源 `01a100a3-a73b-744f-9fcc-4080f267b036`。正式工程只读，所有实现留Lab。不创建子代理或其他执行任务、不联系其它窗口、不提交/推送/安装/远端构建、不使用系统输入。

P0实际几何/光照/中文显示通过，资源错误保留；P1三比例三镜头程序驱动原生通过；P2首轮已可看但四图未见像素；P3真实购买/失败/读信/剪词原生通过，内存隔离；P4已有日志/带时间帧，未有正常速度录屏、人工或手机结果。

70项离线检查通过；LSP 0 Error/92 Warning；395来源哈希未变。app=`52356e67-6bfa-415e-862d-8203b5fcffc9`，独立绑定及官方已有登录缓存更新已授权且完成，正式绑定不变。当前没有审批等待。旧“绑定授权阻塞”记录是历史。

普通入口 `scripts/main.lua`；`QAConfig.enabled=false`，关闭QA后原生日志验证Home、memoryWrites=0。单套真实GameSession/PlayModel，SaveSystem内存slot d3_lab_r3，无磁盘回退，不证明跨进程恢复。运行程序 `.runtime/UrhoXRuntime.exe`，Maker HOME `.preview-home`、TEMP/TMP `tools/tmp`。首轮Runtime安装目录日志/缓存副作用已记录并改正。

真实阻塞/待办：四张Library参考因官方Windows os.setxattr错误未落盘，未看像素；Day/Dusk环境贴图及themis DLL报错；人工UI输入/遮挡边缘/手机测试未完成。默认形状和材质不是用户确认的审美。

最小下一步：同一任务读REPORT、行动记录和reference-map，恢复官方支持材料化→实际逐张看四图→对图修正→资源/人工/手机验收。只刷新经确认存活的试验session；用户停止后不得重启，不自动重开预览。

交付：REPORT.md；docs/3d-interface-map.md；docs/RUNBOOK.md；docs/evidence/3d-lab-r3/NATIVE_ACCEPTANCE.json；native/gallery.html；deliverables审查ZIP与Library回执。A2未审查、用户未接受最终审美、正式2D范围不变。


## 2026-10-12 GitHub 独立保存与美术优先级
用户明确授权目标仓库 https://github.com/llylee994-ui/To-the-Human-World 的独立3D分支提交和推送。本次仅解除该请求的 commit/push 禁止；正式2D仍只读。Lab 内新建独立检出，不共享2D Git元数据。以远程main d1b2d06cb31948a33b1e8d7bfbadb858550255af 为基线，仅新增 experiments/3d-lab 下135文件、3125667字节；暂存原字节/来源哈希/凭据特征/体积检查通过，70离线检查通过。已推送 experiment/3d-lab，远程SHA 6d4829df6d3af0b6c2f2d114dd7b32da9d6ab997 核对一致。无force、PR、合并、发布、2D切换/stash/reset/clean。证据见 deliverables/github-push-receipt.json 与 github-stage-review.json。
用户否定旧画面；先做一版Home原生截图等待方向确认，不扩展玩法。四张同名原图已逐张查看并保存原字节；主页/炉/船辅助caBX块解释大小差异，捞网版本待确认，映射 reference-local-map.json。最新帧仍旧画面，未宣称美术通过。分包暂停。临时ResourceProbe启动调用已移除；独立诊断文件保留。


## 2026-10-12 主页美术 A 中途交接
独立GitHub分支已成功推送，SHA 6d4829df6d3af0b6c2f2d114dd7b32da9d6ab997；远端核对一致。后续本地HomeArt/ArtTextures/DuskPreset/SceneView/World/CameraRig与SkyUtils增量尚未提交。已有首张实际Home截图Library libfile_b0c43d58a38c8191be8cba00999f9de4（902552字节），不是概念图，用户审美未确认。更新材质/光照/桌柜/炉型、植物和玻璃器物；70离线通过，LSP0Error/83Warning。最新b0原生帧刚取证，尚待目视与真实拾取回归，不把它标为完成。QA=false；专用预览有10分钟自动时限。准确session/PID、待办和下一步见 docs/evidence/3d-lab-r3/HANDOFF_HOME_ART_20261012.json。


## 2026-10-12T06:05:32.654262+00:00 新主参考/拒绝旧方向
新图libfile_6ea7753ee7a48191aa842fadeeb7db67与本机原件RGBA哈希完全相同，已实际查看并保存完整元数据；见master-reference-20261012.json。用户再次否定Home Art A，已归档rejected-home-art-a，未发布为认可画面。当前按MASTER_REFERENCE_ALIGNMENT.md重建转角房间、斜角机位和物件比例；MasterLayout/倒角/管线为真实几何增量。尚未达到高保真，待原生对照与交互复验。GitHub远端仍为6d4829df6d3af0b6c2f2d114dd7b32da9d6ab997，未推送本次美术重做。


## 2026-10-12T06:11:50.147469+00:00 主参考已核验／本次状态回报

新主参考 image(2).png 的1672×941 RGBA SHA256与父会话完全匹配，已实际查看；获取参考不再阻塞。当前实施门框锚点相机拟合、右侧转角桌架、炉船网空间重排、倒角木作与管线细节。新布局离线检查结果见 master-layout-offline.log；原生已构建537网格/20694顶点，但预览提前停止原因待查，当前没有同机位新画面可供审美判断，也未推送新美术。旧版及Home Art A维持用户否定状态。持久断点见 docs/evidence/3d-lab-r3/HANDOFF_MASTER_REFERENCE_20261012.json。


## 2026-10-12T06:17:05.611079+00:00 退出诊断完成

无法证明本次是应用错误或自动结束；用户关闭不能排除。保留停止状态，需明确许可后才能重启。 已核对本次日志、CLI退出判定源码、QA配置和退出路径、Lab dump目录、限定时段Windows应用事件及既有PID。具体报告：docs/evidence/3d-lab-r3/preview-exit-diagnosis/REPORT.md；哈希与依据：findings.json。本轮没有重启、修改应用代码或推送。


## 2026-10-12T07:01:22.623419+00:00 主页真实帧与本地细节迭代

真实Home帧已查看并上传：libfile_f8cfaf966d988191b47d922270f90a79。该帧是537网格旧材质。其后细节版1036网格、21张1024贴图已落盘，67个Lua/70项离线检查通过，原生验证尚未完成。执行连接中断后进程消失且记录停在running，未保存退出码；未擅自重启，已询问再次启动许可。未提交或推送新美术。详见MASTER_HOME_PROGRESS_20261012.md与HANDOFF_MASTER_HOME_20261012.json。


LSP补充：将诊断服务的日志和资源路径显式限定到Lab后，67个文件均收到诊断，0 Error、112 Warning。警告包含原有业务源的类型推断项与少量新模块的空值/断言提示，未当作零警告通过。证据：docs/evidence/3d-lab-r3/lsp/diagnostics.json。


## 2026-10-13T12:44:51.309352+00:00 v035 black-screen / exit checkpoint
See docs/D3-v035-black-screen-exit-report.md. Start assertion was bypassed with diagnostic retained; native projection still FAIL, pixel output unverified. Authorized restart PID 41116 exited during resource loading; no exit code/stack or matching Windows crash event recovered. Executor connection recovery failure is not a proven crash cause. User prohibits further restart. A later unowned Lab session PID 3332 was observed and not operated. Business QA remains paused. Offline 102 checks / 99 Lua compile pass; no native acceptance.


## 2026-10-13T13:11:43.237776+00:00 full-scene loader preparation checkpoint
FullSceneHost, ScenePackage, CameraCalibration, LoadStatus and FrameStats added; ProbeAdapter generalized, MeshContract retains explicit normal-map degradation and semantic visible IDs; MeshLoader adds cooperative and streaming jobs; Integration accepts already loaded geometry. Complete package not yet local: only old probe ZIP exists. Native entry/generated files unchanged, no preview or business commands. 126 offline checks PASS, 105 Lua files compiled, 80 pinned source hashes intact; real delivered probe schema compatibility PASS. End-to-end synthetic 9-file package/hash/coverage validation PASS, not a full-scene acceptance. Native basis/ray diagnostics unrun; 26 normalTexture PNGs explicitly unbound. Known PIDs 41116 and 3332 no longer running at read-only check; exit cause still unknown. Active format/limits: docs/v035-full-scene-contract.md.


## 2026-10-13T13:41:04.308403+00:00 immediate full-package receipt checkpoint
7/7 actual ZIP sizes and SHA256 match (120392531 total bytes). Safely extracted 170 unique files into experiments/3d-lab/assets/import-v035-full; 169/169 internal hashes and CRC pass. Viewed actual full_json_reconstruction.png, explicitly cloud reconstruction not native evidence. First full offline validation failed in mesh 3, full_group_002_000 (letter cursive ink): absolute 1e-20 cross-squared threshold rejects nonzero faces; this mesh has zero exact-zero faces, minimum positive 3.2499997871426556e-26. No geometry removed and no threshold change applied yet. Evidence: full-package-integrity.json, full-package-first-validation-failure.json, tiny-triangle-diagnosis.json. Current separate regression suite PASS 135 checks, 107 compiled Lua files. Native remains paused. Parent requested immediate stage result; resume same task for the specific validator repair and full import.
# 2026-10-13 v035 immediate offline checkpoint (native paused)

Task 01a12c24-a725-712b-ba7d-df58430f5098. Connection briefly disconnected and recovered; current offline work is not blocked. MeshContract tiny-triangle repair is written: accepts finite nonzero cross products, rejects exact degeneracy and nonfinite cross products without deleting faces. First actual full run PASS: 90 meshes, 3,209,455 triangles, 2,584,246 source vertices, 10,790 source objects, 862 emitted batches (native backend substitute), 84.73 seconds. Normal-material binding is now implemented for 26 materials using PBRDiffNormal[Alpha], linear TU_NORMAL and GenerateTangents before Commit. Regression suite passes including actual tiny source triangle, nonfinite/collinear counterexamples, normal texture units, missing/failing tangent rollback. Resource audit PASS: all 53 used PNGs decoded; actual cached techniques checked; constant-white utility fallback verified for material 055. Geometry payload including tangents 344,638,176 bytes; RGBA8 textures without mips 314,572,288 bytes, excluding CPU/GPU copies/overhead/shadows/Lua peak.

Second full stream verification with normal metadata and retained ship geometry was started via tools/verify_full_v035.py; check full-package-check.json and full-package-check.log for its latest completion. No native launch/refresh/restart. FullSceneHost is not yet staged; current generated runtime entry remains the historical probe. Native camera, tangent availability/TBN appearance, performance, pixels and full 8-entry input remain unverified. Next: inspect second verification, guarded full runtime staging, then readiness report for one separately authorized controlled native run. Export still supplies Home only; Brew/Seaside routes are not accepted.



## Paused at user visual-mapping checkpoint
Second full verifier session 45343 exited 0: all 90 meshes, 3,209,455 triangles, 10,790 source objects, eight semantic entries, one complete ship mesh retained, 862 emission batches; 122.64 seconds. tools/stage_v035_full.py completed successfully: 250 recorded files (including retained probe files), 150 full runtime resources. scripts/main.lua now points to v035.lab35.FullSceneHost.Install with resourcePrefix=v035-full, flipV=false, 300-second loading deadline. This is offline staging, not native import acceptance. Probe entry and stage manifest backed up as probe-main-before-full.lua and native-stage-before-full.json. No native start/refresh/restart.
Parent/user now requests a pause before further work, pending visual ownership confirmation. Green book -> journal and tied paper stack -> case file remain tentative. No new hookup, post-stage checks or controlled-run tooling performed after the pause. Next after confirmation: verify staged namespace/Lua/resource paths and complete controlled-run logging/exit-code plan; native remains separately gated.


## 2026-10-13 full entry offline ready after mapping confirmation
User confirmed all eight visual/business mappings, including green book -> 故事记录 and tied paper stack -> 案件板. Ids.lua now reads target/label directly from pinned LayoutManifest; actual rendered hint text is tested for all eight entries. Regression PASS 152 checks / 107 canonical Lua compile / 80 pinned source hashes unchanged. Full second import PASS remains 90 meshes / 3,209,455 triangles / 10,790 source objects / eight entries / complete ship card retained. Guarded re-staging and full-staged-check PASS: 250 recorded files, 150 runtime resources (316,959,873 bytes), 85 generated Lua compile, actual main Install registration without Start, source mesh hashes and complete ship payload intact. Entry scripts/main.lua -> v035.lab35.FullSceneHost.Install.
No native launch, official full-package prepare, API/GPU execution or system input. Home is the only exported camera; Brew/Seaside routes remain missing. Native camera calibration, GenerateTangents availability/TBN, working set, pixels and performance require controlled verification. Resource estimate: vertex payload including tangents 328.67 MiB plus RGBA8 textures without mips 300 MiB, excluding other memory. Report and exact single-run evidence plan: docs/D3-v035-full-entry-ready-report.md. No unresolved mapping decision; wait for main-thread native authorization, do not restart automatically.

Ready report uploaded successfully: Library libfile_871512b779a48191b085b12da3a30355 version 0, filename D3-v035-full-entry-ready-report.md. Local identity metadata helper remains unsupported on Windows; receipt saved as full-ready-library-receipt.json. No native launch.


## 2026-10-13 controlled full attempt: no Runtime launched
Standalone official prepare passed after approved retry for spawn EPERM; generated manifest contains all 90 meshes/150 runtime resources. Existing-page navigation fallback implemented and 157 regression checks pass; generated entry includes bounded native UI callback observation, not OS input. Official preview run CLI PID 49424, session bf5e180e-ea53-4ae3-b81b-6ea9fa74e4c4 exited 1 at 14:26:54 UTC during its own repeated prepare: public source index download failed. Official result explicitly says no Runtime was started. No native PID, native exit code, screenshot, load count or memory measurement exists. Observer exec session 41908 has completed; no long command remains. Evidence: docs/evidence/v035-main-interface/native-full-20261013-01/{checkpoint.json,cli-stdout.log,observer-final.json,run-prepare-failure.log}. Stop here for parent timed report; do not label as runtime crash or complete scene acceptance. Next same-task continuation diagnoses exact official prepare log and repairs recoverable preparation; also verify optional NativeObservation panel GetProps API before a real launch. No formal project operation or OS input.
