# d584352 美术包整合到共享 main 玩法

## Status and situation
Completed（美术整合及记录收尾；不代表全部交互验收通过）。已完成资源导入、加载/灯光/点击区域适配、静态检查和 Windows 完整画面观察。用户随后要求停止代理测试并自行验收，八入口和业务流程的真实鼠标验收未完成。2026-10-15 用户另行授权提交剩余记录并正常推送到 integration/3d-main-20261014；不切换分支、不合并或更新 main、不继续测试。

- 实际仓库：D:\taptap\D3-cloud-d00aca9\D3-github-cloud-3d-d00aca9。
- 实际分支：integration/3d-main-20261014。
- 修改前 HEAD：135334dc997023a1bbbc35c1b994364a24504c3a；无后续提交，工作区与索引干净。未发现 Git 写入锁；本机进程命令行查询被系统拒绝，不能据此声称已读取其他聊天的任务状态。后续每阶段提交前复核状态与 HEAD，发现外来修改即保留并协调。
- 现行玩法依据：scripts/前端接入接口手册.md；3D 宿主经 Bootstrap 使用共享 core/data/systems/ui.PlayModel、ordinary-release-v2/schema 4 和 MemoryStorage。保留 135334d 的全部共享玩法接入及 main 合并、开发计划、接口文档与清理成果。
- 上轮外层清理没有仓库源码改动，已在仓库外记录并验证；本次初始提交保存本基线说明，不伪称存在待提交源码。
- 完整包来自 C:\Users\YINGYI\Downloads\2，11 个分块及恢复工具 ZIP 已找到；版本 d584352a8e5cd0a776f91b41e1f3d7f7e7a6d35d。预期整包 194958529 字节，SHA256 d18cf2d3435bf3fae3cda06f3be64ae4dbd29a3b8916ed98302b8a121c4a85e1。
- 参考包已独立恢复到 D:\taptap\D3-visual-d584352-reference；未写 Downloads、未解压覆盖仓库、未使用旧增量包。
- 当前 .runtime-windows、.windows-runs、.tmp 是本机忽略数据；源分块、恢复目录、运行器、测试进度、Blender 源工程不提交。

## Implementation measures
1. 仅提交本基线行动记录，保留当前代码检查点。若出现新未提交改动，先在仓库外完整备份并核验，不能混入本次暂存。
2. 按已阅读的恢复脚本安全路径、分块哈希、整包 SHA256、ZIP CRC、项目清单验证逻辑，在新目录恢复完整包。
3. 比较本地、云端共同候选基线与完整包；写出精确新增/替换/删除清单与理由，不以包内缺失为删除依据。
4. 分阶段导入最新模型/贴图/位置/材质/灯光元数据及资源清单。引用检查通过后仅暂存资源与相关记录，保存资源提交；未适配加载前不宣称运行通过。
5. 逐项合并场景加载、灯光和点击适配，保留本地共享玩法装配/状态/UI。按原有八入口契约同步点击区域，保持包内确认的座钟、台灯、四原料构图，不另做美术设计。
6. 已检查共享玩法、Lua/资源/点击契约、Windows 启动器，并用本机官方运行器启动当前仓库、观察完整画面。存档固定为隔离内存槽。用户要求自行测试后停止代理输入，真实鼠标交互不列为通过。
7. 按真实完成情况记录静态、启动、画面与鼠标验证，保存第二阶段提交及剩余整合记录。仅正常推送指定 integration 分支；不重新运行测试或操作游戏窗口。

## Affected file tree
- docs/actions/2026-10-15-d584352-visual-integration.md：本轮唯一仓库行动记录与分阶段结果。
- docs/evidence/d584352-integration/：精确导入清单、资源/代码检查及必要验收证据（不引入旧连续截图）。
- assets/v035-full：候选模型、贴图、场景元数据及哈希清单；153 个精确资源路径与原因见 import-plan.json。
- scripts/v035/lab35：FullSceneHost.lua、HarborLighting.lua、KenneyCauldronFire.lua、MeshContract.lua、NativeGeometry.lua、ProbeAdapter.lua、SelectedLampLighting.lua、SemanticOcclusion.lua；仅合并必要美术/加载/灯光/点击适配。
- tools/check_d584352_assets.py、tools/check_d584352_runtime.py、tools/audit_v035_resources.py：资源与加载适配检查；原有共享玩法检查继续复用。
- README.md、docs/WINDOWS-RUN.md：已同步当前美术版本、启动入口及分层验证依据。
- scripts/core、scripts/data、scripts/systems、scripts/ui 与根目录 v035：以本地为准；不被完整包的旧玩法副本覆盖。
- D:\taptap\D3-visual-d584352-reference：仓库外只读参考；不作为运行验收入口。

## Self-verification method
分块/ZIP/项目清单 SHA256 与 CRC；三方文件比较；资源引用与清单；现有 shared main 344 项隔离检查及相关变更测试；Lua 语法；Git 精确暂存与 diff --check；官方启动器 --check；Windows 窗口/日志/截图/加载时间/内存与实际输入记录。原生画面、真实鼠标和脚本替身检查分层报告。

## Self-verification results
阶段 0 已完成：基线记录提交 d8689b9ecea6d3ab898f7cf62daaa388d090fbb6，源码仍为 135334d。

- 11 个分块、194958529 字节完整 ZIP 的 SHA256 及所有 ZIP 成员 CRC 通过；963 个项目文件逐项匹配包内索引。包装共 967 文件，不含 .git。
- 恢复工具误写索引名“项目文件清单.json”，实际为“项目文件索引.json”；按实际索引核验，原下载包未修改。恢复到仓库外 D:\taptap\D3-visual-d584352-reference。
- 三方比较 d00aca9 / 本地 / d584352：Bootstrap、AppView、Controller、HomeView、Panels 的包内代码等于旧 d00aca9，本地共享 main 版本全部保留。FullSceneHost 双方都有修改，已逐项合并。其他 7 个美术加载相关文件只有云端变化。
- 精确计划见 [import-plan.json](../evidence/d584352-integration/import-plan.json)：资源新增 102、替换 36、删除 15。删除项均为旧场景显式移除/替换且不在新网格目录和哈希清单中的网格，无活跃代码直接引用；不是按完整包缺失任意删本地文件。
- 57 个将修改/删除的既有文件已完整备份到仓库外 docs/actions/d584352-restore/local-before 并逐项核验。没有用户未提交改动混入。
- 只导入 assets/v035-full 的已确认资源，不重新引入 assets/Textures、v035-probe、scripts/lab、旧 LSP、旧交付包或历史启动器。主相机相同，档案位置/代理与书本、药炉的可见模型归属随包同步，八入口用途不变。
- 包内最新验收 JSON 记录有截图，但对应最新全屋 PNG 未包含在包中；现有参考图不能冒充 d584352 截图。本地截图按实际包内几何与用户目标检查，逐像素对照待原图。
- 阶段 1 资源导入与静态检查通过：251 项资源 SHA256、138 个网格、3,214,558 三角形、2,643,579 顶点、88 个贴图引用、4 个材质 technique XML 和 8 个稳定入口映射均有效。座钟宽 0.60m、底面 Z=2.4205，台灯底面 Z=1.852，符合确认摆放。完整结果见 resource-checks.json。
- 资源文件按包内字节导入；将 manifest 的过时 suggestedExtractionPath 修正为 assets/v035-full/。首次 git diff --check 检出包内 4 个 technique XML 和 selected-fire/LICENSE.txt 的行尾空白，已仅清除这些空白并更新对应 SHA256；许可正文、材质参数、构图和模型不变。
- 整合提交中的 scripts/core、data、systems、ui、根目录 v035、urhox-libs 与基线无差异。阶段 1 仅是资源提交，不能单独用未适配的旧加载器作运行验收；阶段 2 及 Windows 观察结果见下文。
- 阶段 1 已保存为 8e47814e1f5871a594724d84f54a6a318632bd5e。首次重新暂存时，已入索引的删除路径不能再次 git add，已仅重暂存仍存在的明确文件，原删除项保留在索引；最终精确核对 158 个变更路径后正常提交，没有 reset/clean。
- 阶段 2 已逐项合入 8 个 3D 美术模块：FullSceneHost 保留本地 main 字体/装配/业务日志；其他 7 文件合入只有云端发生的美术变化。新增局部台灯、火焰、线性 RMA/发光贴图与透明材质；仅火焰绘制层排除拾取，新的档案/书本/药炉使用场景内明确可见模型归属。
- `tools/check_d584352_runtime.py` 通过：183 个可达 Lua 文件编译、88 个贴图解码、新旧场景材料契约、4 类无效材料拒绝、火焰构造失败清理与幂等停止。原生对象为明确替身，不宣称引擎渲染通过。
- `tools/check_3d_main_integration.py` 原有 344 项断言全部通过，覆盖实际共享 schema 4、8 入口回调、独立内存槽、捕捞/读信/剪词、购物扣款、家具报价、药效预览、返回主页与跨天幂等。没有 OS 鼠标输入。
- 阶段 2 已保存为 914da43e8e4d7e60d128511c4fb39915c8f99a5d，保护的共享玩法路径仍与 135334d 一致。
- Windows 官方启动器预检通过，使用已安装 20260923-1717-bf3316f / PE 1.32.14.0，实际入口为当前仓库 scripts/main.lua。沙箱首轮 PID 35096 在非交互桌面加载完成（128.022 秒），但无法获得真实桌面窗口，未点击、不算画面通过；已关闭该精确 PID 后在交互桌面启动 PID 29916，成功捕获加载画面。没有更改系统执行策略或安全软件。
- Day / Dusk 环境资源、themis_x64.dll 缺失日志与此前 WINDOWS-RUN.md 已记载的问题一致；不把历史环境警告说成本次新引入错误。完整房间可见，但这些缺失项对所有效果的影响尚未确认。
- 交互桌面运行 PID 29916 已实际显示完整房间，1170×658，Direct3D 11 / RTX 4060 Laptop GPU。日志记录完整加载 102.846 秒；已经读取和观察真实窗口截图，未以 READY 代替画面检查。座钟位于第三层架子四原料右侧，台灯在炉子与档案之间并照向信纸；窗景、四原料、档案和新模型可见，桌面 DAY/金币瓶已移除，金币 30 / 第 1 天及提示、结束当天 HUD 可见。
- 本机截图为 `.windows-runs/20261015-153242-784834/01-home.png`，同目录保留 launch.json、stdout.log、stderr.log、os-events.jsonl 和加载截图。该目录受 Git 忽略，仅本机留存，不随记录提交。20 秒内存采样已保存；当时进程工作集峰值 2,355,822,592 字节。引擎 Update FPS 日志不等于 GPU profiler 或完整操作流畅度验收。
- 用户要求“我自己测试就好，你可以停下来”后，代理停止后续输入；排队的提示按钮点击被自动审批拦截，未执行。八入口、提示气泡、返回主页、购买扣金币、结束当天和漂流瓶捕捞阅读的 OS 点击验收均未完成；此前 344 项 headless 回归不能替代这些项目。关闭窗口或重启测试也未继续执行。
- 本次收尾前实际 HEAD 为 914da43e8e4d7e60d128511c4fb39915c8f99a5d，仅本记录存在未提交修改，索引为空；修改前记录已在仓库外完整备份并核验。用户授权本次提交与指定分支 push，不合并 main，不新增测试。远端查询确认目标分支原为 e3c958964eb930a3434da5b64cdf6567ef8374b6；推送结果以实际远端提交核验为准。
- 美术修改前回退定位点：d8689b9ecea6d3ab898f7cf62daaa388d090fbb6；资源阶段：8e47814e1f5871a594724d84f54a6a318632bd5e；加载适配阶段：914da43e8e4d7e60d128511c4fb39915c8f99a5d。本轮未执行任何回退、历史重写或 main 合并。
