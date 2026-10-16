# 透明日历与跨天撕页

## 状态与情况

- 状态：Completed（本地实现、自动检查、桌面原生日历及两种过渡验证完成；手机验收未完成）。工作区 `D:\taptap\To-the-Human-World-endings`，分支 `feat/ending-flow`；保留上一轮尚未提交的跨天／结局规则修改。
- 用户已确认日历视觉及透明抠图，明确背景只用现有游戏界面，并于 2026-10-16 要求继续接入。
- 本轮实现动态日期、发货印章、结束／取消操作，以及保存成功后的约 1.5 秒撕页。最后一单完成时收起日历进入收尾，不产生第 12 天。
- 复用现有 NextDay 命令与门禁，不修改剧情、数值、存档格式、主线或其他结局演出。
- 初始工作区缺少 Maker 本地绑定；用户随后授权本地预览重启，已核对既有游戏身份并补齐最小配置。实际原生结果见文末接续记录。不运行 init、不提交或推送。

## 实施措施

1. 用已确认透明日历制作无日期／无印章／无文字底图，保留木架、纸页、黄铜夹和灯塔；状态及按钮由 UI 实时显示。
2. 将 day 面板交给专用日历视图，背景继续展示当前游戏场景；安全区内自适应，阻止点击穿透。
3. 命令保存成功后才播放撕页；冻结当次日期，重复点击不再次推进。失败保留日历并展示错误，提交不确定可同槽重读。
4. 动画使用现有 NanoVG 与 UI 控件渲染，分离纯运动状态和业务命令；关闭／重读／失焦不重放业务提交。
5. 全部委托完成时用收起动作结束，随后同步现有收尾页。补充有时钟的 UI 集成、故障、陈旧回调及渲染调用检查。

## 实际影响文件树

```text
assets/image/calendar-r1/blank.png + .meta     透明无字日历底图
assets/image/calendar-r1/source.txt + .meta    内置 image_gen 编辑来源与完整最终提示词
scripts/ui/landscape/
  CalendarMotion.lua + .meta                  只负责时间与纸页运动
  CalendarArt.lua + .meta                     纸页遮罩、18 段连续弯曲、印章、安全区布局
  CalendarView.lua + .meta                    日历控件、保存后启动、动态日期／印章／按钮
  AppView.lua                                day 面板路由、动画生命周期与输入锁
  Panels.lua                                 移除旧通用确认页入口
  人工验收.md                                日历跨天操作与验收边界
scripts/debug/
  CalendarIntegrationTest.lua + .meta         日历与真实状态／存档接口回归
  ReleaseUITest.lua                           既有跨天断言适配动画时序
  run_release_rules.py                        专项检查入口
scripts/actions/2026-10-16-calendar-transition.md 本记录
```

此外，忽略目录 `.tmp/` 内有本轮 LSP 客户端、浏览器参考导出及检查脚本和日志，不作为运行内容提交。浏览器参考位于工作区外的授权视觉目录；生产代码不依赖它。此前其他文件的跨天／结局规则改动没有撤销或覆盖。

实际交接关系：`AppView` 路由 day 面板并维持动画中的控件树；`CalendarView` 经 `PlayModel.NextDay` 调用已有存档命令，成功后交给 `CalendarMotion`；`CalendarArt` 只绘制，动画更新从不重复执行业务命令。最后一封完成后延迟已有 closing 路由，待收起动画结束才显示结局选择。

## 自检方法

- 真 schema 4＋内存存档：未发货不可撕、成功仅加一天、重复点击、保存失败、提交不确定与重读、最后一单不加天、陈旧控件回调、失焦／销毁。
- 控件实际渲染函数的调用检查与安全区布局计算；用真实素材提供可查看的动画预览，明确其与原生游戏的区别。
- 检查素材透明通道、日期没有烘焙；使用已安装 EmmyLua LSP，核对最终差异和 UTF-8。
- 原生窗口、手机触摸和实际视觉验收另列结果；适配器不代替原生证据。

## 自检结果

### 本轮实际运行

使用已有 Lupa 与只读引擎资料，不安装依赖，不读取玩家存档：

```powershell
python -B -X utf8 scripts/debug/run_release_rules.py --suite calendar --lua-deps 'D:\taptap\To-the-Human-World-bgm\.tmp\b1-python' --engine-libs 'D:\taptap\To-the-Human-World-bgm'
python -B -X utf8 scripts/debug/run_release_rules.py --suite ui --lua-deps 'D:\taptap\To-the-Human-World-bgm\.tmp\b1-python' --engine-libs 'D:\taptap\To-the-Human-World-bgm'
python -B -X utf8 scripts/debug/run_release_rules.py --suite gates --lua-deps 'D:\taptap\To-the-Human-World-bgm\.tmp\b1-python' --engine-libs 'D:\taptap\To-the-Human-World-bgm'
python -B -X utf8 .tmp/check_calendar_lsp.py
python -B -X utf8 .tmp/export_calendar_preview.py
node --experimental-websocket .tmp/check_calendar_browser.mjs
git diff --check
```

- Calendar：**10 passed / 0 failed**。真实状态／存档接口＋隔离时钟／UI 控件适配器；包含未接信／接单／待确认、先保存后动画、仅一次 DayStarted、重复与陈旧回调、失败重试、提交待核对后同槽恢复、最后一单收起、失焦／销毁、安全区几何、绘制调用和真实 UI 输入遍历。最终日志 `.tmp/calendar-checks.txt`。
- ReleaseUI：**11 passed / 0 failed**。既有购买、愿望、船票、学徒、恢复流程和跨天页面回归；只调整日历的等待时序与按钮文案。测试的收尾事务使用缩小必需订单集合的专项夹具；完整 11 单链路沿用 [上一轮记录](2026-10-15-ending-day-gates.md)，本轮没有再运行完整链路。
- ReleaseDayGate：**8 passed / 0 failed**。发货前跨天受阻、一／二星发货可跨天、保存失败与恢复、旧 D14 继续补信、旧收尾恢复、历史结局和船票提前离开回归。
- EmmyLua：7 个本轮涉及的 Lua 文件，**0 Error / 36 Warning**。警告包含既有可空字符串／测试适配器，以及闭包与动态表的类型推断；不把它们描述为零告警。明细 `.tmp/calendar-lsp/diagnostics.json`，摘要 `.tmp/calendar-lsp-summary.txt`。
- 浏览器参考：**6 项通过**。素材及字体加载、真实指针点击开始撕页、未寄出禁止确认、最后一天收起、取消、无 JavaScript 异常；已检查静止、0.35／0.65 秒撕页、次日和未寄出截图。检查后已关闭本轮独立临时浏览器。
- `git diff --check` 通过。未改数据配置、主线、存档协议或第三方引擎；未提交、推送、构建。

### 素材与可查看交付

- 运行底图：[blank.png](../../assets/image/calendar-r1/blank.png)，使用内置 image_gen 编辑已批准抠图，最终提示词与来源：[source.txt](../../assets/image/calendar-r1/source.txt)。原图保留。
- PNG：1254×1254 RGBA；alpha 范围 0–255，549,973 像素 alpha=0，四角透明；纸／木／铜采样 alpha=253，主体近乎不透明但不宣称全部为 255。肉眼检查未残留日期、红章或按钮文字。
- SHA256：`869758EB67B3D84F7594058D651D31684C895BFDA53790D1205E4D31EB6520EC`。
- [可点击浏览器预览](C:/Users/YINGYI/.codex/visualizations/2026/10/15/01a13fef-df38-7ca1-8582-9475f76d0e59/calendar-preview/日历过渡预览.html)：点击右下纸角，也可切换未寄出／旅程收尾。从生产控件属性、运动采样和游戏主页素材导出，Canvas 参考渲染，不是原生游戏。
- 同目录 `calendar-rest.png`、`calendar-tear-035.png`、`calendar-tear-065.png`、`calendar-tomorrow.png`、`calendar-waiting.png`、`browser-checks.json` 保留参考画面及检查结果。

### 实际遇到的问题与未完成项

- 首次日历检查把一次保存误计为一次文件写入；现有双文件协议实际有多次写入。改以存档 revision＋DayStarted 次数确认只跨一天，重跑通过。新增输入遍历检查曾缺少测试鼠标枚举，补齐与已有 UI 测试相同的适配后通过。
- 首次 LSP 返回 0 诊断，属于检查未完成；再次运行取得完整诊断，最终检查仍为 0 Error。
- 首次浏览器启动受沙箱进程通信限制；经自动批准使用独立临时配置后成功。Node 20 需启用实验 WebSocket；点击检查需等待动画帧。这些是预览检查工具问题，修正后 6 项通过。
- 前一轮改动后状态检查返回 `Preview requires a bound Maker project with .maker-mcp/config.json.`；本轮已解决绑定并补充桌面原生画面／过渡验证。**真实玩家存档退出重进、手机触摸和动画性能仍未验收**；没有初始化新 Maker 项目或启动其他工作区。
- 后续按 [人工验收](../ui/landscape/人工验收.md) 在手机验证触控与性能；三个结局的正式演出仍未制作，主线仍不接入。

## 本地原生预览接续（用户已授权重启验证）

- 状态：Completed。原生日历检查完成，普通预览已恢复并保持打开。用户于本轮明确要求“本地预览重启验证”。沿用本记录，范围是启动当前 endings 副本、检查实际窗口／日志并验证日历；不提交、推送或远端构建。
- 已核对官方 `apps --json` 的《寄往人间》UUID `76909fb8-3dc3-4adc-8c49-fe56bab4393e` 与 SCE `m_h4x3`，和本地 `.project/project.json` 及既有同游戏副本配置一致。补齐当前副本忽略目录 `.maker-mcp/config.json` 的最小项目 ID，保留 GitHub remote，不 init、不新建项目。
- 计划按官方 CLI status → start／refresh → logs／check 执行；可能准备／下载公开运行资源。启动状态、可见窗口、日历实际交互和手机验证分别记录。
- 验证存档使用隔离测试槽／现有隔离测试会话；不为展示下一天或最后一天覆盖玩家进度。必要的验证工具及证据放 `.tmp/calendar-native/`，实际临时改动恢复后再次检查。
- 临时检查入口：备份 `scripts/ui/PlayView.lua` 后，以现有 `ReleaseFixtures` 内存存档构造已发货第 1 天，再逐单真实完成 11 封信；原生 Yoga 布局和引擎指针命中确认控件，逐帧截图。结束后按原始字节恢复入口并再次刷新正常预览。工具／备份／日志放 `.tmp/calendar-native/`。
- 当前进展：已启动当前副本，实际 OS 鼠标打开正常第 1 天日历；原生截图确认透明底图叠加当前小屋，未发货按钮禁用。预览日志仍有既有 `DaySpecularHDR.dds` 与 `themis_x64.dll` 提示，Maker `ready=false`，与实际窗口已加载分别记录。隔离检查第一次在截图落盘阶段失败：引擎不接受工作区绝对截图路径；改用已有原生检查使用的相对文件名后重跑，不据此判断日历功能失败。

### 本轮原生与隔离结果

- 正常玩家入口：实际桌面鼠标命中顶部“结束当天”，打开透明日历；1280×720 截图 `normal-calendar.png`。背景是当前游戏小屋，无额外背景图；当前第 1 天未寄出，确认按钮禁用。
- 普通跨天：session `1050d266-c60e-4a3b-a22a-791003cc0c2b` / reload 2 / PID 47108，使用真实 GameSession 和内存存档。原生 Yoga 命中与 PointerDown/Up 触发按钮，确认已保存第 2 天、视觉仍显示旧纸第 1 天；截图检查弯曲／滑落期间日期和红章跟纸移动、底下露出第 2 天；动画结束关闭，重新打开显示第 2 天且不可再次确认。
- 全 11 封数据：`python -B -X utf8 .tmp/calendar-native/export-final-fixture.py` 逐单调用真实接信／剪词／接单／试做／发货命令，并以同一存档协议重读，确认当天为 11、`canClose=true`。这一步使用 Lupa 与内存适配器，**不称为真人或全链路原生操作验收**。日志 `final-fixture-build.txt`，隔离存档 `final-files.json`。
- 最后一天原生：session `102dd194-5073-47e9-a173-7eb348d529ac` / reload 1 / PID 25956，载入上述完整存档到内存会话。实际渲染“第 11 天／收好日历”，引擎指针命中后执行真实关闭命令，收起动画结束出现愿望／学徒选择，天数仍为 11。检查输出 `PASS native final-day Yoga/pointer/render and collection without day12`，同时断言正常玩家会话前后相同。日志 `final-probe-logs-r1.json`。
- 原生截图位于 `.tmp/calendar-native/`：`calendar_native_fixture-day1-shipped.png`、`calendar_native_fixture-tear-032.png`、`calendar_native_fixture-tear-067.png`、`calendar_native_fixture-day2-home.png`、`calendar_native_fixture-day2-waiting.png`、`calendar_native_fixture-day11-complete.png`、`calendar_native_fixture-collect-045.png`、`calendar_native_fixture-ending-choice.png`。均由实际游戏 Graphics 截图并逐张检查；文件名为采样阈值，不承诺严格帧时间／性能测量。
- 临时入口已按备份字节恢复，`scripts/ui/PlayView.lua` SHA256 `7D21836D31E8F31EB54187EB6DF0B80C34514355204BA18A9901E5D43F4DE02D`，无 Git 差异；日常开发开关保持 false。检查脚本、原始入口备份及两版临时探针仅留在忽略目录 `.tmp/calendar-native/`。除本地绑定和验证记录外，本轮没有永久玩法代码变更。
- 恢复后的正常预览：session `102dd194-5073-47e9-a173-7eb348d529ac` / reload 2 / PID 48540 / HWND 14947700，1280×720；实际 OS 鼠标依次打开日历、点击灰色确认、取消、重新打开，确认仍是第 1 天，取消回到小屋且金币仍为 30。窗口最终停在正常第 1 天日历。截图 `normal-disabled-click.png`、`normal-cancelled.png`、`normal-calendar-restored.png` 已查看；`restored-preview.json`、`restored-logs.json`、`restored-check.json` 保留最后状态。
- 最后官方 `preview check`：进程运行且存活，`result=FAIL` / `ready=false`，仅列出上述两个引擎资源错误；不是日历路径失败，也不称为完整运行环境通过。最终 `git diff --check` 通过，未提交／推送／远端构建。

### 检查失败与边界

- 原生连续批量发货在第 5 封之后进程停止，没有捕获明确退出原因；该批量探针未判通过。改用适配器生成完整 11 封合法存档，再分别验证原生末日显示、真实关闭命令和收起动作；没有把批量探针的失败归因于日历。
- 最终日历探针首次使用按钮的 `GetText()`，原生按钮不提供此方法，测试报错；改读原生已有 `props.text` 后重跑通过。生产日历代码无需修改。
- 沙箱内看不到桌面 HWND；经已授权的本地预览验证取得桌面访问后，按 PID、标题和前台窗口核验再点击。旧 Windows PowerShell 对 UTF-8 中文标题的解码不兼容，点击工具改在现代 PowerShell 执行；无标题／尺寸／焦点确认时拒绝点击。PostMessage 未触发该窗口输入，实际鼠标点击另行验证，不把消息投递当作点击成功。
- Maker 整体检查受既有 `Cube/Day/DaySpecularHDR.dds`、`themis_x64.dll` 两项错误影响，不能报告全绿。桌面截图和具体日历路径已验证；手机、安全区实机、端上性能、真人连续完成 11 封和真实玩家存档退出重进仍未验收。
