# 药炉点击接入已有转头效果

## 状态与现场

- Completed（入口接入及针对性原生自动检查）；成果 C-STOVE-YAW-ENTRY-20261012-v01。正式美术转场、OS 人工体验和手机验收仍未完成。用户本轮明确要求把已有转头接入药炉点击；替代上轮“仅开发入口”的限制。
- 实际基线：fengyycon@c59c59044218e6be626edb86f66dc950f6943bd2，工作区已含 C-HOME-YAW-PROBE-20261012-r1-v01 未提交成果及其他窗口修改；增量修改，不覆盖、不提交、不推送、不合并。
- 当前 home.stove 直接打开 brew；yawProbe=false 只隐藏独立开发按钮。本轮普通入口无需打开开发开关。
- 用户决定：点击药炉应触发已有转头效果。实施默认流程：点击药炉→自动播放已有几何体转头→原炼药功能页；中途取消/中断返回主页；不会自动熬制。
- 美术限制：现有转头仅几何体空间，不能表达为正式主页美术已连续转向；本轮不生成/替换正式素材。保留捞网推进、业务校验、主页热区与静态排版。
- 初始预览：session fd7f0f24-b9e4-42df-a1d6-4fcc27bba5a7 / reload 4 / PID 29024，存活。仅刷新存活预览，不控制 OS 鼠标。既有 Cube/Day/DaySpecularHDR.dds、themis_x64.dll 错误保留。

## 实施措施

1. AppView 的 home.stove 路由到转头播放，完成后仅导航一次至原 brew；播放时阻止主页/HUD/面板操作。
2. 复用 HomeYawProbe/Scene/Motion，增加自动播放和完成回调模式；保留独立开发验证手动控制。临时几何画面明确标识。
3. 播放完成、取消、尺寸/时间中断、视图销毁均释放资源和阻挡；返回主页可再次播放。
4. 运行针对性入口/时间/中断检查及既有 yaw、net zoom 检查；存活预览刷新、取日志与可得原生证据。

## 影响文件树

- scripts/ui/landscape/AppView.lua：药炉导航及状态/输入隔离。
- scripts/ui/landscape/HomeYawProbe.lua：复用渲染组件的自动播放/结束/取消行为。
- scripts/ui/landscape/HomeYawScene.lua：关闭时解绑渲染目标及 NVG 图像，放弃所持引用，由原生引用计数/GC 管理场景、材质和纹理最终生命周期，避免显式销毁仍被引用的资源。
- scripts/ui/landscape/tests/StoveYawEntryTest.lua、run_stove_yaw.py：真实 AppView/Probe/UI，渲染器、时间和布局适配器；入口、中断与状态回归。
- scripts/ui/landscape/tests/StoveYawNativeProbe.lua：显式开关下原生内部指针、自动播放、取消、重播、GC 重开检查，不注入 OS 输入。
- scripts/ui/landscape/DevChecks.lua：增加默认关闭的 stoveYawAuto 取证开关；交付所有检查开关 false，药炉入口正常可用。
- docs/验证/evidence/stove-yaw-entry/：本轮日志、检查、截图与哈希。
- 本行动记录：实际变更、检查和限制。

## 自检方法

- 真实 AppView + UI 指针派发，渲染器替身仅用于 headless；验证默认开关关闭时点药炉自动播、只导航一次、取消不导航、重复/其他输入阻挡、尺寸/隐藏/时钟中断、销毁、业务状态与写入次数不变。
- 原有 run_home_yaw.py / run_home_zoom.py；可用 Lua 诊断；git diff --check（限定本轮文件）。
- Maker 官方 preview status，存活才 refresh，随后 logs/check；原生自动输入与 OS 人工、手机、视觉流畅度分别标明。

## 自检结果

- headless 入口 370 项、原 yaw 597 项、原捞网 383 项通过（原生视觉仍未据此认定通过）。首次沙箱临时目录访问失败，沙箱外重跑；入口测试小窗口取消坐标错误已修正。
- 用户追加明确授权接入后启动游戏。此前检查到原预览已停止，未擅自重启；获得本轮启动指令后才启动新 session edafe49a-17c6-4126-b1c5-ac2faae3fe5f。
- 原生首次运行出现崩溃，用户截图与本机 minidump 对应：WindowsCrash-2026-10-12 20_44_37_284.dmp，异常 0xC0000005 / UrhoXRuntime.exe+0x6e9ce9。日志有两次完成/释放，第三次新建后崩溃。此轮 FAIL，非通过。自动取证同时受到人工点击干扰，不能把脚本断言失败直接等同崩溃原因。
- 按 diagnosing-bugs 排查资源生命周期。第一假设：场景/材质在 UI 仍持有渲染引用时被显式 Dispose，稍后 GC 或重开触发无效引用；第二：初始布局连续重建目标；第三：其他原生引擎资源问题。没有可用符号化堆栈，未认定引擎内部具体根因。
- 第一次修正仅改变 Scene/Material 的显式 Dispose，仍在第三次重开崩溃（20_51_41_192.dmp，失败日志保留）。第二次再移除 Texture2D 的显式 Dispose，保留 nvgDeleteVideo 和 RenderSurface 解绑，通过下述同类入口/重开原生检查。行为证据支持纹理生命周期问题；不能把未取得的 C++ 内部机制当成定论。
- 原生成功运行：session a4ca4c9a-65f8-4c4d-ba85-02eca0033128 / reload 1 / PID 47536。8 次完整播放、1 次取消，包括 6 次关闭后显式 Lua GC 再重开，脚本 PASS；614 个相机样本固定位置与 FOV，物件位置未变，业务快照前后一致。修正后没有新增崩溃转储。详见 native-pass-lua.log、native-summary.json。
- 最终入口专项再次运行 370 项通过；此前原 yaw 597、捞网 383 项通过。Lua watch 最终 0 Error / 37 Warning / 9 Hint，诊断包括既有及测试/推断提示；watch 主动 Ctrl-C 退出 1，不表述为命令退出 0。首次 check 模式缺少 emmylua_check；首次沙箱 watch 日志无权限而扫描 0 文件，未算通过。测试布局类型错误已修正，最终真实诊断无 Error。
- Maker check 仍 FAIL：Cube/Day/DaySpecularHDR.dds 与 themis_x64.dll 既有错误。第一次修正运行中曾有 Zero sized JSON data project.json，之后实际正常加载；该轮原生日志保留。最终玩家启动日志有 Game started successfully，未宣称 Maker 整体检查通过。
- 截图工具首用 PowerShell 7 缺少 System.Drawing 引用，改用 Windows PowerShell；沙箱无法枚举桌面窗口，经授权后台捕获。成功轮捕获开始晚于动作，251 张实际时间戳截图只覆盖返回后的主页，已查看 native-returned-home.png；没有成功轮动画连续截图或录屏，不声称已目视验收流畅度。失败轮冻结帧和用户崩溃截图不拿来充当成功过程证据。
- 交付恢复所有自动取证开关 false，刷新存活预览到 reload 2 / PID 53324；player-preview.json、player-logs.json、player-check.json 对应当前人工窗口。启动完成，自动脚本不再操作游戏。

## 最终参数与人工复查

- 沿用参数：固定相机 (0,1.65,0)，yaw 0→48.814075°，俯仰 8°，侧倾 0°，FOV 50°，1.2 秒 smoothstep。属于实施默认值，非正式美术相机定稿。
- 点击主页药炉：无需开发按钮、无需再点播放，自动显示明确标注的临时几何画面并向右转头，结束只进入一次原炼药功能页。
- 点“返回主页”后再次点击药炉：重新从起始朝向播放；原捞网入口仍使用门洞推进。
- 播放中点“取消”：回原主页；重复点药炉、商船、结束当天不应触发业务或重复导航。自动流程不熬制、不收信、不购买、不跨天、不改存档。
- 播放中尺寸/最小化/长帧中断取消并释放阻挡；导航或销毁也清理。桌面 headless 中断检查不等于 OS 实测；实际窗口最小化、手机触摸、长时 GPU 内存仍未验证。
- 用户决定、实施默认值和建议分开：用户只要求药炉入口播放；自动完成→brew、取消→home 为本轮默认；正式美术需后续同机位补齐，属于执行者建议，不在本轮生成。

## 交接

- 对象：用户与 A2，由用户转发。DAG：药炉点击→已有转头渲染→原炼药功能页→用户人工复查。
- 正式主页转头美术未完成。待用户决定事项：无。
- 必须修改项：本轮已知崩溃路径已修正并原生复查，暂无新项；人工/手机体验仍待验收。未提交、推送、合并或远端构建。
- 变更哈希见 docs/验证/evidence/stove-yaw-entry/delivery.json；旧 yaw-probe-r1 证据不覆盖。
