# C-HOME-YAW-PROBE-20261012 r1

## 状态与现场

- Completed（隔离技术验证）；成果 C-HOME-YAW-PROBE-20261012-r1-v01。正式美术、OS 人工与手机验收不在已通过范围内。
- 实际基线 fengyycon@c59c59044218e6be626edb86f66dc950f6943bd2；不切分支、不合并、不提交、不推送、不远端构建、不改绑定。
- 用户要求固定站位向右转头：相机与物件位置、FOV、俯仰、侧倾固定，只改变 yaw。几何体测试不等于正式美术完成。
- 当前已有主页接入、热区小修与捞网推进保留；其他窗口的文档、素材、编辑器改动保留。
- 初始官方预览 session fd7f0f24-b9e4-42df-a1d6-4fcc27bba5a7 / reload 0 / PID 47000，process_alive=true。仅在后续状态仍存活时刷新；刷新会重启预览并丢失内存态。不得复活已停止会话，不操纵 OS 鼠标。
- 原环境错误：Cube/Day/DaySpecularHDR.dds 缺失、themis_x64.dll 加载失败；与本轮问题分别记录。
- 依据：用户任务、适用 AGENTS、完整 project-control-report / action-document、Lua 指南、scene-to-nanovg、camera、built-in-models、UI 相关完整章节、scaffold-3d-scene，以及 API 索引中的几何/相机与 UI 示例。

## 实施措施

1. 独立 Scene / 固定 Camera / Viewport / Texture2D 手动更新，通过 nvgCreateVideo 嵌入现有 UI；不采用跟随相机，不移动现有主页图片。
2. 内置模型组成前墙、右墙、桌面、右前方药炉和方向标记；简易材质，无新生成美术。
3. 显式开发开关默认 false；提供播放、复位、关闭；屏幕控件固定。打开/关闭不调用业务命令。
4. 正确管理纹理尺寸、nvgDeleteVideo、Viewport 解绑、Texture/Scene 释放与重开。
5. 可执行检查覆盖生命周期、唯一 yaw 变化、重复输入及正常入口隔离。存活预览中通过开发自动脚本调用同一按钮回调取连续原生证据，明确不等于 OS 人工点击。
6. 提供正式素材最低规格，区分几何链路已验证部分与贴图未验证部分，不立即制作。

## 影响文件树

- scripts/ui/landscape/HomeYawScene.lua：独立测试场景、透视相机与纹理资源生命周期。
- scripts/ui/landscape/HomeYawMotion.lua：只改变 yaw 的时间状态机；重复播放和中断复位。
- scripts/ui/landscape/HomeYawProbe.lua：验证窗口、播放复位关闭与参数时间记录。
- scripts/ui/landscape/AppView.lua：仅增加显式开发入口及更新/释放钩子；不替换任何物件业务入口。
- scripts/ui/landscape/DevChecks.lua：新增默认关闭的 yaw 验证/取证开关。
- scripts/ui/landscape/tests/HomeYawTest.lua、run_home_yaw.py：专项状态/入口/生命周期检查。
- scripts/ui/landscape/tests/YawNativeProbe.lua：真实 UI 内部指针派发，默认关闭，不操作 OS 鼠标。
- scripts/ui/landscape/tests/capture_yaw.ps1：后台 PrintWindow 连续截图及时间戳，不注入输入、不调整窗口。
- scripts/ui/landscape/tests/summarize_home_yaw.py：验证原生时间线、复制原始截图并计算证据哈希。
- docs/验证/evidence/home-yaw-probe-r1/：运行证据、检查日志、哈希和素材规格。
- 本行动记录：跟踪默认参数、执行结果、失败与未验证项。

## 自检方法

- 记录真实相机 worldPosition、Euler 朝向、FOV、物件位置及屏幕投影；证明只有 yaw 随时间变化。
- 检查播放/重复播放/中途复位/关闭/重开、尺寸改变、失败清理及默认关闭。
- 查询现有预览状态，只刷新存活预览，读取当前会话日志/check；背景截取指定 PID 窗口，不发鼠标或键盘事件。
- 运行相关既有导航检查和 Lua 诊断；静态/替身/原生自动/人工/手机证据分别标记。

## 自检结果

1. `python scripts/ui/landscape/tests/run_home_yaw.py`：最终 597 项通过，启动宿主阶段 0 为 11/11。涵盖只变 yaw、30/60/144 Hz 模拟时间、连点、复位、隐藏/时间间隔中断、默认关闭、dirty 前更新、关闭重开/销毁与业务/存档写入次数不变。headless，不是原生视觉证据。
2. `python scripts/ui/landscape/tests/run_home_zoom.py`：既有 383 项通过；四种比例、输入阻挡、中断与导航不受新增更新钩子影响。
3. 官方 `preview status/refresh/logs/check --target-dir D:/taptap/To-the-Human-World --json`：刷新前均确认 process_alive=true。会话未更换；reload 1 为首次相机/生命周期通过，reload 2 尺寸测试失败，reload 3 修正后全专项通过。原始失败和通过日志分别保留，未启动停止的预览。
4. 原生内部 UI 指针：播放、连点不重置、复位、播放中复位/关闭、重开重播、底层业务阻挡、尺寸改变后复位与恢复、业务快照相同全部通过。不是 OS 人工操作。最终 session fd7f0f24-b9e4-42df-a1d6-4fcc27bba5a7 / reload 3 / PID 36040。
5. `capture_yaw.ps1 -RuntimePid 36040 -Seconds 52 -Fps 10`：实际获取 492 张窗口截图并记录 UTC/耗时；筛选保留 388 张。已打开查看原生起始、中段、结束、尺寸复位和恢复玩家入口。非正常帧率录屏，不能证明实时流畅度；`native-review.html` 只回看截图，未将浏览器回放当作原生运行。完整原始捕获保存在项目忽略的 `.tmp/yaw-native-frames-verified/`；前两轮原始截图同样保留在 `.tmp`，旧 Maker 日志在正式证据目录。
6. `python scripts/ui/landscape/tests/summarize_home_yaw.py --captures .tmp/yaw-native-frames-verified`：304 个去重相机样本通过；48 物件世界位置、旋转、比例不变；相机 (0,1.65,0)，pitch≈8°、roll≈0°（容差 0.0001°），FOV=50°、aspect≈16/9 固定。3 次完整播放结束 yaw=48.814060°，药炉屏幕投影 (0.5,0.475791)。渲染目标实际记录 1280×720、1056×594、768×432；尺寸变化仅测试原生 UI 验证区域，不算 OS 窗口调整。
7. `maker-lua-lsp --path .../scripts --output-dir .../home-yaw-probe-r1/lsp --mode watch --enable-system-log`：实际检查脚本，最终 0 Error / 27 Warning / 7 Hint。警告包括既有测试、默认关闭分支、本轮两处缓存资源 assert 和测试推断提示。watch 经主动中断退出 1，不描述为一次性诊断进程退出 0。
8. Maker check 的 `result=FAIL`：仍是既有 Cube/Day/DaySpecularHDR.dds 缺失与 themis_x64.dll 加载失败；与本轮 Lua/渲染成功分开报告，不宣称整体运行检查通过。
9. 默认开关恢复 false 后，仅刷新存活预览到 reload 4 / PID 29024，日志与 `player-default-off.png` 已读取/查看，正常主页没有验证按钮、热区框或验证场景。
10. `git diff --check` 退出 0（工作区有 LF/CRLF 提示）；受保护路径 `HomeView/HomeZoom/LayoutGeometry/LayoutManifest/PlayModel/main/core/systems/data/assets/image/urhox-libs` 相对 HEAD 无差异。其他窗口现有文档、素材、编辑器工作保留。

### 已处理失败与偏差

- 首次沙箱执行测试宿主有临时目录 PermissionError，整轮不算通过；允许本地目录访问后重跑成功。没有改系统权限或清理其他人的目录。
- 首次 Lua 诊断暴露 SetRenderPath 的重复声明/可空类型问题；核对引擎声明后采用 Viewport 自带 RenderPath 的 Clone/Load，补齐可空资源类型。未修改引擎。
- reload 2 的测试把 `"60%"` 传给只接数字的 SetWidth，测试画布消失，尺寸断言失败。修正为实际像素宽度，并增加零尺寸画布复位；reload 3 通过。不是把失败截图换成成功声明。
- 无任务范围偏差。测试增加独立 HomeYawMotion 以隔离状态；没有动静态排版或业务契约。

### 参数、生命周期与证据限制

- 实施默认：固定相机 (0,1.65,0)，固定药炉中心 (3.2,1.15,2.8)，yaw 0→atan2(3.2,2.8)=48.814075°，pitch=8° 向下，roll=0°，垂直 FOV=50°，16:9，1.2 秒，smoothstep。角度由占位空间得出，不是正式主页角度。
- 重复播放期间再次点击无效；播放完成停留终点，可显式重播。关闭只释放测试 Scene/自建材质/纹理/NVG video 句柄；没有炼药或导航回调。
- UI 可用尺寸变化、零尺寸、最小化或更新间隔超过 0.25 秒复位。失焦但正常更新可以继续，仅用于视觉验证，不执行业务。中断不留输入锁，关闭在下一 Update 处理；Root.Destroy 也清理资源。
- 尚未验证：OS 人工点击/实际窗口变化/最小化、手机触摸/安全区/性能、GPU 长时内存与图形 context 丢失、正式贴图 UV/接缝/首帧匹配、主观实时流畅度。无正常帧率录屏。

### 正式素材建议（不立即执行）

`docs/验证/evidence/home-yaw-probe-r1/B-material-spec.md` 区分必需/可选：建议先校准首帧，再交同观察点 +Z/+X 两个 90°×90°、各 2048² 的局部立方全景面及配准预览；补齐原画外的右墙、层架、桌面和药炉周边。几何体链路已验证；全景贴图接入未验证。不将普通宽图、不同站位的炼药近景当成全景。

## 交接

- 对象：用户与 A2；素材规格由用户转交 B，不创建或联系其他窗口。
- DAG：固定站位需求 → C 几何/相机/UI 验证 → 用户与 A2 看运行证据 → 用户转交 B 素材规格 → 后续正式贴图验证。
- 结论：原生固定站位转头技术验证通过；正式美术与手机/人工流畅度证据不足，未宣称完成。
- 成果路径：本行动记录；`docs/验证/evidence/home-yaw-probe-r1/README.md` 提供人工步骤，`native-review.html` 提供带时间截帧，`delivery.json` 提供源码与证据哈希。
- 必须修改项：无（本轮已发现问题已修正）。待用户决定事项：无。执行者建议：先由用户与 A2 看原生证据，再由用户转交 B 做同机位投影小样；不自动制作或接入。
