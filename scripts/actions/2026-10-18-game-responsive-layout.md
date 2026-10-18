# 全游戏响应式适配

## 状态与情况

- 后续交付更新：同日已完成 [v4 内置游戏 APK 与旧版对比包](2026-10-18-responsive-apk-bundled-game.md)。下文 v3 必须先发布远端 Lua 的限制只适用于历史外壳包；v4 已内置本地候选，不需要本次远端发布，手机验收仍待完成。
- In progress：本地响应式候选与 v3 APK 已生成；游戏 Lua 未发布，手机验收未完成。用户确认执行上一轮响应式方案，并要求覆盖整个游戏。
- 基线：`feat/brewing-bgm` / `9eb6942`；工作区已有音乐设置、同步记录和 APK 交付记录改动，保留，不纳入本轮覆盖。
- 当前是横屏 UrhoX / Lua UI，APK v2 使用联网 WebView；游戏不是普通 DOM 页面。已有 DPR 缩放、局部 compact 分支和排版编辑器定位数据。
- 已确认：背景可延伸，文字与操作保留安全区；小屏减少同屏密度，不把全部控件压小；保持业务模型、存档、一次性消耗和排版源数据。
- 手机截图确认 v2 已移除常驻测试栏，但存在留白和阅读尺寸问题；不据截图认定退出恢复已通过。
- 当前工程未带根 AGENTS 和 engine-docs，使用同工程 `.tmp/audio-api-reference/` 已有官方开发包副本阅读指南与示例，并核对当前 urhox-libs 的真实接口；不修改引擎库。
- 范围为现有游戏界面及隔离 Android 外壳。不新增剧情、系统或美术，不碰他人音乐修改，不操作前台窗口。提交/远端构建在具体交付可审查后按授权核对，不能把本地 Lua 改动当作 APK 已加载。

## 实施措施

1. 统一可用窗口、DPR、字号、触控尺寸与响应式断点；核对 UI 密度缩放，避免安全区重复缩进。
2. 外壳让背景填满窗口，安全区以可信宿主尺寸传入网页，再交给游戏布局；保留 v2 兼容回退，不改 origin、包名、签名或存储。
3. 覆盖标题/引导、主页/HUD、海边、读信/抽屉、词条/记录书、炼药/配方/原料、商店/船票、结果/历史、设置、日历、回溯、愿望与结局；宽度不足时切换紧凑结构、分页或抽屉。
4. 窗口变化只重排，不触发业务命令；维持阅读位置、页码、选择和投料草稿，关闭和主操作可触屏到达。
5. 跑多尺寸布局和 UI/业务回归、Lua 静态检查；重新生成同签名更高版本 APK。分别记录本地实现、远端接入和手机验收。

## 实际影响文件树

相对游戏工程根目录，除新文件外均为已有组件增量调整：

```text
scripts/
  main.lua                              UI.Scale.DPR，保持 MiSans 显式初始化
  actions/2026-10-18-game-responsive-layout.md  本记录
  ui/landscape/
    Responsive.lua[.meta]               新增：安全区度量、断点、滚动位置恢复
    HostViewport.lua[.meta]             新增：启动参数、安全区校验和就绪信号
    AppView.lua                        共享模态、短屏 HUD 菜单、重排状态恢复
    HudLayout.lua                      宿主/引擎安全区优先级
    HarborStyle.lua, ReleaseFrame.lua   共享触控尺寸与短屏信纸内边距
    BrewLayout.lua, BrewView.lua        短屏两列、可展开抽屉；重排不终止熬制
    BrewRecipe.lua                     药槽标签和详情入口
    WordTrayDrawer.lua, WordTrayArt.lua 短屏投影、分页和卡片区
    JournalBook.lua, JournalBookArt.lua 短屏投影和可读记录区域
    LetterDrawer.lua                   手机列表、卡片与触控区
    ReaderOrder.lua                     短屏字段换行、正文避开固定接单底栏
    LetterPresentation.lua             词条托盘提示避开接单按钮
    ShopView.lua                        单商品分页、矮屏卡片、固定购买操作
    MusicSettingsView.lua               有界设置弹窗和滚动；不修改偏好模型
    WishView.lua, WishLayout.lua,
    WishTray.lua                        愿望页安全区、短屏抽屉
    CalendarView.lua                    矮屏日历/说明分列
    EndingView.lua, TravelTicketView.lua 结局和船票安全区与布局
    TitleView.lua                       手机标题菜单宽度
    Onboarding.lua, OnboardingLayout.lua 引导触控尺寸
    ReleaseClosingView.lua              收尾和黎明弹窗
    LoadingView.lua                     矮屏加载页、窗口变化重排
    tests/ResponsiveTest.lua[.meta]     新增：尺寸、状态、宿主协议测试
    tests/run_responsive.py[.meta]      新增：隔离测试入口
```

`[.meta]` 表示同时新增对应 Maker 元数据。未修改 `scripts/data`、业务系统、素材或排版编辑器 Manifest。保留开工前音乐设置、SceneMusicTest 与文档差异，不纳入本轮交付范围。

游戏工程外，用户已授权的隔离 APK 宿主：

```text
D:/taptap/android-web-test/
  src/cn/tothehumanworld/webtest/
    MainActivity.java                  启动参数、同源页面就绪核对、触屏菜单
    ImmersiveWindow.java               系统 Insets 与原生回退边距
  assets/player.html                   引用本地菜单定位脚本
  assets/layout-tools.js               新增：调用官方菜单 setPosition，保留其功能
  AndroidManifest.xml                 versionCode=3，versionName=0.3-responsive
  build.py                            记录真实存储 origin、未内置 Lua 的交付事实
  README.md                           构建、限制、升级/回退和实机验收
  check_responsive_regression.py       隔离前端/业务回归收集器
  probe_local_responsive.py,
  responsive_native_probe.lua         仅后台本地资源拦截验证，不入游戏/APK
  evidence/                           日志、布局、实际引擎渲染和检查结果
  build/20261018T150145Z/              本次最终 APK 构建与升级核对
  backups/responsive-before-20261018T135131Z/  改前宿主可回退快照
D:/taptap/download/
  ToTheHumanWorld-online-test-v3-20261018T150145Z.apk  最终测试宿主
  ToTheHumanWorld-online-test-v3-说明.md             使用限制与安装说明
```

### 实际实现与调整

- 原 UI.Scale.DEFAULT 在较短手机窗口上额外缩小 UI；改用 DPR 对应的逻辑尺寸。统一正文/操作尺度，短屏通过分列、滚动、分页和抽屉减少同屏密度，避免全页等比压小。
- 主界面安全区内保留账本和常用操作，其余进入可触屏菜单；短屏炼药保留锅、药槽、原料与底部主操作。关闭、选中、窗口变化均不触发结算。
- 保存读信/抽屉滚动位置；商店重排保留选中商品；窗口变化只取消拖拽，不取消正在进行的熬制。
- 宿主最终采用官方 `GetArguments` 启动参数。引擎实际返回的键包含 `-` 前缀，游戏端已兼容；参数必须包含有效 session 和有限安全区值，不能超过窗口。初始化后输出带相同 session 的控制台就绪信号，宿主验证同源 URL 后才撤除重复边距。
- 旧游戏没有就绪信号时，继续使用原生安全区保护；系统边距变大时由原生层补足差额，变小时保守保留启动余量。重新加载才重新建立基准，不宣称实现实时双向 Insets 桥接。
- 曾试验网页 `/tmp` 文件握手，真实 Lua File 无法读取；HTTP 尝试被 URL 白名单拒绝。两种实现均已移除，没有修改或绕过引擎权限。相关实验日志保留，废弃测试脚本删除。
- 官方网页菜单移到预留右侧区域，展开项向左；不删除平台功能或水印。Android 原生 `⋯` 保留重试、说明和退出确认。
- 844×390 样例中原料名称与数量在手绘小牌上拥挤，短屏改为底部只显示名称、数量放在卡片右上角；数值仍来自原库存减草稿占用，不改变消耗。

## 自检方法

- 按手机横屏 CSS 等效尺寸（含矮屏与超宽屏）、平板及桌面执行几何与 UI 组件检查；检查可见边界、关闭/确认按钮、正文滚动和物件命中映射。
- 对已打开页面改变尺寸，检查滚动/页码/选中项及模型快照，不产生购买、熬制、发货、结算或清档。
- 执行已有前端与事务测试，以及 Lua LSP；输出分别记录。后台网页只用于启动和尺寸证据，不替代手机视觉/触控验收。
- APK 编译、签名、版本递增、ZIP/哈希和存储地址核对；手机安装、全屏、安全区、触控、退出恢复仍须实机。

## 自检结果

### 逻辑与组件检查

工作目录均明确指定为本游戏工程，测试使用隔离临时存档，不覆盖玩家槽。Windows 受限沙箱最初无法访问测试临时目录；获准在沙箱外执行隔离检查后才得到下述游戏结果，未将基础设施报错算作游戏失败。

- `python -X utf8 -B scripts/ui/landscape/tests/run_responsive.py`：177 个断言通过。覆盖 568×320、640×360、800×360、844×390、960×540、1024×768、1280×720、1920×1080，安全边界、滚动/选中项、熬制状态、模型快照和写入次数，以及宿主参数协议。
- `python -X utf8 -B D:/taptap/android-web-test/check_responsive_regression.py`：19 套中 15 套通过、4 套失败；实际命令和状态见 `evidence/responsive-regression/summary.json`。
- 通过：word_tray 64、journal_book 67、brew_workbench 191、reader_bounds 48、second_batch 97、letter_drawer 98、shop_view 55、wish 9 组、wish_overflow 23、first_batch 966、onboarding、travel_ticket 47、departure 5 组、apprentice 6 组及 responsive。
- 收尾修改后重新运行 responsive、reader_bounds、shop_view、word_tray、first_batch、brew_workbench，6 套均通过，见 `final-summary.json`；引导/收尾调整后还复查 onboarding、departure、first_batch。最后移动读信提示后再次执行 reader_bounds，48 断言通过。
- 4 套失败用 `.tmp/responsive_baseline.py` 从 `git show HEAD` 注入改前 UI 源码复现，未覆盖工作区，保留 `*-HEAD.log`。这只说明未由本轮 UI 差异引入，不能视为全部玩法通过：
  - home_entry：第 157 行等待熬制结果失败；测试只推进 70 帧，与现有 1.6 秒动画不匹配。
  - home_hud：第 57 行假设日历存在通用 panelHeader，实际为 false。
  - landscape_flow：第 78 行 `real reward once` 断言失败，仍需单独核对现行内容与夹具。
  - release_startup：NextDay/启动状态断言失败，未完成根因修复。

### 静态与真实渲染检查

- `.tmp/check_responsive_lsp.py` 使用已安装的官方 Lua language server stdio（CLI wrapper 的 emmylua_check 不可用）：最后一轮 31 个 Lua 文件，0 Error、335 Warning。未把 Warning 清零或声称全部类型问题解决。结果：`evidence/responsive-lsp/final-console.txt` 和 `diagnostics.json`。他人 MusicSettings / SceneMusicTest 改动未纳入本轮范围。
- `git diff --check` 通过；Git 的 LF/CRLF 提示是行尾提示。
- `python -X utf8 -B probe_local_responsive.py`：独立后台 Chrome 使用官方 Web 引擎 1.34.8 c3b4c991，拦截游戏资源为本地候选，仅在该隔离进程追加验证回调，未上传。800×360、568×320、1280×720 的 16 份捕获位于 `D:/taptap/android-web-test/evidence/local-responsive-20261018-230049/`。
- 已查看标题、主页、抽屉、词条、记录书、商店、日历、炼药、读信和设置的实际渲染。检查到的商店卡片/翻页区、菜单压账本、读信提示压接单按钮问题已修改。`layout-checks.json` 仅覆盖所列可见控件，不代表每个页面每个控件都已验证。
- `python -X utf8 -B probe_local_responsive.py --reader`：最终读信提示修正后的渲染与滚动记录位于 `.../local-responsive-20261018-230615/`。800 读信滚动到 260，改为 568×320 后仍为 260，剪词后仍为 260，且提示显示新增词条。使用隔离存档和实际 UI 回调，未模拟手机手势，不等于实机连续剪词验收。
- 原料名称/数量分开后，重新执行 brew_workbench，191 断言通过；故障注入的 WriteString false 和满槽报错属于该测试的预期拒绝路径。
- `python -X utf8 -B probe_local_responsive.py --phone` 最终样例在 `.../local-responsive-20261018-231659/`：844×390、DPR 3，模拟安全余量 left=44、right=108（包含菜单 64）、bottom=21；标题/引导/主页/读信/商店/炼药均有渲染和尺寸记录。最终原料数量分离为右上角独立标签，名称保留底部。属于本地候选示意，未宣称 iPhone WebKit 或真机通过。
- 后台截图用于定位与候选展示，依据 fyyAGENT §5 不作为最终视觉/触控验收。平台引擎小齿轮在浏览器动态改变模拟尺寸后的定位尚未完成核查。

### APK 与升级核对

- `python D:/taptap/android-web-test/build.py`：Java/DEX 编译、apksigner v2/v3 和 zipalign 通过。
- 最终 APK：`D:/taptap/download/ToTheHumanWorld-online-test-v3-20261018T150145Z.apk`，1,064,238 字节；SHA-256 `f6ed188a80f04bff24648022419447e72236f46b6eaf85c6383322aa07a7e54b`。其他 v3 时间戳为中间候选，不交付旧握手版本。
- 包名 `cn.tothehumanworld.webtest`、原测试签名不变；同一 `https://appassets.androidplatform.net` origin、m_h4x3 项目和访客入口，无清数据调用。`build/20261018T150145Z/upgrade-audit.json` 全项为 true，包括 ZIP CRC、启动配置一致、无 Lua/私钥、菜单脚本已入包、废弃桥接已移除、交付哈希一致。私钥仍只在本机 `.signing`。
- APK 未在手机安装。保持地址与签名是升级条件核对，不能替代同用户同槽退出重开验证。不得通过卸载或清除数据安装。

## 尚未完成与交付边界

1. 本轮未提交、推送或远端构建。APK 加载远端 Lua，不包含本机游戏代码；远端本轮观察值为 1.0.30，安装新 APK 不会自动得到本地所有 UI 变化。
2. 本地候选已可审查；按 fyyAGENT §6，游戏提交/双端推送/Maker 构建需明确交付授权。获准后须重新核对两端引用，在隔离集成中保留其他窗口修改。
3. 手机仍须验收：页面视觉、触控、长信滚动、安全区、两个菜单、横屏翻转、草稿/待处理试做/重置后/发货后的同槽退出恢复与重复结算，以及联网异常。
4. 尚不能声称所有后期页面已逐一完成真实引擎或手机验收；共享布局和对应组件测试已接入，完整结果/历史、回溯、愿望与结局的人工流程仍待走查。
5. 用户另问 iPhone 常规屏幕效果，本轮追加 844×390、DPR 3 的布局样例（模拟左右安全余量及右侧 64 菜单保留位）。这是 Chromium 中的尺寸示意，不是 iOS Safari、iPhone 真机或 iOS 安装包。最终样例 `.../local-responsive-20261018-231659/` 已包含原料数量标签收尾调整。

## 当前尺寸与响应规则

尺寸为 UI 逻辑像素、宽×高，非面板物理像素；不是机型白名单。布局连续计算，安全区由宿主/引擎提供。下表模式按本轮测试安全区计算，实际设备边距可能改变分支。

| 尺寸 | 当前响应模式 | 已有证据 |
|---|---|---|
| 568×320 | 紧凑菜单、矮屏炼药双列、抽屉按需展开 | 几何/状态测试；读信/剪词、商店、炼药、设置渲染 |
| 640×360 | 同类矮屏布局，增加可用宽度 | 几何/状态测试；未逐页渲染 |
| 800×360 | 紧凑菜单、矮屏双列、短屏弹窗 | 几何/状态测试；标题/主页/抽屉/词条/记录/商店/日历/炼药/读信渲染 |
| 844×390 | 常规手机横屏样例，紧凑菜单和矮屏双列 | 几何/状态测试；标题/引导/主页/读信/商店/炼药渲染 |
| 960×540 | 保留紧凑菜单/抽屉，不触发可用高度<520的炼药双列 | 几何/状态测试；未逐页渲染 |
| 1024×768 | 此次安全区下可用宽度<1000，仍使用紧凑菜单/抽屉 | 几何/状态测试；未逐页渲染 |
| 1280×720 | 宽屏展开布局、炼药两侧抽屉 | 几何/状态测试；设置页渲染 |
| 1920×1080 | 宽屏展开布局，沿用桌面结构 | 几何/状态测试；未逐页渲染 |

共享规则：可用宽<1000或可用高<520进入紧凑模式；可用高<520进入矮屏重排；主页可用宽<720进一步把跨天/回家移进菜单。商店按内容区可用宽<900切换每页1件（否则2件）。正文不随整页等比压小；新短屏主操作按44逻辑像素触控尺寸布局，但未宣称全游戏所有触点已在实机完成测量。八组尺寸均未完成手机实机验收。
