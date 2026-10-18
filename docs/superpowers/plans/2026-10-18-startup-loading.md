# 启动预加载与雾港加载页实施方案

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task in the current session. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **2026-10-18 实施状态：** Task 1～4 的代码、bootstrap 资源、隔离专项与现有回归已完成，实施记录见 [启动预加载与雾港加载页实施记录](../../actions/2026-10-18-startup-loading.md)。原生窗口视觉/首击音效、手机冷启动和真实网络证据未完成；L01～L10 的人工项仍未勾选。

**Goal:** 在正式画面开放操作前完成所需资源的下载、载入与显示准备，减少首次进入时图片补出、字体跳动及首个音效延迟。

**Architecture:** 以小型 bootstrap 资源保证加载页本身完整显示；使用独立 AssetPreloader 管理按场景分组的下载和预热。启动先准备标题、药铺与通用界面；海边、炼药和结局在标题停留期间后台预下载，首次进入前再检查对应组。加载只管理资源与显示，不推进经营状态。

**Tech Stack:** Lua 5.4、urhox-libs/UI、ResourceCache DWP API、UI ImageCache、现有字体和音频系统。

## 1. 已确认的产品方向

用户已确认雾港加载页概念，并要求先写方案。第一版不另画一套美术：复用雾港海面，导出一张低体积背景用于启动。生成的概念图仅作视觉参考，不能作为带文字的运行背景。

流程：**启动 → 雾港加载页 → 标题页 → 开始／继续游戏**。

- 上方：`寄往人间`、`TO THE HUMAN WORLD`。
- 下方：`正在准备药铺……`、细金色进度条、真实百分比。
- 首次需要下载时：`首次抵达，需要多等一会儿。`；已有缓存时不显示这句。
- 完成后淡入标题，过渡 0.25 秒；不添加人为最短等待时长。
- 进度条、文字、金色菱形均由代码绘制，保持横屏安全区适配。
- 没有背景图时先显示纯雾蓝底和加载文字，不能空屏等待一张加载背景。

![已确认加载页概念](../../设计/原型/loading-screen-v01.png)

## 2. 当前证据与适用边界

代码基线：本机 `main@a1b616d`（2026-10-18，实施前重新核对）。

1. `.project/resources.json` 保持 `groups.default=["**"]`，`preload_groups=[]`：入包不等于提前下载。
2. `ImageCache.Get(path)` 首次调用才执行 nvgCreateImage；无效结果会以 handle=0 缓存。
3. `UI.Init` 已设置 ImageCache 的 NanoVG context，不需要另建 NanoVG context；初始化期间还会注册字体并监听字体 DWP ReloadFinished。
4. `ObjectSounds.New` 提前调用 GetResource，但没有等待真实资源回调；SceneMusic 在 Sync 时载入音乐。非空占位对象不构成真实就绪证明。
5. 当前实际音乐为三首：hearth-warmth-loop、seaside-path-loop、brewing-mystery-loop；ObjectSounds 当前有 21 个播放映射。实施以公共清单实时获取，不将数量写死。
6. 当前 main 在创建正式 UI 前完成数据校验与读档；AppView.New 会创建场景、音频并开始同步音乐。需要把“显示加载页”和“正式视图装配”分开。

症状与 DWP 机制相符，但本方案不是冷启动问题已修复的声明。首次声音延迟也可能包含解码／设备初始化，需要原生时间线确认。

依据：`engine-docs/recipes/preload-and-build-refs.md`、`engine-docs/recipes/download-while-playing.md`、`.emmylua/ResourceCache.extensions.d.lua`、`urhox-libs/UI/Core/ImageCache.lua` 和 `UI.lua`。

## Global Constraints

- 只实现启动资源准备与首次场景门禁，不改剧情、数值、来源词卡、结局判定、保存格式或存档槽。
- 不预先触发捕捞、剪词、投料、购买、跨天或结局事务；不靠打开真实页面推进进度来“预热”。
- 不修改 urhox-libs；不通过重启 Runtime、反复重建 GameSession 或 UI.Shutdown/Init 实现刷新。
- 保留 `groups.default=["**"]` 与现有构建忽略规则；只新增很小的 bootstrap 组，不把 default 整组加入预下载。
- 原始背景只读，使用版本化的新轻量副本；不将标题、百分比烘焙进背景。
- 不播放可听见的“测试音”或静音循环一遍所有音效来预热；预载 Sound，不调用业务声音播放入口。
- 不自动清空用户／Runtime 缓存，不安装新 Runtime，不更改服务环境。
- 本方案不授权远端提交／构建。实施中每批代码／资源改动后检查预览，仅存活时刷新取证；停止会话保持停止。

## 3. 资源分层与加载范围

| 组 | 内容与权威来源 | 准备时机 |
|---|---|---|
| bootstrap | 新轻量雾港图；`fonts/HarborHand-Regular.ttf`、`fonts/HarborHand-Medium.ttf` | 引擎启动预下载。保留原 MiSans 注册及依赖 |
| core | TitleView 的正式背景；LayoutManifest、SeaArt 的药铺图层；HarborStyle、PanelLayoutManifest、LetterDrawer、JournalBook、CalendarArt、StoryStyle 的通用界面图；全部交互音效；室内 BGM | 加载页期间下载、载入与预热；完成后开放标题 |
| seaside | SeasideManifest、SeaArt 所用海面／码头／瓶子／捞网／商船；ShopView、MerchandiseArt 的正式商店图；海边 BGM | 标题页后台预下载，首次进入前预热 |
| brew | BrewArt、IngredientArt、MerchandiseArt 的锅／原料／托盘及炼药 BGM | 标题页后台预下载，首次进入前预热 |
| endings | DepartureView 的出走背景、WishView 的桌面／拼贴装饰，以及结局独有的正式引用 | 后台低优先级预下载，首次演出前预热 |

同一路径在多组复用时全局去重，不创建重复纹理或 Sound。图片尺寸和压缩文件大小列入资源审计；不能从 PNG 文件体积推断显存。第一版只把 core 常驻预热，避免启动时将所有结局大图都送入 GPU。

清单只覆盖当前正式运行引用；不扫描整个 assets 强制下载，不包括过程稿、source-manifest 的历史候选、许可证 HTML、测试图、编辑器数据或验证截图。资源被写进清单前，检查本地文件、meta 和构建可达性。

## 4. 实际就绪、进度与异常

### 4.1 状态机

资源控制器：`idle → downloading → loading → warming → ready`；任一步可进入 `failed`；取消／销毁后为 `cancelled`。加载页另有 `preparingTarget → revealing → dismissed` 显示阶段：资源 ready 不等于立即撤掉遮罩。

- downloading：DownloadResources 完成回调成功；不能仅用 Exists 或 GetResource 非空判断。
- loading：每个条目通过 GetResourceAsync 对应的真实资源回调。Sound 在此配置 looped 属性，不创建播放动作。
- warming：图片进入同一 UI ImageCache，handle>0 且尺寸>0；在加载遮罩后面的有效 NanoVG Render 内分批提交小幅绘制。字体已就绪后刷新布局与文字测量，等待真实 UI 帧完成。
- ready：所有本组资源任务成功，只调用一次 onReady，让加载页开始装配目标；它仍保持遮罩。加载页确认目标视图完成一轮布局和一轮遮罩后的渲染，再淡出并恢复输入。目标保持可渲染，由最上层不透明遮罩遮挡；不能把目标 SetVisible(false) 后等待它渲染。

ImageCache 若曾存入 handle=0，在对应资源真实载入成功之后，仅 Release 该失败路径并重新 Get；不得 Clear 全部缓存或每帧释放有效图。字体处理沿用 UI.GetFontVersion 与 UI.MarkLayoutDirty，不重复每帧 nvgCreateFont，也不销毁整个 UI。

### 4.2 进度

下载有可信 totalBytes 时，显示 downloadedBytes/totalBytes，并在文字旁标明正在准备资源；不知道总字节时使用“已准备 X / Y 项”，不展示虚构百分比。

进入载入／预热阶段后使用已完成资源步骤数，显示“正在整理画面……”；阶段切换不把总进度倒退。采用明确任务权重：下载 70%、载入 20%、资源预热 8%、目标首帧 2%。该数字是任务加权进度，不是网络速度或剩余时间估计。资源控制器的 progress 完成时，加载页最多显示98%；目标首帧确认后才显示100%。

缓存命中可迅速完成；无须强迫用户看满一秒。初次切到一个尚未就绪的场景时继续用同一加载样式，已就绪则直接进入。

### 4.3 失败与清理

- 资源失败：停在遮罩上，显示“有些资源没能准备好，请重试。”和“重新加载”；技术路径及原因只进日志。
- 默认 30 秒没有任何字节或任务进展时显示“准备时间比平时久，可以继续等待或重试。”；有进展就重置计时。不因网络慢直接宣告资源损坏。
- 重试只处理失败／未完成条目，保留成功缓存；递增 request generation，丢弃旧请求迟到回调。
- Cancel/Destroy 取消本控制器持有的下载 group，停止自己的观察器，不取消其他调用者的全局下载；后续回调不能改 UI 或启动正式游戏。
- 不能给仍缺关键资源的玩家一个“忽略并进入”按钮。已有存档问题继续使用原错误保护流程，资源重试不能重开或覆盖玩家存档。

## 5. 文件与接口

| 文件 | 职责 |
|---|---|
| `scripts/ui/landscape/AudioCatalog.lua`（新增） | 三首 BGM 和交互音效的唯一映射，提供 Copy 返回的只读条目；SceneMusic、ObjectSounds 和预加载共用 |
| `scripts/ui/landscape/PreloadManifest.lua`（新增） | 显式、完整路径的分组清单；从纯数据布局 Manifest 收集 path，避免 require 控制器来读取资源 |
| `scripts/ui/landscape/AssetPreloader.lua`（新增） | 状态机、资源引用持有、去重、进度、失败、回调世代和取消 |
| `scripts/ui/landscape/LoadingView.lua`（新增） | 已确认构图、纯色兜底、实际进度、重试按钮、输入遮罩和预热 Render |
| `scripts/ui/landscape/SceneMusic.lua`、`ObjectSounds.lua` | 仅接公共音频映射，保持各自循环、设置与播放器生命周期 |
| `scripts/main.lua` | 先显示 LoadingView，再执行原数据校验／读档和正式 UI 装配；保留旧显式验收入口 |
| `scripts/ui/landscape/AppView.lua` | 目标组未就绪时遮挡首次场景／面板进入；就绪后执行一次原导航 |
| `.project/resources.json` | 保留 default；新增 bootstrap 精确资源列表及对应 preload_groups |
| `assets/image/loading-r1/harbor-small-v01.jpg` | 从已有海港图导出 512×288、目标≤80 KiB 的无字背景；不覆盖原图 |
| `scripts/ui/landscape/tests/PreloadTest.lua`、`LoadingEntryTest.lua`（新增） | 明确下载／字体／布局适配器的专项检查 |
| `scripts/ui/landscape/tests/run_preload.py`（新增） | 复用 content_test_runtime 的隔离测试运行器，失败退出非零 |

控制器约定接口：

```lua
local loader = AssetPreloader.New(manifest, ports, options)
loader.Begin("core", onReady)       -- 完成一次；重复 Begin 同组复用请求
loader.Prefetch("seaside")          -- 只后台下载，不预热、不跳转、不抢占前台状态
loader.Update(dt)                   -- 超时提示与预算调度，不阻塞等待
loader.WarmFrame(vg)                -- 在现有 UI Render 中调用
loader.GetStatus()                  -- state/stage/progress/done/total/errors
loader.IsReady("core")
loader.Retry()
loader.Cancel()
loader.Destroy()
```

ports 为测试隔离边界，生产适配器仅包装已核对的 cache API：download / cancelGroup / loadAsync / imageGet / imageSize / imageRelease / fontVersion / markLayoutDirty。options 默认限制最多 4 个并行载入任务；图片每帧最多预热 2 张，单帧预算 4ms，慢设备单张超预算则让出后续帧。该预算是可测的实施默认值。

不要单用 ObserveDownloads 的 activeCount=0 放行：尚未请求的资源不会出现在活动计数里。全局观察只作补充诊断，完成依据是本组明确清单与其回调。

## 6. 分步实施任务

### Task 1：建立清单与基线

**Files:** AudioCatalog.lua、PreloadManifest.lua、SceneMusic.lua、ObjectSounds.lua、PreloadTest.lua。

- [ ] 记录冷／热启动的时间线：首个有效画面、资源下载完成、最后一张核心图出现、首个操作音。使用明确的隔离测试进度，不清玩家缓存或存档。
- [x] 先写清单测试：重复路径只出现一次，目录中的历史图不自动进入清单；三首 BGM 和当前全部音效映射均有对应条目，所有 path 为合法资源路径。

```lua
local catalog = Manifest.Group("core")
assert(CountPath(catalog, "image/misty-harbor-r1/sea-calm.png") == 1)
assert(not HasPath(catalog, "scripts/layout-editor/.local/project.sqlite3"))
for _,entry in ipairs(AudioCatalog.Effects()) do
    assert(HasPath(catalog, entry.path))
end
```

- [x] 运行 `python -X utf8 -B scripts/ui/landscape/tests/run_preload.py --suite catalog`，先确认缺少清单时失败；再抽取公共映射并填入当前正式资源。
- [x] 导出每组路径、字节、图片像素／RGBA 估算、字体大小。清单与正式引用差异必须为零；运行现有 SceneMusic/ObjectSounds/UI 音效测试，确认本步不改变播放行为。

### Task 2：异步下载与真实就绪门禁

**Files:** AssetPreloader.lua、PreloadTest.lua、run_preload.py。

- [x] 先写受控端口测试：请求已发出但无回调、占位对象、单图失败、缓存命中、取消后的迟到回调都不能提前 ready。

```lua
loader.Begin("core", function() readyCount = readyCount + 1 end)
host.DownloadComplete(true)
assert(loader.GetStatus().state ~= "ready")
host.DeliverRealResources()
assert(loader.GetStatus().state ~= "ready")
host.RenderWarmFrame(loader)
assert(loader.IsReady("core") and readyCount == 1)
loader.Destroy()
host.DeliverLateCallback()
assert(readyCount == 1)
```

- [x] `host` 是测试工具：回调顺序由用例明确控制，不能直接把 loader 标 ready。实现 DownloadComplete、DeliverRealResources、RenderWarmFrame、DeliverLateCallback，分别只派发对应边界事件。目标布局／首帧属于 Task 3 的 LoadingEntryTest，不作为触发资源回调的前置条件，避免相互等待。
- [x] 运行 `run_preload.py --suite loader` 确认失败后实现状态机；下载调用使用下列实际 API，处理同步命中回调时也先登记计数。

```lua
cache:DownloadResources(paths, onDownloaded, onDownloadProgress)
cache:GetResourceAsync(entry.type, entry.path, onResourceLoaded)
```

- [x] 增加失败重试、无进展提示、字体就绪、负缓存定点清除、同组请求去重与销毁检查，再跑同一套件通过。

### Task 3：加载画面与启动装配

**Files:** LoadingView.lua、main.lua、resources.json、轻量 JPEG、LoadingEntryTest.lua。

- [x] 先验证原入口会在资源未回调时创建正式视图；将其作为门禁测试。添加“加载失败重试不重复 GameSession／读档／新开局”的断言。
- [x] 导出轻量背景，记录源图哈希、尺寸、文件字节；仅将轻量图与两个项目字体加入 bootstrap。构建引用模式不变。
- [x] LoadingView 在 `UI.Init` 后立即 SetRoot；正式 UI 前保持业务输入遮挡。现有字体选项保留，bootstrap 确保初始化不先用错字体。
- [x] main 将当前数据校验、恢复与 CreateUI 拆为明确的单次启动步骤；Update 内推进 loader。加载期间不装配 AppView，不提前启动 BGM。

```lua
InitUI()
loadingView = LoadingView.New(loader, StartExistingGameOnce)
UI.SetRoot(loadingView.root)
loader.Begin("core", function() loadingView.PrepareTarget() end)
-- PrepareTarget 调用单次正式装配；遮罩保留到目标完成布局与渲染。
```

- [x] 正式装配后调用 `UI.MarkLayoutDirty()` 并在现有帧循环完成布局。LoadingView 在原 NanoVG Render 上预热图片，不能新增独立 nvgBeginFrame。目标帧完成后再移除遮罩、恢复输入及启动目标 BGM。
- [x] `run_preload.py --suite entry` 检查：ready 前无输入／音乐；字体更新前不开放标题；100% 只在最终 ready；Start/Stop 多次不留下回调、下载观察器或播放器。

### Task 4：首次场景切换与回归

**Files:** AppView.lua、LoadingEntryTest.lua、人工验收.md、对应行动记录。

- [x] 先写“第一次进海边／商店／炼药／愿望／出走”未就绪时不能露出半成品或播放占位音的测试；已就绪重复进入不重复请求、不重启同曲。
- [x] 标题页出现后按 seaside → brew → endings 顺序低优先级下载。导航遇到未就绪组时保存一次目标意图并显示 LoadingView，ready 后执行一次原导航；取消／返回／销毁使旧意图失效。
- [x] 后台调用 Prefetch 只补本地下载缓存；下载完成的组仍须经过 Begin 的载入／预热才算 IsReady。前台 Begin 与同组 Prefetch 共享去重后的下载，前台目标优先，后台完成不得覆盖加载页进度或自动导航。
- [x] 仅展示层动作等待资源。已成功保存的购票／结局事务不因资源失败而重复执行；重试后展示已保存结果。

```lua
local original = snapshot()
view.Open("shop")
assert(view.loading and Equal(original, snapshot()))
host.FailGroup("seaside")
assert(not view.shopIsInteractive and Equal(original, snapshot()))
view.loading.Retry()
host.ReadyGroup("seaside")
assert(view.shopIsInteractive and Equal(original, snapshot()))
```

- [x] 跑专项 catalog/loader/entry/navigation，以及现有 SceneMusicTest、ObjectSoundsTest、UiActionSoundsTest、主页／托盘／炼药／结局套件。新增 Lua 文件与修改文件须无 LSP Error，既有项目问题单列。
- [ ] `git diff --check`，每组资源实际路径检查，以及正式构建 manifest 对照；本地测试不触发远端构建，manifest 对照在后续明确授权的构建中完成。

## 7. 验收矩阵

| 编号 | 情况 | 通过标准 |
|---|---|---|
| L01 | 首次无媒体缓存启动 | 加载页完整可见；标题／药铺不逐件补出 |
| L02 | 缓存齐全启动 | 快速通过，无人为停留和重复请求 |
| L03 | 第一次打开通用面板 | 托盘／抽屉／记录书／日历纸面与字体一次完整出现 |
| L04 | 第一次海边／商店／炼药 | 对应组 ready 后才交互；按钮操作音不首击漏播 |
| L05 | 第一次三个结局 | 等待资源不重复扣票、发奖或推进结局；重试保持原进度 |
| L06 | 慢网／断网／单资源失败 | 进度诚实，不假到100%；可等待或重试；不空屏、不死循环 |
| L07 | 字体晚到／图片失败缓存 | 字体后重排正确；失败图片恢复，无错误占位永久缓存 |
| L08 | 静音／音量／退出 | 预载无可听测试音；尊重设置；退出释放本控制器和播放器 |
| L09 | 切后台／旋转／取消 | 回来保持正确阶段，安全区与进度有效，旧回调不打开错误页面 |
| L10 | 低内存设备 | 记录启动／分组前后内存；没有一次预热全部结局大图造成的峰值 |

原生验收须记录首屏录像／连续帧、下载和载入时间点、第一次操作的声音、设备／网络与缓存状态。手机冷启动与桌面本地测试分别记录；无头端口测试不能宣称真实下载、GPU 或听感通过。没有真实资源就绪计时的单纯等待动画不能算完成。

## 8. 交付与回退

第一批交付公共清单与控制器专项；第二批交付加载页和启动门禁；第三批交付首次场景门禁及设备证据。全部在当前会话顺序执行，无需派生其他聊天。

回退范围是新增加载控制器／视图及 main/AppView 的门禁接线；公共音频映射可独立保留。恢复 resources.json 时只撤销本批 bootstrap 项。保留原美术、存档、运行数据和原有播放逻辑。

本轮交付：方案、实现与隔离回归已在当前会话完成；轻量图、bootstrap 组、加载页、控制器和场景门禁已接入。未提交、未推送或构建；原生/手机人工验收仍按第 7 节与[人工验收记录](../../验证/2026-10-18-startup-loading-manual.md)执行。
