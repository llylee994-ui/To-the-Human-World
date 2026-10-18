# 最新代码同步与 Android / Windows 包交付

> 2026-10-18 后续纳管：本文最终 dependencyfix ZIP 已移至仓库 `packages/windows/2026-10-18-e4621ef/ToTheHumanWorld-Windows-x64-e4621ef-dependencyfix-candidate.zip`，内容和 SHA-256 未变。下文 output 路径为生成时的历史位置；旧包和测试证据保留。当前获取方式见 [Windows 包索引](../../packages/windows/README.md)，GitHub 上传结果见 [纳管交付记录](2026-10-18-windows-package-github.md)。

## Windows 依赖报错修复（2026-10-18，当前执行）

- 状态：Completed（两项依赖在隔离包补齐，本机原生回归和重新打包完成；不是 Maker 官方导出或异机/人工视觉验收）。用户要求查明 DaySpecularHDR.dds / themis_x64.dll 两个启动错误，能修复则仅修复隔离包，重新验证并打包；继续禁止影响开发窗口。
- 措施：先在最小原生入口复现并建立明确失败检查；核查资源引用、引擎发行内容与官方来源；一次只调整一种依赖；禁止伪造 DLL、替换无关同名库、屏蔽错误日志或改写二进制跳过功能。可修复时再在完整游戏上验证启动/存档恢复并输出新版 ZIP，保留旧包。
- 影响树：本行动记录；`D:/taptap/output/windows-package-20261018/dependency-fix/` 中的诊断脚本、最小复现、修复候选、来源与哈希、原生日志；最终新版 ZIP 与证据。源游戏程序/配置/美术、共享引擎与开发窗口不修改。
- 验证：最小入口日志明确匹配两条 ERROR；文件来源、位数/导入依赖及资源可加载；完整正式入口、独立 EXE、全流程重开存档及重复确认；源码/共享引擎哈希保持、所有本轮进程收回。
- 最终结果：最小入口、六阶段完整存档回归、最终 EXE 启动和旧包存档迁移均通过，日志不再出现两条 ERROR；新 ZIP 已生成，旧包保留。以下新增证据优先于后文旧候选“仍有两条 ERROR”的历史结论。

### 根因、来源与隔离修复

1. `dependency-baseline` 用不含业务逻辑的最小入口复现两条 ERROR，定位为原生运行环境。原 20260923-1717-bf3316f 的 Res.pak 只有 `Cube/Day/DaySpecularHDR_QualityLow.dds`，没有启动时请求的 `DaySpecularHDR.dds`；官方 ZIP 本身没有 themis DLL。
2. 实际下载官方 CDN latest：20261016-1025-f1b5fc6，92,862,004 字节，SHA-256 `b05dbbe8e024a61fc2afed5ea42b03e09383eb61314534363c28fad256448934`，MD5 与响应 ETag 相等，ZIP CRC 通过。`dependency-official-update` 仍出现同样两条 ERROR，故未升级交付包或共享 Runtime。
3. 用原引擎 `cache:GetFile` 从官方 Res.pak 导出低清贴图，补入包内 `runtime/Res/Cube/Day/DaySpecularHDR.dds`。262,304 字节，64×64 六面 cubemap，SHA-256 `98256975277e225fc0dd42865f45bcd9dcf257f06d63928c4540fbccd2b6ee31`。这是官方低清资源的兼容回退，并非恢复高清图。`dependency-texture-fix` 原生 TextureCube 加载和尺寸断言通过，仅剩 DLL ERROR。
4. [官方诊断接入文档](https://developer.taptap.cn/docs/v3/sdk/tapdb/sdk/client-side-integration/) 指向 [TapThemis-Unity 3.2.3-3](https://github.com/taptap/TapThemis-Unity/tree/3.2.3-3)，其中 `themis/x86_64/themis_x64.dll` 确实存在。下载后核对 Git blob SHA、AMD64 位数、`init_themis_by_appid` 导出、同版本 Windows C# 接口和导入依赖；Authenticode 为 Valid，签发对象 X.D. Network Inc.。DLL 16,045,080 字节，SHA-256 `a7d726c1758fbf72af9fb777964f17313fef4652894782b36e51bf0fec969177`。仅复制到隔离包 runtime；没有安装系统组件、伪造 DLL 或改写引擎二进制。
5. `dependency-both-fix` 最小入口正常退出，游戏日志 ERROR 数为 0；原生贴图加载断言仍通过。完整测试进程中也实际枚举到该隔离路径的 themis DLL。这里证明本机加载/初始化与回归兼容，不代表已验证崩溃上报服务或获得 Maker 原生导出认证。
6. 资料解释：[TapTap 官方文档](https://developer.taptap.io/docs/zh-Hans/v3/sdk/tapdb/features/diagnosis/) 说明 Themis 为崩溃诊断 SDK；[维护方回复 #612](https://github.com/taptap/instant-games-open-mcp/issues/612) 将两个缺失归属 Runtime 维护，关闭 issue 不表示已修复。本轮最初只核查发行包时未找到 DLL，后续沿官方 SDK 文档找到它，以本节最终证据为准。

### 本轮证据目录

- `dependency-fix/official-download.json`：最新版 Runtime 官方来源、发行清单和校验；`old-package-resource-index.json`：旧 PAK 索引。
- `dependency-fix/texture-fix.json`：贴图来源、尺寸和校验；`themis-download.json`、`themis-pe.json`、`themis-signature.json`、`themis-loaded-module.json`：DLL 来源、接口、签名与真实加载。
- `evidence/dependency-baseline`、`dependency-official-update`、`dependency-texture-fix`、`dependency-both-fix`：同一最小复现逐步对照，原始日志均保留；没有屏蔽错误。
- `evidence/texturefix-flow-summary.json`：仅补贴图的六阶段全部通过；`evidence/bothfix-*`：两项均补齐后的正式回归，最终结果见后续交付补记。

### 最终双修复包及复验结果

- 交付：`D:/taptap/output/windows-package-20261018/ToTheHumanWorld-Windows-x64-e4621ef-dependencyfix-candidate.zip`，328,180,438 字节（约 313 MiB），448 个文件；SHA-256 `a992df7d6c88c00c229da706362389c5b863b451f231e0ea60187838964521bd`。推荐本包，旧 candidate.zip 和中途 texturefix-candidate.zip 留作回退/过程证据。
- ZIP CRC 与解压后逐文件 SHA-256 通过；包中无测试探针、测试存档、账号凭证、日志和开发配置。包内 README/BUILD_INFO 明确低清贴图回退、SDK 来源、版本与验证边界。
- `verify_bothfix_flow.py`：draft → pending（提交后强制退出）→ reset → pending_again（重置后采购）→ ship → verify，六个独立进程全部通过。资源序列 30→30→30→18→118→118，正式订单数最后为 1；两个历史记录仍保留；重复发货四次无额外事件/扣料/扣卡/奖励，最后四份存档/提交记录哈希不变。六阶段 game 日志 ERROR 均为 0。
- `final_validation.py`：从最终 ZIP 解压到含中文与空格的新路径，经包内 EXE 正式入口启动、正常关窗、进程退出 0；另外独立解压并导入旧 candidate 的 r2 测试存档，使用该 EXE 恢复完整快照后重复发货，保存哈希不变。两次原生 game 日志 ERROR 均为 0。
- 最终报告 `dependency-fix/final-verification.json`、包收据 `both-package-receipt.json`；证据 `evidence/bothfix-flow-summary.json`、`bothfix-final-exe`、`bothfix-old-save-exe`。迁移测试探针只在验收副本，不在 ZIP 中。
- 434 个游戏源文件和 9 个原共享 Runtime 交付文件重新核对哈希均未改变。测试进程仅运行在新建非输入 Windows desktop，不切换桌面、不移动鼠标、不控制 Maker preview；各测试自有进程已关闭。无提交、推送、系统安装或共享 Runtime 升级。
- 未验收：人工视觉/听感/完整交互、异机运行、平台上传，以及 Themis 崩溃上报服务端结果。后台原生运行与存档通过不替代这些验收；本轮不额外制造崩溃上传或更改诊断身份。

## Windows 自行封装实验（2026-10-18，当前执行）

- 状态：Completed（Windows 本地候选包与本机后台原生存档验证完成；不代表官方导出、异机或平台发布验收）。用户明确授权先在隔离目录制作 Windows 包并验证独立运行、存档；不影响开发窗口。本节优先于下方历史官方导出阻塞结论，Android 仍不在本轮实施范围。
- 源：`To-the-Human-World-bgm` 的 `e4621ef` 加现有本地音乐设置修改。保留源目录文件、分支和共享 Runtime，不调用 Maker preview start/stop/refresh，不提交推送。
- 实施：复制白名单游戏代码与资源、经发行 ZIP 核对的 Runtime；制作相对路径启动器；使用独立 Windows desktop（不切换输入桌面）启动实际图形进程，独立用户/缓存/存档目录；验证后压缩，另解压至含空格中文的新路径复验。
- 影响文件：本行动记录；`D:/taptap/output/windows-package-20261018/` 下的构建脚本、候选目录、验收副本、日志、哈希清单与最终 ZIP。源游戏 Lua、data、UI、美术、项目身份和全局工具不修改。必要的验收探针仅在验收副本，交付包不包含测试进度。
- 验证：源文件前后哈希；发行包文件哈希；禁止凭证/存档/开发缓存混入；实际图形入口完成装配；真实引擎 File 保存、进程结束后重新读取并比较状态；打包后的解压迁移复验；仅终止本轮持有句柄的进程。独立运行与存档验证不等于人工交互/全玩法/商店发行验收。
- 自检结果：详见下方实际交付与证据；Windows 包已生成并在新的解压路径运行。没有提交、推送、上架或修改游戏源码。

### 实际交付与文件

- ZIP：`D:/taptap/output/windows-package-20261018/ToTheHumanWorld-Windows-x64-e4621ef-candidate.zip`，312,777,350 字节（298.29 MiB），446 个文件，小于 2 GiB。单层 `ToTheHumanWorld/` 内含双击入口 `ToTheHumanWorld.exe`、runtime、scripts、assets、使用说明和 BUILD_INFO.json。
- SHA-256：`614b7fe64ba09766d6080ad58a463a812944c1210084bed7c7d4210daff11c73`。
- ZIP 不包含测试探针、测试存档、日志、Git、本地 Maker 绑定或凭证。构建器按清单写入，未将整个工作区压缩。
- 原生发行文件与已安装官方 ZIP 逐字节相等；字体单独核对。正式游戏 Lua 保持原样。新启动器以 .NET Framework 4 编译为 Windows x64 GUI EXE，设置相对包路径、工作目录和独立环境；同目录互斥避免两个实例同时写档。玩家运行无需 Maker、Python 或 Node；编译工具不随包分发。
- 持久存档实际位于 `temp/savedata/unknown/0/`，包括进度与 music_settings.json；**此 temp 不能当作可清理缓存**。包内使用说明已明确备份、更新和迁移需保留它。User/ 是启动器创建的隔离环境目录，不是本轮实际业务存档路径。
- 包外脚本与证据均在 `D:/taptap/output/windows-package-20261018/`：build_candidate.py、Launcher.cs、package_zip.py；isolated_run.py、PackageProbe.lua、verify_flow.py；source-manifest.json、package-receipt.json、verification-report.json、evidence/。候选目录、测试副本及中文空格解压副本保留供复核，没有清理其他目录。

### 实际验证结果

1. `python build_candidate.py`：434 个源代码/资源文件复制前后哈希一致；最终复核源目录全部仍一致。共享 Runtime 的 9 个交付文件也未改变。Git 分支/HEAD 未改变，既有改动保留。
2. 原始入口 `scripts/main.lua`，通过独立非输入 Windows desktop 运行实际图形 Runtime（非 headless），约 2 秒出现启动完成。没有 SwitchDesktop、鼠标/键盘注入、Maker preview 会话控制；测试静音。实际主窗口客户区为 1024×576，不能将命令中的 1280×720 当作测得尺寸。依据 [Windows STARTUPINFO.lpDesktop](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfow) 设置进程桌面；只向本轮自有 HWND 发正常关闭消息。
3. `python verify_flow.py` 最终 r2 全流程 6 阶段通过，直接调用生产会话公共接口，使用原生 File、实际内容与 schema 4，没有内存存档替身或补发资源。89 项 PreloadManifest 资源实际加载成功；音乐音量 37/关闭也跨进程保持。

| 阶段 | 实际结果 |
| --- | --- |
| draft | 剪词、接单、保存草稿；正式资源未因选料消耗，尚未冻结基准；正常关窗 |
| pending | 新进程从正式入口恢复完整草稿，熬制生成待处理；资源未消耗、采购被锁；提交完成后强制结束该测试进程 |
| reset | 强制退出后恢复完整待处理状态；重置保留正式资源及 reset 历史；正常关窗 |
| pending_again | 重开恢复重置状态；采购后金币 30→18；新基准包含补货，试做 ID/基准 ID 更新；旧事务不能发货或重置 |
| ship | 重开恢复第二次待处理；发货后金币 18→118、订单数 1；消耗指定词卡及原料一次；两次重复确认不改变快照、不增事件 |
| verify | 新进程恢复发货后完整状态；再重复确认两次，0 个事件、四份进度/提交记录 SHA-256 完全不变；两个试做记录保留 |

4. `python package_zip.py`：ZIP CRC 校验、逐文件 SHA-256 与解压核对通过；解压到 `解压 验收/ToTheHumanWorld`，直接用最终包的 EXE 启动，正式入口装配成功、正常关闭、启动器和 Runtime 都退出 0。不依赖开发目录中的启动脚本或 Python/Node PATH；仅当前本机验证，未在第二台干净电脑验收。
5. 另从 ZIP 解压到 `存档搬迁 验收/ToTheHumanWorld`，只迁移上述测试存档，在该验收副本追加只读恢复/幂等探针，由同一个包内 EXE 启动：完整快照一致、重复发货 0 事件、存档哈希仍不变。该项是搬迁兼容验证，不冒充同目录退出恢复；同目录跨进程证据见 r2 各阶段。
6. 汇总：`verification-report.json`；每阶段的命令、PID、窗口尺寸、关闭方式、原生日志和状态在 `evidence/`。最后未发现仍运行的本轮 Runtime/启动器；没有关闭他人窗口、操作输入桌面或改变系统配置。

### 失败修正与未验收项

- 首版验收探针重新订阅 Update，覆盖了原入口用于加载的回调，导致测试副本停留加载中。修正为包装并先执行原 HandleUpdate，未改交付入口；不能把失败说成游戏本身加载故障。
- 首次发货探针将 Reset 用的 baselineId 也传给 Confirm，被真实接口以 UNKNOWN_FIELD 拒绝。按接口只传 orderId/transactionId 后，从全新 r2 目录重跑 6 阶段全部通过；失败日志保留。
- 引擎仍输出 `Could not find resource Cube/Day/DaySpecularHDR.dds`、`Can not load themis_x64.dll.` 两类 ERROR。没有修补发行二进制或掩盖日志；因此不声称引擎零错误。项目 Lua 日志中没有本轮最终验收失败或 traceback。
- 未做人工触控/鼠标、全玩法、听感、异机、离线断网/平台上传或官方再分发支持验收；本轮后台启动不等于视觉验收。强制结束测试发生在 pending 已提交之后，不是写盘中断或断电测试。未将包称作 Maker 官方正式导出物。

## 状态与情况

- Blocked（代码同步及公开官方资料查证已完成，未找到适用于当前 Maker 工程的原生导出方法）。用户要求拉取最新代码，并按所附“Tap 打包规范”生成 Android APK 和 Windows 游戏包；未要求上架。
- 当前目录 `D:/taptap/To-the-Human-World-bgm`，分支 `feat/brewing-bgm`，本轮起点 `739896c`。
- 最新 fetch 后 GitHub 与 Maker main 均为 `e4621ef`，包含新手引导与入场演出更新。可快进，现有五个未提交路径与上游更新不重叠。
- 保留本地默认音量 60% 相关修改及此前同步记录；不清档、不清理工作区、不改应用身份或签名。
- 图中要求：APK 为可安装正式包，包名一致，VersionCode > 0 且不低于线上版本，签名与历史 APK 一致；Windows 为 .zip/.7z、单包不超过 2 GB，包含 .exe 并保持资源相对路径。
- 当前 Maker MCP 0.0.36 绑定、认证、Git、Python、LSP 均 ready；提示有 0.0.37 更新，未擅自升级。当前暴露的构建工具为提交构建/远端 Web 预览，尚未发现 native APK / Windows 导出工具或参数。

## 实施措施

1. 备份未提交文件与哈希；快进到已核对 main；核对本地改动完整保留。
2. 核查当前安装的官方 Maker CLI、工作流文档、工程构建入口，确定可支持的原生打包方式。
3. 若存在正式打包入口，使用同一代码快照生成两端包；核对 APK 元数据、签名，Windows 启动入口、依赖、压缩结构及大小。
4. 如缺少原生导出能力、正式宿主或签名配置，明确记录具体缺口，不把预览 Runtime 或 manifest 压缩包冒充正式包。
5. 用户追加要求主动查证官方方法：核对 Maker 官网、官方 taptap/instant-games-open-mcp 仓库与最新发行包；独立研究代理只读查证，结论统一归入本记录。发现适用导出方法后继续实际打包，不以旧版本未找到入口推断所有版本不支持。

## 影响文件树

```text
scripts/actions/2026-10-18-native-package-delivery.md  本轮行动、证据与交付状态
上游 main 变更                                      以 Git 快进同步
D:/taptap/.sync-backups/20261018-native-package/       本地改动备份及哈希，仓库外
```

## 自检方法

- Git 提交、祖先关系、上游路径与未提交路径交集；同步前后 SHA-256。
- 官方工具/CLI 能力检查与工程原生构建文件检查。
- 包体生成后检查实际文件内容、元数据与 SHA-256；安装/启动验证单列，不由文件存在推定通过。

## 自检结果

- fetch 两端成功；main 一致为 e4621ef；未提交路径无重叠。
- 工程未找到 Android Gradle 工程、APK、签名库或独立 exe 构建入口。当前 CLI 帮助未列出 APK/Windows export 命令。
- 同步完成：`git merge --ff-only origin/main` 成功，当前 feat/brewing-bgm、Maker main、GitHub main 均为 `e4621efe2f22f1d8023d07854503167245a6b25d`。
- 同步前六个本地文件（含本记录初稿）的 SHA-256 同步后全部一致。备份及 manifest 位于上述仓库外目录；本记录随后追加实际结果。未提交、未推送、未清理文件。
- 当前工具列表没有 Android/Windows 原生导出工具，maker_build_current_directory 参数没有平台、包名、VersionCode 或签名选项；CLI 帮助和已安装的官方本地工作流未提供对应导出步骤。未把一次普通远端 Web 构建视为 APK/Windows 打包。
- 对工程已跟踪文件核对：无 AndroidManifest.xml、Gradle、签名库、APK、CMakeLists.txt、Visual Studio 原生工程。项目发布字段只有 Maker 身份、方向与商店描述等，未发现 Android 原生包名、VersionCode、签名配置。该结论仅覆盖本机工程和当前暴露工具，不断言 Maker 所有后台都不支持原生导出。
- APK：未生成。除官方原生宿主/导出能力外，还须核对项目正式包名、历史签名及线上 VersionCode；未创建替代签名、猜测包名或修改身份。
- Windows：未生成。当前只有开发预览运行路径，未取得官方可分发独立运行包/导出入口；不能仅把预览 Runtime 与源码压缩后宣称满足图中正式包要求。
- 用户已明确回复：只有当前 Maker 项目，没有独立包导出入口。原生交付仍受阻，下一步需向 Maker 官方确认可用导出方案或取得可分发宿主；不是等待用户寻找已有入口。未主动联系第三方或上架。
- `git diff --check` 通过，无暂存内容和未解决冲突。官方 preview status 为 stopped、process_alive=false，未启动窗口。未运行 APK 安装、Windows 独立启动或真机验收。

## 可转给 Maker 官方支持的说明（未发送）

> 我们的《寄往人间》是 TapTap Maker / UrhoX / Lua 项目，Maker 项目 m_h4x3，App 955210。目前需要交付可安装的正式 Android APK，以及包含 exe 和完整运行资源的 Windows zip 包。当前只有 Maker 工程，现有 MCP 0.0.36、CLI 和后台未找到独立包导出入口。请确认该项目是否支持这两种独立分发方式，并提供官方导出流程；若需原生宿主工程，请提供可用版本、资源打包方式及运行时分发条件。Android 还需明确包名、VersionCode 和正式签名的配置方式。若暂不支持，请明确当前可交付的格式，便于我们调整发布方案。

确认官方方案前，不擅自把 Web 预览套壳，不改变引擎或重做项目；这些属于另行评估的开发范围。Maker 0.0.37 的更新提示本身不证明新增原生导出能力。

## 官方导出能力专项查证（2026-10-18）

结论：发现星火编辑器的官方 Windows/Android 独立导出教程，但没有找到当前 TapTap Maker / UrhoX / Lua 工程可直接使用的官方导出方法。该结论仅覆盖本次可核查的公开资料与发行包，不等同于官方宣布永久不支持。

| 第一手来源 | 实际证据与适用范围 |
| --- | --- |
| [Maker 官方工作流](https://github.com/taptap/instant-games-open-mcp/blob/main/docs/MAKER.md) | 公开的工作流是项目同步构建、本地/远端预览与测试二维码，没有找到 APK/Windows 游戏独立包导出步骤。插件安装 ZIP 与游戏包不同。 |
| [官方版本策略](https://raw.githubusercontent.com/taptap/instant-games-open-mcp/main/config/maker-version-policy.json) | latest 为 0.0.37，策略更新时间 2026-10-16T17:17:32.375Z。不是仅依据本机旧版判断。 |
| [npm 最新版本元数据](https://registry.npmjs.org/@taptap%2fmaker/latest)、[0.0.37 官方发行包](https://registry.npmjs.org/@taptap/maker/-/maker-0.0.37.tgz) | 实际下载至内存并只读检查，未安装、未执行。package/dist/maker.js 为 8,499,641 字节，已核对 CLI 帮助；build/qrcode/preview、canvas 素材 export 均不提供 APK/Windows 游戏包导出参数。对发行包脚本与文档搜索 APK/AAB/AndroidManifest/keystore/native game export 未找到相关能力。包体 SHA-256：7a3f7b4fb61a8d2948e1302f93b839fa05382c98799658be5fef2ff4237e6b48。 |
| [官方本地预览文档](https://github.com/taptap/instant-games-open-mcp/blob/main/docs/MAKER_LOCAL_PREVIEW.md) | Runtime 直读本地工程和受管理副本均属于开发预览；未找到将其作为正式可分发游戏宿主的导出流程。当前项目的宿主依赖仍未解决。 |
| [星火编辑器：如何将游戏独立导出为 PC 或 Android 包](https://doc.sce.xd.com/Manual/Developer/DevStage/IndependentExport/) | 确实提供“文件→导出为独立包→Windows/Android→远端构建→下载”。明确前提为星火编辑器第 13 版，且项目已在星火编辑器内发布。没有找到 Maker 工程可直接导入或接入该链路的官方证明，因此不执行新建星火项目或改绑操作。 |
| [官方 UrhoX 游戏合集](https://github.com/taptap/awesome-urhox-games) | 运行步骤仍为 TODO，引擎链接指向 xindong/UrhoX。合集的 MIT 许可不作为引擎分发许可依据。 |

- 正常本机网络下匿名请求 `https://github.com/xindong/UrhoX`、其 main/README.md 原文及 `https://api.github.com/repos/xindong/UrhoX`，三者实际返回 HTTP 404。只能据此确认本次未能公开取得源码，不断言其私有、永久关闭或不能授权使用。
- 未采信第三方“Maker 不支持导出”的旧帖作为最终依据；普通 TapTap APK 上传指南也不是 Maker 引擎导出方法。
- 本轮未升级工具、未启动预览、未触发远端提交构建、未联系第三方；APK 与 Windows 独立包仍未生成、安装或验收。
- 下一步的准确问题：请 Maker 官方确认项目 m_h4x3 / App 955210 能否接入上述星火独立导出链路；如果不兼容，是否提供 Maker 专用原生导出或可分发宿主。取得适用方法后继续本任务，不要求用户重复寻找不存在的后台入口。

## Android 引擎包查找与下载（2026-10-18，查证完成／下载 Blocked）

- 用户要求寻找合适的引擎包并下载到 download 文件夹。本轮按当前工作目录使用 `D:/taptap/download/`，开始时该目录不存在。
- 范围：核查官方 Android UrhoX SDK、宿主工程和公开发行包；只下载来源可核对的适用包，不安装、不执行下载脚本，不改变游戏、引擎或应用身份。
- 措施：并行查证官方文档、发行资产和官方安装器来源；逐一核对目标平台、接入接口与版本信息；找到候选后检查实际包内容、大小和 SHA-256；没有匹配包则如实记录具体缺口，不以其他引擎或桌面运行包替代。
- 实际影响路径：本行动记录承载来源和结果；新增 `D:/taptap/download/UrhoX-Android-查找结果.md` 说明本次没有取得 Android 引擎包，包含实际来源和 HTTP 结果，不进入 Git。没有新增引擎归档、SDK 或宿主工程，已有游戏文件保持不变。
- 自检方法：公开来源访问结果、发布文件名/平台、归档目录、Android 原生库和宿主构建文件、内容哈希。下载不等于编译或设备运行通过。
- 自检结果：查证完成，下载 Blocked。正常网络实测官方 Windows Runtime ZIP HEAD 200、application/zip、92,862,004 字节；它不是 Android 包，未下载。按该 URL 规则推测的 Android ZIP 与 build.json 均 404，两个推测路径不是官方公布的链接，不能据此声称所有 Android 发布路径不存在。
- 最新[官方安装器源码](https://raw.githubusercontent.com/taptap/instant-games-open-mcp/main/src/maker/preview/installerSource.ts)实际读取成功，平台表仅 linux/win32/darwin；[预览安装入口](https://raw.githubusercontent.com/taptap/instant-games-open-mcp/main/src/maker/preview/installation.ts)检查 darwin/win32。未发现可接入的 Android 下载项。
- 本机 Runtime build.json 的版本为 `20260923-1717-bf3316f`、构建仓库指向 `taptap/urhox`；该仓库 API 与 releases API 正常网络匿名访问均 404。首次沙箱请求被代理拒绝，已使用获准正常网络复核，未把代理故障当成仓库不存在。
- download 目录内容复核：只有上述查找记录（2,812 字节），没有引擎包；记录 SHA-256 为 `26cdfbeda89818f0df8aa9b3242d9110237250b68f8d9241d3a56bf490253441`。未安装、未启动游戏、未改变本机运行时、未提交或推送。


### Android 下载来源独立复核

2026-10-18，独立代理只读核查公开源和发布索引；未找到可以判定适用于本项目的 Android 引擎下载包，未下载或执行第三方二进制。

- [GitHub 官方公共仓库搜索：taptap + urho](https://api.github.com/search/repositories?q=urho+org%3Ataptap) 实际返回 `total_count=1`，仅 `taptap/awesome-urhox-games`；[xindong + urho](https://api.github.com/search/repositories?q=urho+org%3Axindong) 返回 `total_count=0`。这是匿名公开索引结果，不覆盖私有或未索引仓库。
- [Maven Central 查询 urhox](https://search.maven.org/solrsearch/select?q=urhox&rows=20&wt=json) 与 [Sonatype Central 查询 urhox](https://central.sonatype.com/solrsearch/select?q=urhox&rows=20&wt=json)，实际联网 GET 均返回 `response.numFound=0`。只说明这两个公开 Maven 索引中该关键词没有匹配发布物，不排除其他制品名称或私有 Maven 仓库。
- [官方 MCP 仓库 native 说明](https://github.com/taptap/instant-games-open-mcp/tree/main/native) 明确该目录为 TapTap Native Signer，即 Node.js 请求签名模块；不是 UrhoX Android 游戏引擎，不能拿其 native 构建替代 Android SDK。
- [官方 Maker 工作流](https://github.com/taptap/instant-games-open-mcp/blob/main/docs/MAKER.md) 仍未找到适用的 Android SDK 接入或下载步骤。[官方游戏合集](https://github.com/taptap/awesome-urhox-games) 是 Lua 游戏合集，通用运行步骤仍为 TODO，不是原生引擎发行包。
- 搜索命中的 [tidys/taptap-maker-urhox-runtime](https://github.com/tidys/taptap-maker-urhox-runtime) 自述个人本地预览方案，目录为 Windows EXE/DLL；其安装脚本列 linux/win32/darwin，没有 Android。它属于第三方排除项，不作为 Maker 官方支持证据，也不下载冒充所需包。
- 搜索命中的 [fredakilla/Urhox](https://github.com/fredakilla/Urhox) README 明确是 Urho3D 扩展库；没有证据证明兼容本项目的 Maker Lua 5.4、NanoVG、Yoga 与 SDK，已排除。未将同名搜索结果当成匹配引擎。

结果边界：公开搜索与下载来源复核完成；Android 依赖尚未取得，未运行编译/安装/设备验收。该结论不等同于 Maker 官方声明不支持 Android 原生发布。

## 联网测试 APK（2026-10-18，候选打包 Completed／Android 实测待验证）

- 用户已明确接受“先尝试联网测试 APK”。这是单独 Android WebView 测试应用，不等同于原生引擎独立导出，也不是正式上架包。
- 已发现本机 Android SDK 34、Build Tools 34.0.0、Java 22 和 Android 模拟器；未在 PATH 中不等于未安装。优先复用现有工具，不改系统配置或共享 SDK。
- 实施：确认现有游戏的实际网页入口；在 `D:/taptap/android-web-test/` 编写独立宿主和可复现构建脚本；使用独立测试包名、测试签名；生成到 `D:/taptap/download/`。不携带 Maker PAT、会话凭证或开发者登录态，不覆盖游戏存档。
- 宿主要求：HTTPS、JavaScript/DOM 存储、硬件加速、按当前横屏布局适配安全区；返回前提示，失败显示可重试界面；保留正常 WebView 数据，不在退出时清档。不以网页加载完成代替游戏启动验收。
- 验证：实际编译，APK 签名与包元数据检查；桌面后台浏览器验证官方入口及候选的同一 HTML。Android 安装/启动、触控、游戏存档恢复与稳定性尚未验证；本机系统镜像目录仅有未完成安装标记，没有可用 AVD，未启动模拟器窗口或操作其他设备。
- 文件范围：现有行动记录；新增 `D:/taptap/android-web-test/` 构建源码、测试证书与证据；新增 `D:/taptap/download/` APK 与使用说明。不得提交测试密钥，不改 Maker/Lua 工程。
- 自检结果：候选 APK 生成并通过编译、签名、对齐和结构检查；手机可玩性未确认。具体证据见本节末尾，不能作为正式 APK 上架验收。

### 网页运行器接入核查

- 用户明确没有浏览器试玩链接。匿名 GET 原 Maker 预览域名返回 302 到编辑页，CDN 游戏目录根返回 404；不能把跟随跳转后的 HTML 200 当作游戏可运行。
- 官方 CDN 中当前项目 `m_h4x3` 的 project/latest/manifest 可读取，远端版本 1.0.30；官方 Web Player `https://tapcode-sce.spark.xd.com/src/web/index.html` 返回 200，并提供 COOP/COEP 响应头。其公开脚本明确接受 `game_url`，引擎 stable 清单为 1.34.8。
- 已使用独立 Chrome headless 进程和新用户目录测试官方 Web Player；仅判定脚本、引擎、游戏启动，不作为视觉/触屏/真实游戏存档验收，不触碰现有浏览器和游戏窗口。不使用开发者登录凭证或模拟正式平台账号。
- 新增影响路径：`D:/taptap/android-web-test/probe_web.py` 后台浏览器检查；`evidence/` 官方清单、响应及本轮日志。第三方开源预览实现仅用于查找官方来源，没有安装或执行其工具；官方代码的实际响应与运行结果作为接入依据。
- 实测：独立 Chrome 完成 18 个引擎启动步骤，加载当前项目 main.lua，输出 `UrhoXRuntime: Game started successfully`，共享内存可用、OPFS 挂载成功。使用官方 `skip_login` 访客参数，userId 为 0；没有伪造 TapTap 登录或平台存档。该结果是桌面网页引擎/入口启动证据，不代表完整玩法或手机通过。
- Android 兼容措施：官方 Player 强制依赖 SharedArrayBuffer。采用 AndroidX WebKit 1.18.0-rc01 的公开 `CROSS_ORIGIN_ISOLATED_ALLOWLIST` 能力检查；支持时仅允许 APK 自有虚拟 HTTPS origin，配套 Document-Isolation-Policy。固定游戏入口，禁用任意地址浏览；不支持时明确说明设备 WebView 缺少能力，提供单独浏览器测试入口（存档隔离，不宣称 APK 内运行成功）。这是 RC 支持库的兼容性候选，真机结果未定。
- 重新核对的库最低 compileSdk=33、minSdk=24，本机 SDK 34 满足；无需升级全局 SDK。GeckoView 仅查证元数据，没有下载或使用其引擎。

### 联网候选实际产物与证据

- APK：`D:/taptap/download/ToTheHumanWorld-online-test-20261018T130744Z.apk`，1,060,074 字节，SHA-256 `22ef8812e7b3cd6bf15a4e1a5ddc4d0080c0916298098cc058105ee82eddcd2b`。说明为同目录 `ToTheHumanWorld-online-test-说明.md`。包内不包含完整游戏/原生 UrhoX，首次运行需联网下载资源。
- 包名 `cn.tothehumanworld.webtest`，VersionCode 1，minSdk 26 / targetSdk 34，只有 INTERNET 权限，横屏。独立测试签名，不能冒充原应用历史签名或正式上架包。可调试候选；未安装、未上传、未发布。
- 构建：`python D:/taptap/android-web-test/build.py` 最终成功。证据目录 `build/20261018T130744Z/` 含 `build-result.json`、`signature-verification.txt`、`apk-metadata.txt`、`dex-build.txt`、`package-audit.json`。Java/DEX 编译成功，最终 D8 日志为空；APK v2/v3 签名验证、zipalign、38 项 ZIP CRC、交付文件 SHA-256、内嵌 HTML 与源码一致、敏感路径/密钥文件名排除检查通过。
- 构建失败记录：SDK 自带 D8 8.2.2-dev 处理本次 javac 输出时发生内部空指针异常；改用 Google 官方稳定 R8/D8 9.5.26 后通过。一次下载连接超时后同官方域名重试成功；没有更新全局 SDK。曾下载最新 alpha 编译器作来源核对，但最终没有使用。依赖与编译器均核对官方 SHA-1 并记录 SHA-256；下载脚本固定版本。依赖许可证和来源 NOTICE 随包保留。
- 网页验证一：`evidence/browser-20261018-205859/events.json` 为官方 URL；引擎启动、main.lua 加载、OPFS 挂载成功。网页验证二：`evidence/browser-20261018-210729/events.json`、`evidence/virtual-player-console.txt` 为 APK 同一 HTML 和虚拟 HTTPS origin/隔离响应头，通过 CDP 响应拦截模拟宿主，最终出现 `=== 寄往人间 启动完成（第 1 天）===`。这是桌面 Chrome 后台启动检查；未把它视为 Android WebView 实测、触控验收或完整存档恢复。
- 两次后台进程均由本轮持有进程句柄管理并已关闭；未开前台窗口、移动鼠标或控制 Maker preview。未改变游戏 Lua、配置、美术、绑定或共享引擎；工作区原有改动保留，HEAD 仍为 e4621ef。`git diff --check` 通过（现有 LF/CRLF 提示保留），未提交、推送或远端构建。
- 剩余：手机安装及实际 WebView 能力检查；是否进入标题/桌前、触控/长信/安全区、四种进度下退出恢复、重复发货幂等。访客 userId=0，无 TapTap 账号同步。外部浏览器备用测试与 APK 内存档独立，不能混作同一退出恢复结果。

## Android 沉浸式全屏修订（2026-10-18，实现与候选打包 Completed／手机验收待验证）

- 情况与授权：用户提供手机截图，旧测试 APK 已在其手机显示游戏场景，同时顶部宿主工具栏及底部深绿系统导航区域占用画面。用户明确要求沉浸式全屏、隐藏常驻测试栏、触屏菜单内放重试/退出、保留安全区并重新打包。截图只证明该设备已显示游戏场景，不补认退出恢复、结算或完整触控验收。
- 措施：删除原生常驻状态/按钮/进度横栏；游戏区域使用全屏窗口。API 30+ 采用 WindowInsetsController，低版本采用 immersive-sticky；系统栏可由边缘滑动临时唤回。按系统报告的挖孔/刘海、手势和输入法边距保护内容与菜单按钮，不固定保留整条导航栏高度。提供右侧中部的触屏菜单按钮，菜单内继续、重试、说明、退出，重试/退出再确认，取消不加载或结算游戏。回到前台与关闭弹窗后恢复沉浸式状态。
- 交付身份：保持原包名、签名、虚拟 HTTPS origin、游戏 URL 和网页存储；VersionCode 提升至 2。同签名覆盖安装所需条件逐项核对，不能用重新安装/清数据绕过升级。首次 APK 与原宿主源码快照保留在隔离目录备份。
- 影响树：本行动记录；`D:/taptap/android-web-test/src/cn/tothehumanworld/webtest/MainActivity.java` 宿主交互；新增同目录 `ImmersiveWindow.java` 全屏/安全区适配；`AndroidManifest.xml` 版本与启动主题；`res/values/styles.xml` 无栏黑底启动主题；`build.py` 与 `config.json` 加入升级签名保护和真实版本记录；`README.md` 与 download 使用说明；`build/`、`evidence/` 和新 APK。游戏 Lua、UI 组件、内容、美术、Maker 绑定、全局工具不修改，不提交推送。
- 验证方法：实际 Java/DEX/aapt 编译、签名/zipalign/ZIP 检查；对比新旧包名、VersionCode、签名指纹和内嵌网页/地址一致；检查新旧 API 分支、菜单触屏及返回/取消路径、无主动清档或结算调用。无可用 Android AVD，不能把编译或桌面网页检查当作本轮手机全屏效果验收；新版手机覆盖安装、边缘滑动、菜单触控、旋转和退出恢复待实机。
- 依据：[Android 沉浸式模式](https://developer.android.com/develop/ui/views/layout/immersive)、[边缘布局与安全区](https://developer.android.com/develop/ui/views/layout/edge-to-edge)。
- 自检结果：Java/DEX/aapt 编译、APK v2/v3 签名、zipalign、ZIP CRC、交付哈希检查通过；新 APK 包名与 v1 一致，VersionCode 2 / VersionName 0.2-immersive，签名指纹与 v1 相同，权限未变。内嵌配置和 player.html 与 v1 字节一致，新的全屏适配类已进入 DEX。安全区与菜单路径经源码和编译后字节码检查；未运行 Android UI 测试，不能把这些结果当作真机全屏或恢复验收。
- 产物：`D:/taptap/download/ToTheHumanWorld-online-test-v2-20261018T132836Z.apk`，1,060,074 字节；SHA-256 `9ac8e89ec1471970b0988833be2e498a775fe27743e4a368d20ad6e60ec64590`。配套 `ToTheHumanWorld-online-test-v2-说明.md`。v1 APK 保留；请覆盖安装，不先卸载或清除数据。
- 证据：`D:/taptap/android-web-test/build/20261018T132836Z/` 中 `build-result.json`、`upgrade-audit.json`、`signature-verification.txt`、`apk-metadata.txt`、`dex-build.txt`、`compiled-ui-inspection.txt`；控制台日志为 `evidence/apk-immersive-build-console.txt`。D8 本次成功且日志为空。升级审核中的 `android_v2_install_and_ui_tested=false` 明确保留。
- 回退与身份：修改前源码快照位于 `D:/taptap/android-web-test/backups/immersive-before-20261018T132559Z/`，未把密钥复制进快照。构建脚本新增保护：升级版若原密钥缺失或签名指纹不匹配则停止，不自动换签名。保留旧包和源码用于后续回退构建，不要求手机卸载降级。
- 实际交互：右侧中部 48dp 菜单按钮位于安全内容区域内，错误提示时仍可点；菜单取消/继续、关闭说明、恢复窗口焦点和横屏配置变化均不主动重新加载页面。重试与退出二次确认，系统返回键打开菜单。本轮未加入游戏存档、结算或清除网页数据调用。
- 并行边界：本轮开始及收尾核对仓库 HEAD 为 9eb6942，已由其他工作更新；未拉取、提交、推送或启动前台窗口，未覆盖现有音乐设置等修改。构建记录沿用的参考 HEAD e4621ef、远端观察版本 1.0.30 和桌面启动结果属于 v1 接入阶段证据，不代表本轮重新同步或验收了远端游戏。
- 剩余：v2 手机覆盖安装、全屏与临时系统栏行为、菜单触控/遮挡、安全区和横屏翻转，以及同一访客存档的退出恢复与重复结算。手机截图确认的是 v1 游戏画面，未将其替代 v2 或存档验收。
