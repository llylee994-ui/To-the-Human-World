# Blender v03.5 场景接入 GitHub main 真实接口

## Status and situation

Blocked on actual asset delivery/native permission; independent step completed — 2026-10-13。唯一任务 `01a12c24-a725-712b-ba7d-df58430f5098`。

用户要求以 GitHub `llylee994-ui/To-the-Human-World` 的 main 最新契约为准，将真实业务接到云端 Blender v03.5 混合图景。旧程序模型不是本次场景。完整工程 Library `libfile_f0f734c339f8819184fc10b1aa8f376c`；轻量补充包 `libfile_0bdebeedaef08191a5a2c536a0fe0713` 依赖 v03.4，不代替完整工程。

正式2D只读，当前 `fengyycon` / `54eff6e2b4716031f1944465fe287f053cb34f0e`，存在用户未提交改动。Lab独立Git检出仍在 `experiment/3d-lab` / `6d4829df6d3af0b6c2f2d114dd7b32da9d6ab997`，检出内无已跟踪改动；Lab根目录保留此前尚未提交的美术代码。此次允许Lab获取main代码数据，不push、不合并、不改正式分支。

保留捞网打开现有捞漂流瓶界面、返回主页、日期、金币、结束当天；提示按钮显示物件旁气泡。二维动效逐项审查，不以删除表现为由删除业务。单套GameSession/PlayModel、独立内存存储。尚无新的原生启动许可，不启动或恢复预览。不得系统输入、子代理、额外任务或联系其他用户窗口。

## Implementation measures

1. 查询main最新SHA并在Lab独立检出获取固定版本，核对顶部契约与现行实现。
2. 官方Library材料化完整v03.5包，确认本机文件并检查内容；依据本地引擎文档确认导入格式，不把下载成功当加载成功。
3. 保存真实接口与二维表现保留/替换清单，尽早回报main契约、资产路线与阻塞。
4. 独立适配场景稳定ID、点击分发、既有捞取页面、HUD与提示气泡；保留旧有效成果。
5. 离线/程序化验证真实状态、重复输入、返回和存档隔离；原生检查等待明确运行许可。

## Affected file tree

- `docs/actions/2026-10-13-v035-main-interface.md`：本次唯一行动记录。
- `docs/evidence/v035-main-interface/`：固定来源、接口检查、材料化和离线验证证据。
- `imports/v035/`：Library原包及安全提取文件，不覆盖旧场景。
- `imports/main-<sha>/`：main中所需业务/页面源码快照，记录哈希。
- `scripts/lab/`：后续适配位置；具体变更在确认接口和资产后补充。
- `deliverables/github-checkout/.git/`：只获取main对象和引用；不切换或推送实验分支。

## Self-verification method

只读Git核对固定SHA与代码；官方材料化结果逐项核验存在、可读、大小和哈希；实际查看所需图片。业务验证使用独立内存GameSession，不使用正式进度。测试点击路由、模态阻挡、一次性事务、捞取成功/失败/重复点击、日期金币绑定、结束当天和返回。原生/人工/手机结果分开，不继承旧美术验收。

## Self-verification results

Pending。已确认正式目录可读，Lab独立检出与此前记录存在；尚未确认远端main、v03.5包和引擎导入能力。


## 2026-10-13T10:42:01.980053+00:00 actual checkpoint

- PASS: GitHub main fetched into the existing Lab clone without checkout, merge or push; SHA `1cd0cdbec06487a5c60f109d5fd477198cfc8846`. Current schema 3 top contract and runtime code inspected. Eight Home IDs match LayoutManifest. Source snapshots with SHA256: `docs/evidence/v035-main-interface/main-source-manifest.json`.
- PASS: GameSession.New accepts options.saveSystem; SaveSystem.New(storage) supports isolated memory injection. Existing AppView uses one Model.New and keeps salvage receipt before presentation animation. Ledger binds live currency/day; End Day opens a confirmation panel before NextDay.
- FAILED: full v03.5 official Library materialization. Initial download failure, one retry reached metadata and failed because Windows os.setxattr is unavailable. Destination ZIP absent; no unofficial workaround or additional retry. See materialize-retry.log.
- NOT VERIFIED: actual cloud scene pixels/geometry, import, new scene interaction binding, native performance and mobile. No new native preview or system input.
- DELIVERABLE: `docs/v035-export-contract.md` gives supported API route and exact sample mesh/texture/camera/anchor interchange. Blender/GLB/FBX importer not found in local docs/tools; CustomGeometry is documented but this asset import has not yet been tested.
- NEXT: cloud prepares a small merged evaluated mesh sample; resolve supported Windows materialization; implement and test importer plus main-backed adapter in Lab, keeping old scene as history. Native requires explicit renewed permission.


## Independent implementation continuation (authorized 2026-10-13)

Parent requested continued asset-independent work. No new Library retry or native preview. Add isolated `v035/scripts/lab35/` modules: strict mesh contract validation/conversion, native CustomGeometry/material backend, semantic pick proxies and projected hints, eight-ID controller, isolated bootstrap and HUD binding. Snapshot pinned main business/UI modules into `v035/scripts/` with hashes, without changing formal or old Lab scripts. Preserve original SeasideView and SalvageController; adapt a separate AppView copy to accept one injected model and a 3D Home facade. Synthetic mesh tests and real main business offline checks must explicitly distinguish API mocks from native rendering.

Verification will cover invalid mesh input before engine mutation, handedness/index/UV conversion, semantic ship proxy rather than full alpha card, UI/modal/navigation gates, repeated presses, return paths, End Day confirmation, currency/day state binding, hint visibility and memory-only storage. Asset-dependent visual acceptance remains blocked.


## 2026-10-13T11:07:16.401014+00:00 independent step delivered

Actual tree: `v035/scripts/lab35/` (loader, native backend, semantic picker, controller, bootstrap/memory, Home/AppView/Panel adaptations and tests); `v035/scripts/{core,systems,data,ui,debug}` (80 unchanged pinned main Lua files); `v035/assets/image/` (5 pinned Seaside resources); `tools/check_v035.py`; `docs/v035-interface-map.md`; `docs/D3-v035-independent-step-report.md`; evidence/HANDOFF. Old Lab entry and formal sources untouched.

Verification: `python -X utf8 tools/check_v035.py` PASS 102 checks, 97 Lua compile, all 80 main hashes intact. Initial test-runner Python parenthesis typo was repaired before execution; no game defect inferred from it. Native call tests use explicit substitutes, not a running renderer. Real snapshot/memory auditing confirms navigation/panels do not receive, spend or reward. Library retry deliberately not attempted; latest expected probe absent=True.

Status: independent implementation complete; actual sample schema normalization, real scene data/texture import, native host/camera routes/occlusion and preview remain blocked/pending. No native start, install, system input, commit or push. Next: follow HANDOFF_V035_INDEPENDENT.json in the same task.

Report uploaded successfully to Library: `libfile_8123103b7d208191bf42f973fcc75efa`, version 0. Current official metadata helper failed to persist local xattrs on Windows; complete receipt saved separately, no helper changes/retry.


## 2026-10-13T11:38:43.028443+00:00 preview authorization received; probe absent

User explicitly permitted this isolated Lab preview ("允许！"). Checked exact Lab-root `D3-v035-CustomGeometry-import-probe.zip`: absent. Authorization recorded but unused. No native preview or old scene started; no Library retry. Next blocker is local delivery, not permission. Previous 102 offline checks remain historical results, not rerun this check.


## Actual cloud probe integration started

User confirmed local delivery and preview permission is already granted. ZIP exact size/SHA256 match; 22 archive members and CRC pass; destination absent. Extract into the expressly requested Lab experiments path, preserve source package, verify internal hashes, view actual PNGs/schema before visual changes. Add explicit ProbeAdapter for actual dot-customgeometry-probe-v1, native host/entry and evidence capture. Main modules and formal workspace remain unchanged. Native start uses official Maker CLI for Lab only; automatic refresh only while verified live, never restart an exited preview. Verification pending for this actual-asset step.


## 2026-10-13T12:14:11.849347+00:00 immediate parent checkpoint

ZIP found and exact size/hash pass; extracted safely; all 21 internal hashes pass. Viewed original sea/ship PNGs, Blender probe/checker renders and UV checker. Actual source uses dot-customgeometry-probe-v1; ProbeAdapter converts it and excludes invisible proxy meshes from rendering. Actual Lua adapter/validator offline read: 6 visible meshes, 8128 triangles, 8 anchors. NativeHost added with explicit probe-only lighting/navigation defaults, memory business QA and screenshot hooks but NOT staged/compiled/run yet. NativeGeometry supports the actual unlit cards; AppView Brew sidebar changed. Old Lab main remains unchanged; no game started, no native result claimed. Next compile/retest and stage resources, then use current preview permission.

## Authorized restart after black-screen diagnosis
Initial Start failed at NativeHost camera calibration assertion before viewport/UI/Update registration. First repair explicitly set aspect and kept calibration mismatch as a diagnostic instead of aborting; initialized the actual UI root. Refresh 1 then registered Start/Update, loaded 6 meshes / 8128 triangles, and native ship/stove semantic ray checks passed. Camera anchor calibration still FAIL (squared error 1.607814), so this is NOT full projection acceptance. All automatic business QA remains disabled. Native SavePNG absolute path was refused; use existing read-only owned-window PrintWindow capture instead, without altering engine permissions.
Previous preview is confirmed stopped by official status; no live process to close. User explicitly ordered one new restart: Sentinel_dcdff45c7ea48191b6780edd884dc7d8, quote “重启3D版本”. Consume this permission for one official Lab-only run, not unlimited restarts. Preserve old logs. Formal project unchanged.


## 2026-10-13T12:44:51.309352+00:00 v035 black-screen / exit checkpoint
See docs/D3-v035-black-screen-exit-report.md. Start assertion was bypassed with diagnostic retained; native projection still FAIL, pixel output unverified. Authorized restart PID 41116 exited during resource loading; no exit code/stack or matching Windows crash event recovered. Executor connection recovery failure is not a proven crash cause. User prohibits further restart. A later unowned Lab session PID 3332 was observed and not operated. Business QA remains paused. Offline 102 checks / 99 Lua compile pass; no native acceptance.


## Full-scene import continuation (Sentinel_ceee7525a5e4819191110ae147bc81a7)
Status: In progress, native preview explicitly paused. User now requests conversion/import of the complete existing scene. Cloud full package is being exported; not yet delivered locally. Applicable formal AGENTS hash remains unchanged. No process operation, install, binding, push or system input.
Measures: generalize actual cloud schema beyond six meshes; retain independent eight semantic proxies and source-to-visible-mesh mapping; add cooperative validation/loading with progress/failure/cancel cleanup; prepare a separate full-scene host that shows loading/error UI before file parsing, creates one memory session only after load, and reports runtime counts/timings. Preserve probe code/results as historical evidence and do not replace the currently staged runtime entry while native ownership is unresolved.
Affected tree: v035/scripts/lab35/{ProbeAdapter,MeshContract,MeshLoader,Integration}.lua (generalized adapters/loading seams); new LoadStatus.lua and FullSceneHost.lua (visible status and native composition); tests/FullImport.lua; tools/check_v035.py (offline checks); docs/v035-export-contract.md and evidence/HANDOFF (contract and truthful limits). No formal files or generated runtime files in this step.
Verification: existing 102 checks and pinned-source hash checks; synthetic multi-mesh cooperative-load progress/failure/cancel tests; actual probe compatibility; syntax checks. Full-package schema/count/hash validation once the exact package arrives. Native pixels, performance and input remain unverified while launch is paused.
Self-verification results: Pending.


## 2026-10-13T13:11:43.237776+00:00 full-scene loader preparation checkpoint
FullSceneHost, ScenePackage, CameraCalibration, LoadStatus and FrameStats added; ProbeAdapter generalized, MeshContract retains explicit normal-map degradation and semantic visible IDs; MeshLoader adds cooperative and streaming jobs; Integration accepts already loaded geometry. Complete package not yet local: only old probe ZIP exists. Native entry/generated files unchanged, no preview or business commands. 126 offline checks PASS, 105 Lua files compiled, 80 pinned source hashes intact; real delivered probe schema compatibility PASS. End-to-end synthetic 9-file package/hash/coverage validation PASS, not a full-scene acceptance. Native basis/ray diagnostics unrun; 26 normalTexture PNGs explicitly unbound. Known PIDs 41116 and 3332 no longer running at read-only check; exit cause still unknown. Active format/limits: docs/v035-full-scene-contract.md.

Preparation status: Completed; actual full import: Blocked awaiting exact package delivery, native validation: explicitly paused. Added tools/verify_full_v035.py (actual-package SHA256/PNG/stream/count verifier) and tests/FullImport.lua (stream lifecycle and failure coverage). Actual verification: python -X utf8 tools/check_v035.py => PASS 126 checks / 105 syntax files / 80 pinned sources intact. python -X utf8 tools/verify_full_v035.py --root docs/evidence/v035-main-interface/synthetic-full-package --expected-triangles 9 --expected-source-objects 9 --synthetic => PASS. This synthetic package is not scene artwork. Generated runtime manifest hashes all remain unchanged. Full contract uploaded to Library libfile_2ce51c6065b48191a892d35f0ed2fc6f version 0; official Windows xattr helper still fails os.setxattr, upload itself succeeded and receipt is saved. No full asset render or native test performed.


## Offline camera/material/failure follow-up
Status: in progress; complete ZIPs still being delivered; no native launch. Investigate right-handed camera basis using actual UrhoX bindings and previous native error evidence; preserve calibration failure until an actual native round-trip passes. Check local materials skill, cached engine-res 1.32.12 techniques/shader and GenerateTangents binding for possible normal-map support. Strengthen import cleanup and bounded resource reading; add regression checks at the real loader and resource-read seams. Planned files: MeshLoader.lua, FullSceneHost.lua, CameraCalibration.lua, new CameraMath.lua/ResourceReader.lua if justified, tests, evidence and contract notes. Verification initially pending.


## 2026-10-13T13:41:04.308403+00:00 immediate full-package receipt checkpoint
7/7 actual ZIP sizes and SHA256 match (120392531 total bytes). Safely extracted 170 unique files into experiments/3d-lab/assets/import-v035-full; 169/169 internal hashes and CRC pass. Viewed actual full_json_reconstruction.png, explicitly cloud reconstruction not native evidence. First full offline validation failed in mesh 3, full_group_002_000 (letter cursive ink): absolute 1e-20 cross-squared threshold rejects nonzero faces; this mesh has zero exact-zero faces, minimum positive 3.2499997871426556e-26. No geometry removed and no threshold change applied yet. Evidence: full-package-integrity.json, full-package-first-validation-failure.json, tiny-triangle-diagnosis.json. Current separate regression suite PASS 135 checks, 107 compiled Lua files. Native remains paused. Parent requested immediate stage result; resume same task for the specific validator repair and full import.

## Full geometry and normal-material offline completion
Status: In progress. Fix the demonstrated tiny, nonzero triangle rejection without removing faces or relaxing finite/index/degeneracy validation. Add the actual failing letter-ink triangle plus exact-zero and overflow counterexamples. Run all 90 actual meshes / 8 semantic entries through the streaming importer. Bind the 26 declared normal maps using verified PBRDiffNormal/PBRDiffNormalAlpha, TU_NORMAL and GenerateTangents before Commit; keep native capability, camera basis and visual TBN acceptance explicitly unverified. Supply a verified white diffuse resource for the one normal-only constant-color material. Stage a guarded full-scene entry and resources offline after validation; preserve the old probe and original entry. No native launch/refresh/restart, binding changes, formal writes or new agents. Validation and handoff results: pending.

Immediate parent-requested checkpoint: repair and normal binding are written. Regression suite PASS; first real full import PASS all 90 meshes / 3,209,455 triangles / 10,790 source names / 862 draw batches in 84.73 seconds. Second full import with new normal metadata and retained ship geometry is running or has just finished; latest result is full-package-check.json/log. Resource audit PASS 53 decoded PNGs, 26 normal materials, verified cached technique resources. Engine cached default-white PNG is actually KTX-compressed, so it was not copied or falsely claimed pixel-verified; a literal RGBA(255,255,255,255) 1x1 utility PNG was generated and decoded under v035/assets/engine-support with hash recorded. Tangent unavailable/false return now triggers visible load failure and cleanup; no silent fallback. Red regression revealed an additional prior bug: infinite cross product had been accepted; repaired and covered. Current generated entry remains probe; full staging pending. No native operation. Transient executor transport disconnect recovered, not a game crash or current blocker.

## Full-scene offline staging continuation
Second verifier session 45343 completed with exit code 0: PASS 90 meshes / 3,209,455 triangles / 10,790 source objects / 8 semantic entries, exactly one complete ship mesh retained for alpha-aware picking, 862 native emission batches, 122.64 seconds. Parent explicitly requests full offline staging and a controlled-run evidence plan; native start remains prohibited. Planned changes: new tools/stage_v035_full.py and offline staged-entry verifier, generated scripts/v035 and assets/v035-full, guarded scripts/main.lua switch to FullSceneHost, status/contract/handoff report. Verify all existing generated file hashes before writing, preserve probe entry/manifest, preserve original source inputs, compile staged Lua and inspect namespaced require resolution, all 90 staged mesh hashes and complete ship payload. No appearance changes or new external software. Self-check results pending.


## Paused at user visual-mapping checkpoint
Second full verifier session 45343 exited 0: all 90 meshes, 3,209,455 triangles, 10,790 source objects, eight semantic entries, one complete ship mesh retained, 862 emission batches; 122.64 seconds. tools/stage_v035_full.py completed successfully: 250 recorded files (including retained probe files), 150 full runtime resources. scripts/main.lua now points to v035.lab35.FullSceneHost.Install with resourcePrefix=v035-full, flipV=false, 300-second loading deadline. This is offline staging, not native import acceptance. Probe entry and stage manifest backed up as probe-main-before-full.lua and native-stage-before-full.json. No native start/refresh/restart.
Parent/user now requests a pause before further work, pending visual ownership confirmation. Green book -> journal and tied paper stack -> case file remain tentative. No new hookup, post-stage checks or controlled-run tooling performed after the pause. Next after confirmation: verify staged namespace/Lua/resource paths and complete controlled-run logging/exit-code plan; native remains separately gated.

## Resume after confirmed eight mappings
User confirmed all eight mappings and authorized continuation. Green book opens 故事记录 (including trial/recipe history); tied paper stack opens 案件板; letter paper reads existing letters. Native start is still paused. Current full verifier has terminal exit 0 and offline staging already completed; do not rerun the 90-mesh job without a new geometry concern. Change Ids.lua to derive targets/labels from the pinned LayoutManifest, so native hints preserve exact main wording (including 炼药工作区). Re-stage with overwrite guards, validate generated Lua namespaces, full resource hashes/ship ownership, and existing real business regression checks. Final deliverable: exact entry, readiness/limits, resource estimate and one controlled-run log/exit-code collection plan. No extra visual design work.

## Authorization: one controlled full-scene native run
Parent explicitly lifted native pause for ONE controlled complete-scene validation. First perform official managed prepare; recoverable prepare failures may be repaired and rechecked without bypassing official flow. Preserve existing 2D Seaside/Brew pages even when exported 3D camera poses are absent. Fix the adapter's missing-camera rejection before this run: open existing pages with Home camera retained, and report this as a UI route rather than a completed 3D camera route. Add real navigation seam coverage, restage, then official prepare and one owned foreground preview run. Capture exact preview.started session/PID, raw CLI streams, bounded process metrics/exit handle and owned-window pixels where available. Never touch formal PID 52756 or use OS input. On crash preserve evidence and stop; no continuous restart. All preparation, monitoring and output stay under Lab. Results pending.


## 2026-10-13 full entry offline ready after mapping confirmation
User confirmed all eight visual/business mappings, including green book -> 故事记录 and tied paper stack -> 案件板. Ids.lua now reads target/label directly from pinned LayoutManifest; actual rendered hint text is tested for all eight entries. Regression PASS 152 checks / 107 canonical Lua compile / 80 pinned source hashes unchanged. Full second import PASS remains 90 meshes / 3,209,455 triangles / 10,790 source objects / eight entries / complete ship card retained. Guarded re-staging and full-staged-check PASS: 250 recorded files, 150 runtime resources (316,959,873 bytes), 85 generated Lua compile, actual main Install registration without Start, source mesh hashes and complete ship payload intact. Entry scripts/main.lua -> v035.lab35.FullSceneHost.Install.
No native launch, official full-package prepare, API/GPU execution or system input. Home is the only exported camera; Brew/Seaside routes remain missing. Native camera calibration, GenerateTangents availability/TBN, working set, pixels and performance require controlled verification. Resource estimate: vertex payload including tangents 328.67 MiB plus RGBA8 textures without mips 300 MiB, excluding other memory. Report and exact single-run evidence plan: docs/D3-v035-full-entry-ready-report.md. No unresolved mapping decision; wait for main-thread native authorization, do not restart automatically.


## 2026-10-13 controlled full attempt: no Runtime launched
Standalone official prepare passed after approved retry for spawn EPERM; generated manifest contains all 90 meshes/150 runtime resources. Existing-page navigation fallback implemented and 157 regression checks pass; generated entry includes bounded native UI callback observation, not OS input. Official preview run CLI PID 49424, session bf5e180e-ea53-4ae3-b81b-6ea9fa74e4c4 exited 1 at 14:26:54 UTC during its own repeated prepare: public source index download failed. Official result explicitly says no Runtime was started. No native PID, native exit code, screenshot, load count or memory measurement exists. Observer exec session 41908 has completed; no long command remains. Evidence: docs/evidence/v035-main-interface/native-full-20261013-01/{checkpoint.json,cli-stdout.log,observer-final.json,run-prepare-failure.log}. Stop here for parent timed report; do not label as runtime crash or complete scene acceptance. Next same-task continuation diagnoses exact official prepare log and repairs recoverable preparation; also verify optional NativeObservation panel GetProps API before a real launch. No formal project operation or OS input.


Continued explicit launch request: attempt 01 never created Runtime; current official log shows engine-res import failed while engine and official-res succeeded. Standalone official prepare had succeeded. Retry official preparation without bypass. Fixed optional native callback to Panel.props (GetProps is not the Panel API), and observer now requires unique attempt label/one-run marker. Transient executor disconnect recovered via read-only Get-Location; separate from prepare failure. No actual Runtime crash occurred.

## 2026-10-13 接手完整场景原生验证

状态：进行中。用户本轮明确授权完整 prepare、诊断修复、单实例启动、程序事件及真实点击验证。此前逐次启动限制由本轮目标取代；仍禁止盲目重启、推送、改动正式 2D 和操作其他代理/无关进程。
事实：最新旧 session d6e445d6-92b0-4daa-9910-6623a43fd647 / PID 13764 已消失；官方 status 已确认 failed/process_alive=false。该轮 prepare 成功，日志停在公共包下载，退出码缺失，未到 FullSceneHost。无活动 Lab prepare/observer；其他项目 PID 52756 保持不动。
措施：1) 校验当前生成入口/固定业务/完整资源并运行官方 prepare；2) 修复观察器句柄同步权限并独立持久化运行，捕获精确 PID/退出码/内存/日志；3) 依据实际错误修复相机、切线或加载，保持全量几何和原页面；4) 实际截图及八入口、提示、返回、重开检查，事件与 OS 点击分开；5) 更新当前报告和启动方法。
影响文件树：tools/observe_full_v035.py（官方启动及进程证据）；v035/scripts/lab35/（仅实际发现错误的适配层）；scripts/v035 与 scripts/main.lua（受保护生成）；docs/evidence/v035-main-interface/native-full-20261013-*（本轮证据）；LAB_STATUS.md、RUNBOOK.md、本行动记录及最终报告。固定 main 80 模块和原始完整资源不修改。
自验方法：check_v035.py、verify_v035_staged.py、官方 prepare manifest 检查、独立 Runtime 记录、按 PID 截图及点击、运行日志检查。实际失败才安排针对性修复与下一次运行。
自验结果：Pending。旧 Runtime 退出原因未证实，不把执行通道断开等同于游戏崩溃。

### 本轮原生证据增量
- attempt 03：官方 prepare 完整资源在，PID 51764 已完成引擎资源加载，Start 在 GetTime():GetTimeSinceEpochMs() 因原生绑定参数错误退出初始化。实际黑屏已保存 full-03-start-error。修复为本机 UI 已使用的 time:GetElapsedTime()*1000；未修改固定 main。不存在可忠实复现该 C++ 绑定错误的离线替身，回归以再次原生执行同一完整入口为准。
- 官方主动 stop 后捕获 Runtime=1、CLI=1；这是本轮结束故障会话的退出码，不是自发崩溃结论。峰值工作集 880041984 B、采样私有内存峰值 1136025600 B。
- attempt 04：官方 prepare 后单实例 PID 46088，22:49:14（UTC+8）已实际进入完整分批加载，计时修复原生通过；尚待全量、相机、画面和交互结果。
- 工具变化：start_full_v035.ps1 只允许未占用 Lab 和未用过的编号；click_lab_window.ps1 验证游戏可执行文件、HWND 所属和前台窗口后发真实鼠标事件；capture_lab_window.ps1 允许启动期标题，但仍严格限制 PID 与 Lab 可执行文件。

### 全量首次载入及投影修复
- attempt 04：90 网格、3,209,455 三角面、10,790 源物件、862 批次全部原生建立；耗时 203.536 秒；法线材质的 GenerateTangents 已随完整加载实际执行且未失败。存档写入 0。
- CAMERA：RH/lookSign=-1 的八条原生射线与源锚点方向全部匹配，rayError=3.177e-14、rightDot 约 1，但 WorldToScreenPoint 错误夹到 0/1。LH 屏幕水平镜像。真实画面整屋已显示；纵向纹理颠倒且校准警告阻挡交互，未宣称通过。
- 修复 NativeGeometry.ScreenUV：用真实 camera.view/projection 计算有符号齐次 W，并保留近远裁切；CameraCalibration 同时记录旧 API 值，继续八点/八射线校验。NativeCalls 中复制 RH 夹边错误先红后绿（rh-projection-red/green.log）。仅 Full 入口 flipV=true，原始资产字节未改。
- 本轮新增/变更：NativeGeometry.lua、CameraCalibration.lua、tests/NativeCalls.lua、stage_v035_full.py；对应受保护生成副本。attempt 05 验证这两项修复。关闭 attempt 04 是针对性修复后的受控替换，不是自动崩溃。

### 案件绑绳、真实鼠标与会话边界
- attempt 05：相机矩阵换算原生通过，pointError=1.4067e-13、rayError=3.1770e-14；全量载入 196.457 秒；实际窗景已正向。7/8 程序入口成功，案件中心点受绑绳遮挡。八入口遍历前后内存写次数与业务快照均不变。
- 真实 OS 鼠标已验证：drawer、journal、words、net 打开正确原页面，前三者关闭成功；海边进入后仍显示“开始捕捞·剩余 1 次”。截图位于 native/os05-*。其余真实鼠标项目待补。
- 取证工具修复 DPI：Windows 125% 导致旧截图仅 1058×625，现以线程 DPI 上下文取得完整 1322×781 窗口；未改变系统缩放或游戏尺寸。full-05-dpi-correct 为完整全屋实际画面。
- 精确源射线回放查得 case 前方 0.0271 米为 full_group_017_000（含 Parcel crossing string / Parcel bow loop），后面紧接 case 纸堆。SemanticOcclusion.lua 只在纸堆实测 bounds+0.035m 内识别此共享网格命中，不豁免共享网格其他区域；三个回归通过。源资产未改。
- attempt 05 于 15:07:14 UTC 达到官方 600 秒运行上限后结束，Runtime/CLI 均为 1；不是自发崩溃。峰值工作集 1766084608 B、采样私有内存峰值 2775257088 B。
- 下一轮验证案件修复并补余下真实点击，使用官方 preview start --legacy-wmi 的独立现有 Runtime 持久会话（保持 Lab 路径，不用全局运行库、不接管正式控制台），直到用户关闭。观察器新增 persistent 模式，仍按精确 PID 留存指标与退出码，无重启逻辑。


### 完整运行完成、交人工测试
- attempt 06：PID 56268，session 46ffe50f-e458-49ab-8cff-855a9dcac2c0；全部 90 网格/862 批次原生载入，114.005 秒，相机八点/八射线通过；8/8 程序 UI callback + native picker 通过，遍历前后业务状态和内存写次数不变。完整房间、正向窗景、全部名称气泡已实际看图。
- 回归 161 PASS / 110 Lua compile，150 资源及固定 main 80 模块不变。持久官方 supervisor 运行，无自动重启；退出码尚未产生。峰值工作集 1786318848 B，采样私有峰值 2819645440 B（交人工前快照）。
- OS 验证新增案件及商店打开、案件关闭。发现最小化 PrintWindow 缓存及外部悬浮键盘遮挡导致假观察；相关失败/不确定点击不列通过。工具加 IsIconic、准确 DPI、实际光标和 WindowFromPoint 根窗口检查、临时抬高仅 Lab 自身窗口并恢复、前台窗口区域 CopyFromScreen。购买尝试在前台获取失败时中止，未发送输入。
- 用户最新明确接手人工测试，因此停止所有自动鼠标输入，保留当前游戏；不操控遮挡它的外部程序。其余真实业务与完整人工验收等待反馈。
- 文件：新增 SemanticOcclusion.lua、diagnose_case_ray.py、summarize_full_v035.py、Start-3D.ps1/cmd；更新 FullSceneHost/NativeGeometry/CameraCalibration/tests、stager、observer/start/capture/click 工具及对应受保护生成副本。LAB_STATUS、docs/RUNBOOK、实际运行报告已更新。当前普通生成入口关闭 observeEntries，不刷新或重启正在运行的已完成观察实例。


### 本地 3D 分支隔离
- 状态：进行中。用户明确要求当前 Lab 目录无损新建 3D 分支；人工测试继续暂停。当前独立仓库为 main，HEAD 8de6f76c212ceea69e8935b6406bdf7b1059bf9d，3d 分支不存在。
- 措施：在同一 HEAD 创建并切换到本地 3d；保留所有未提交/未跟踪内容，不提交、推送、stash、reset、清理或启动/关闭进程。
- 影响：Lab .git/HEAD、refs/heads/3d 及 Git 自身 reflog；本行动记录记录结果。现有游戏实现和资源不计划改变；正式 2D 只读。
- 自验方法：前后 HEAD、索引、工作区状态、当前代码与完整运行资源 SHA256 对比；只读核对正式 2D 分支和 HEAD。
- 自验结果：Pending。
- 自验结果：Completed。git switch -c 3d 成功；当前分支 3d，HEAD 不变，索引及工作区状态不变，429 个现有入口/实现/完整运行资源 SHA256 不变；正式 2D 分支 fengyycon 和 HEAD 不变。没有提交或推送，现有未跟踪文件仍在本地，创建分支不等于已提交保存。


### 本地 3d 分支首次完整提交
- 状态与范围：用户明确授权“本地提交”；当前 3d 分支基于空的 init commit，项目文件全部尚未跟踪。本次保存当前 Lab 的源码、原始解包资源、完整运行资源、启动/检查工具、SDK 源文件、文档及固定验证证据。测试继续暂停，不推送、不启动/停止游戏、不改正式 2D。
- 措施：添加精确忽略规则，保留本地运行库/缓存、机器绑定、临时下载、重复压缩归档和旧嵌套 Git 检出；保留字节级换行以免 Git autocrlf 破坏固定业务/资源 SHA256；明确路径暂存，审查内容与完整包后作本地提交。
- 影响文件树：新增 .gitignore（本地运行与临时文件边界）、.gitattributes（原始文件字节保护）；更新 LAB_STATUS.md、docs/RUNBOOK.md、docs/D3-v035-native-acceptance-report.md（人工测试暂停事实）、本行动记录。其余现有源码、资源、工具、文档只加入版本控制，不改变内容。
- 自验方法：分支/仓库核对；排除路径与嵌套仓库检查；暂存索引的完整资源、固定业务及工作区字节对比；敏感信息模式扫描（仅报告文件和行号）；git diff --cached --check；提交后核对 commit、分支和工作区。沿用已有运行结果，不重复游戏测试。
- 自验结果：Pending。
- 提交前自验结果：范围整理和预检 Completed。2219 项初始暂存文件，完整运行资源 150/150 SHA256、固定 main 80/80 模块 SHA256 通过；无嵌套仓库、无高置信凭据模式命中，暂存内容与工作区字节一致。新增 local-commit-preflight.json 保存本次检查快照。git diff --cached --check 返回 2：识别 CRLF 后剩 59 处既有空白格式提示，未为本次保存改写固定源码/引擎参考；没有冲突标记。现有运行验证结果沿用，人工/游戏测试未重跑。
- 实际影响：.gitignore、.gitattributes、3 份当前状态文档、本行动记录及本次预检 JSON；其余文件只首次纳入版本控制。执行本地 commit，提交标识及最终是否成功以本条记录所在 Git 提交和操作回执为准。推送没有授权，也不执行。
