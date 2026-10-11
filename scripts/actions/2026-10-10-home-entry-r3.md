# C-HOME-ENTRY-20261010 r3 行动与验收记录

## 状态与现场

- 状态：Completed（本轮接入、自动检查、Maker 启动及人工流程交付完成；验收非全绿，真人／手机与 A 审查待完成）。交接对象：用户与 A 统筹审查；窗口间由用户转发。
- 成果版本：`C-HOME-ENTRY-20261010-r3-v01`。未提交、未远端构建、未推送；代码基线加本轮工作区文件，运行文件哈希见 `docs/验证/evidence/home-entry-r3/delivery.json`。
- 指令：2026-10-10 用户 r3 任务完整替代 r1/r2；本轮交付主页、八个物件入口及现有业务支持的基础面板，不宣称 F1–F6 完工。
- 代码基线：`e4d28622e31838c6d48a564e5ae829bf0dc5de18`。启动时工作区已有多窗口文档、素材增删与排版编辑器修改，全部保留。业务模块 PlayModel/main/core/systems/data 不属本轮写入范围。
- 源工程：`C:\Users\YINGYI\Downloads\寄往人间-排版项目-v0.1-2026-10-10\project.json`；project revision 201，主页 revision 189，1920×1080，11 层，39 份资产。本轮仅采用主页引用的 11 份，不写回源目录。
- 共用业务契约：[程序计划第 3 节](../../docs/superpowers/plans/2026-10-10-landscape-program.md)、[接口手册顶部增量](../前端接入接口手册.md)，已核对 PlayQueries、PlayModel、main 实际代码。计划中历史“拟新增”不代表当前接口缺失。
- 已读根 AGENTS、project-control-report、action-document、Lua 开发指南；参考 01 NanoVG、13 Yoga 绘制、16 滚动列表示例和 UI Widget/HitTest/PointerEvent/ImageCache 实现。UI 库只读。
- 首次 Maker 状态为停止，初期保持停止；用户追加“全量测试后启动”授权后，按 `taptap-maker-local` 官方 CLI 启动和刷新。最终正常玩家窗口运行，实际截图已查看；官方 check 仍因两条引擎启动错误返回 FAIL，详情见下文。

### r3 已确认变更与实现默认值

1. 取消日历图片和重排，顶部真实“第 N 天”及“结束当天”文字按钮，确认后调用 NextDay；这是可调整的功能样式。
2. 桌面信纸必须进入真实阅读与剪词，和抽屉列表共用组件。优先已有 selectedLetter，其次当前订单 letterInstanceId；否则选真实已收信件；无信显示空态。不自动接单。
3. 取消抽屉实体拉开连续动画。先打开真实列表；未来推近后切正对桌面、抽屉已打开的新视角，所需素材未交付。不拉伸原图冒充透视。
4. 完整保留导出构图，安全区内等比 contain；不裁切铺满，不改物件位置、比例、层级。
5. 业务失败显示实际返回；导航、关闭、历史阅读不消费、不清草稿、不重置或发货。词卡保持来源 tokenId。

## 实施措施与完成标准

1. 将 11 份资产原字节复制到 assets/image/home-entry-r3，记录源哈希；LayoutManifest 固定层 ID、视觉变换与局部主体热区，抽屉把手与书使用背景局部坐标。
2. HomeView 用 NanoVG 按清单绘制；独立 HitTest 逆变换处理矩形/椭圆组合，装饰不收输入，正常模式仅按下反馈，开发模式另显示轮廓/ID/命中。
3. PlayView 保留 New/Update/Refresh 接口，装配 landscape；HUD 与关闭按钮使用 UI 基准像素，继承 main 的 SafeAreaView。模态屏蔽下层，侧栏仅遮自身。
4. 接同一会话的来信、阅读剪词、词条、商店、记录、案件空态与跨天确认；海边/炼药使用明确标注的功能界面，保留业务门禁与草稿。
5. 最小同步前端计划中冲突的日历、遗漏信纸与 r3 适配口径；程序契约不修改。

## 影响文件树（实际）

- `scripts/ui/PlayView.lua`：现有入口装配适配器，保留生命周期。
- `scripts/ui/landscape/LayoutManifest.lua`：固定来源版本、资源映射、局部主体热区。
- `scripts/ui/landscape/LayoutGeometry.lua`：绘制与输入共用的坐标变换和形状命中。
- `scripts/ui/landscape/HomeView.lua`：原始分层绘制、独立命中、按下与开发反馈。
- `scripts/ui/landscape/AppView.lua`：HUD、导航、侧栏/模态生命周期，同一模型。
- `scripts/ui/landscape/Panels.lua`：真实只读投影与显式业务按钮，阅读组件复用。
- `scripts/ui/landscape/DevChecks.lua`：热区及只读原生检查开关；交付时两项均为 false。
- `scripts/ui/landscape/人工验收.md`：逐入口预期、收信到发货、跨天与手机人工检查。
- `scripts/ui/landscape/tests/import_layout.py`：固定源版本导入，拒绝覆盖不同运行图。
- `scripts/ui/landscape/tests/HomeEntryTest.lua`、`run_home_entry.py`：隔离真实业务、几何及引擎 Lua 输入分派检查。
- `scripts/ui/landscape/tests/run_regression.py`、`run_ui_contracts.py`：15 组主回归及明确标注的旧 UI 兼容检查；旧脚本选择器只在测试运行时适配。
- `scripts/ui/landscape/tests/NativeProbe.lua`：显式开发模式下，对真实 Yoga 布局发派 PointerEvent，八入口/关闭/状态不变；不模拟 OS 鼠标或手机。
- `scripts/ui/landscape/tests/window_evidence.ps1`：Windows PowerShell 对指定 Maker PID 截图／窗口比例检查，不移动全局鼠标。
- `assets/image/home-entry-r3/`：仅当前主页引用的原始 PNG 与来源清单。
- `docs/superpowers/plans/2026-10-10-landscape-frontend.md`：最小同步用户 r3 决定。
- `docs/验证/evidence/home-entry-r3/`：正常与热区原生截图、版本哈希、测试回执、Maker 原始检查与日志。`logs/home-entry-r3/` 保存各检查原始输出；`logs/home-entry-r3-lsp-final/` 保存最终静态诊断。
- 本行动记录：版本、变更、实际证据、缺失项与交接。

## 自检方法

- SHA-256 与 JSON 逐层坐标核对；运行引用均为 image/，不引用 Downloads。
- 隔离 Lua 真实业务模块 + 明确 UI/File 替身：八入口导航不产生隐式业务；信纸绑定、委托、剪词保留/失败；来源卡、购买、记录、草稿、跨天/待处理门禁。
- 共享几何在 16:9、19.5:9、20:9、4:3 与安全边距下检查主体/相邻空白、旋转和最小触控范围；UI 输入树单目标/模态/侧栏检查。
- 运行 Lua 静态诊断；资源/代码每批后核对 Maker 预览状态，若停止继续保持停止。
- 布局重放图需实际查看，只能证明合成与热区位置，不能代替引擎渲染、真机触控/刘海验收。

## 自检结果

### 通过的检查

1. 源工程 SHA-256 `e4ccb82e4c8b64c0abb8a3c1a005d04b82aa7b0123ec89eec58c1996a50c8ce6`；11 层的 ID/资源 ID/中心/尺寸/旋转/显隐逐值一致，11 张运行图和源图逐字节相同。源工程未改变。
2. `C:\Python313\python.exe -X utf8 -B scripts/ui/landscape/tests/run_home_entry.py`：303 项通过。覆盖八入口不消费、真实信纸绑定和正式委托、剪词保存失败／重复剪／重开保留／滚动节点保留、来源 token、购买失败、草稿／待处理保留、历史重置记录、跨天门禁和发货失败。故障信息在当前弹窗内部可见，避免被模态遮住。
3. `... run_regression.py` 15 组主回归完成：最终回执全部 exitCode 0。含横屏流程／迁移／入口、schema 3 与 schema 2 各 58 配方及 11 订单全链、商店、启动存档、数据校验、9325 组数值区间抽样，以及历史订单／一次性词卡／故事／旧 UI 后端兼容。历史数据与旧界面的测试不算新主页或真机验收。
4. 追加运行 `run_b1.py` 默认存档检查、`--b6-acceptance`、三种 `--config-failure`、八种 `--debug-isolation`：13 组通过，隔离临时存档，不写玩家槽。
5. `maker-lua-lsp --path ...\scripts --output-dir ...\logs\home-entry-r3-lsp-final --mode watch --enable-system-log`：实际诊断完成，0 errors / 17 warnings / 3 hints。16 条 warning 位于既有检查代码，1 条为关闭 nativeProbe 后的恒假分支提示；不宣称零警告。
6. `git diff --check` 通过。`git diff --exit-code e4d2862 -- scripts/data scripts/core scripts/systems scripts/ui/PlayModel.lua scripts/debug scripts/main.lua` 通过，边界内既有程序和正式数据未改。

### 原生 Maker 与实际操作

- 使用 Node `D:\node.js\node.exe` 加已安装 Maker 0.0.36 的 `dist/maker.js`，所有命令指定本项目 `--target-dir`。官方 `console open --no-open` → 窗口设为横屏 1280×720 → `preview start`；之后仅刷新存活会话。
- 开发检查 session `6911b30a-e60f-4b73-9d65-8238dd2f97ff` / reload 3：读取真实 Yoga 坐标，在引擎内发派 PointerEvent，按抽屉、书、托盘、捞网、档案袋、船、信纸、炉子的顺序打开对应面板／场景，再命中真实关闭或返回按钮。八项及导航前后存档一致性通过，见 `native-probe.log` / `native-debug-logs.json`。
- 原生信纸入口本次处于新进度无已收信状态，因此验证到真实来信空态；真实阅读与剪词、错误回滚经过隔离业务测试，真人原生滚动／剪词仍待检查。
- `window_evidence.ps1` 截取并实际查看 1280×720、1560×720、1600×720、1024×768、800×360 的热区图。全部功能物件保留、等比不拉伸、热区对齐主体；800×360 下部分物件较小，手机船／把手触控大小需用户实际确认，不擅改构图。
- 最终两项开发开关已关闭；reload 4 / PID 8184 / 1280×720 普通主页已截图查看，窗口保持运行。`native-home.png` 是最终玩家入口截图，开发图为同一运行实现仅打开检查开关。控制台：`http://127.0.0.1:51492/`，页面入口见 `native-player-session.json`。

### 失败、修正与保留项

- 第一轮有三套旧 UI 脚本仍寻找竖版 tab。商店仅在 `run_ui_contracts.py` 内把两处导航适配为新入口，原有业务断言不改；旧竖版／手机 UI 套件加载固定 e4d2862 的 PlayView，仅验证历史兼容。初始失败回执保留为 `regression-initial.json`。
- 全量追加的旧 B2/B3/B4 在当前内容下分别失败 1 / 1 / 7 个断言（重复词测试旧标记、已移除 `word_sleep`、旧世界／回信字段等）。隔离加载 e4d2862 旧界面、其余程序与基线一致时，三套仍失败；使用其历史内容快照 3dbca09 后分别 212 / 387 / 339 项通过。**这是当前全量检查的三个未通过项，待程序侧迁移旧测试；不把历史通过替代当前失败。** 见 `regression-extra-initial.json`、`baseline-failures.json`、`regression-extra-archived.json`。
- 官方 `preview check` 最终为 FAIL：`Could not find resource Cube/Day/DaySpecularHDR.dds`、`Can not load themis_x64.dll.`。随后日志记录项目启动完成，实际主页显示及原生输入树检查完成；两条错误仍未消除、根因未在本轮定位，不改引擎库。原始回执 `native-check-final.json`。
- 截图辅助脚本先遇到 PowerShell 7 绘图库引用差异，改用 Windows PowerShell；又核对 DPI，避免 1280 窗口被误截成 1024。最终截图为目标客户区实际尺寸。
- Windows 后台 PostMessage 点击未可靠触发操作，保留 `native-postmessage-no-response.png`，不能据此判断玩家点击失败。原生输入树检查首次误用了仅测试替身提供的 GetProps，修正为引擎已核对的 props 后通过；该失败属于检查方法。
- 最初隔离 Python 临时目录在受限执行环境报权限错误，授权提升后检查完成；未修改玩家存档路径。

### 未执行

- 真人鼠标／触摸操作、手机刘海／Tap 胶囊／圆角、触控滚动与真实设备恢复；没有声明通过。
- 原生玩家存档的真实购买／捕捞／剪词／跨天／发货与跨进程恢复未自动执行，避免替用户推进进度；已提供人工步骤。隔离测试覆盖对应业务。
- 云端构建、二维码手机包、远端提交与推送不在授权范围，未执行。

## 遗留与交接

- 缺失美术：抽屉正视打开新视角；正式海边捕捞场景；炼药近景及后续阶段动效。当前不生成。
- 追加授权（2026-10-10）：用户要求“做完接入之后开始全量测试，然后启动 Maker 引擎，告诉我人工测试流程”。完成接入及回归后按官方本地预览流程启动引擎；本条替代此前本轮不启动的限制。无远端提交、构建或推送授权。
- 程序接口：本轮所需查询和命令齐全，无新增业务 API 阻塞；旧测试迁移属于程序侧后续维护。
- 相对任务偏差：用户追加全量测试与引擎启动，故新增专项及实际窗口证据；未扩大至正式近景美术或 F1–F6 全量完工。
- 请 A 审查：源工程重放和八入口热区范围；纸／抽屉共用阅读、正式要求报酬、关闭保留状态；小屏完整构图下的触控尺寸；功能版面板与未完成美术标识；旧测试和引擎 check 失败的分流处理。
- 必须补验：用户按 [人工验收](../ui/landscape/人工验收.md) 实际点击、阅读滚动和手机操作；在宣称全绿前处理三套旧测试迁移和两条引擎启动错误。
- 可选建议：若手机船／把手确实难点，在保持视觉构图下局部扩大命中范围并重新检查邻接；当前不预先改变用户排版。
- 下一步：用户体验 → A 独立审查；缺失素材清单由用户转交 B。当前无需再决定或再次授权。
