# D3-LAB v03.5 完整场景离线接入与启动准备

2026-10-13。专用任务：`01a12c24-a725-712b-ba7d-df58430f5098`。本报告覆盖完整云端 v03.5 场景的本地导入、业务入口和启动准备，不代表原生验收或 A2 审查通过。

## 结论

**完整入口及接口适配已完成离线准备，可交给下一次单独授权的受控原生验证。原生尚未启动。** 打包后检查已通过。完整包只包含 Home 相机，Brew／Seaside 实际路线尚缺，不能声称三个镜头已通过。官方 Maker 受管理 prepare 对本完整包也尚未执行。

本轮修复了小尺寸有效三角面的错误拒绝，补充非有限叉积拒绝，未删除任何输入面。26 个法线材质接入已写入并通过 API 替身测试。物件 ID、业务逻辑及用户确认的物品归属保持一致；现在推进是为了验证完整场景能否在当前 UrhoX Runtime 内稳定载入，而不是继续停留于六网格探针。

## 入口与版本

- 工程：`D:\taptap\To-the-Human-World-3D-Lab`。
- 入口：`scripts/main.lua` -> `v035.lab35.FullSceneHost.Install`。
- 资源：`assets/v035-full`，150 个实际运行资源，316,959,873 字节，约 302.28 MiB；另有逐文件运行资源哈希索引。
- 配置：`resourcePrefix="v035-full"`、`flipV=false`、`maxLoadingSeconds=300`。
- 业务基线：main `1cd0cdbec06487a5c60f109d5fd477198cfc8846`；80 个固定业务/界面源码哈希未变。
- 历史保留：原 r1/r2、六网格探针资源、`probe-main-before-full.lua`、`native-stage-before-full.json` 和最早入口备份均保留。
- 正式 2D 工程只读。未更换绑定、安装软件、提交、推送或启动原生。

## 已确认的业务映射

| 3D 物件 | ID → target | 主线提示文字／功能 |
|---|---|---|
| 抽屉 | home.drawer → letters | 来信抽屉；已收来信列表 |
| 绿色本子 | home.journal → journal | 故事记录；故事、试做及当次配方历史 |
| 托盘 | home.tray → words | 分类词条；面板栏标题为词条栏 |
| 捞网 | home.net → seaside | 海边捕捞；导航不自动收信 |
| 扎起纸堆 | home.caseFile → case | 案件板 |
| 商船 | home.merchantShip → shop | 商队商店；真实余额和购买 |
| 信纸 | home.letterPaper → paper | 阅读信件；没有选中信件时先选信 |
| 炉子 | home.stove → brew | 炼药工作区；导航不自动熬制 |

用户已确认以上映射。所有提示气泡直接读取固定主线 LayoutManifest.label。没有新增“日记”或写信功能。

## 完成依据

| 检查 | 结论与证据 |
|---|---|
| 七分包与原始文件 | 7/7 ZIP 哈希、169/169 内部哈希通过；170 个源文件保留。`full-package-integrity.json` |
| 完整流式导入 | 第二轮进程退出码 0；90 网格、3,209,455 三角面、2,584,246 源顶点、10,790 源物件、8 入口；122.64 秒为离线替身运行时间。`full-package-check.json/.log` |
| 商船保留 | 完整保留源 `full_group_057_000`：4 顶点、2 三角面及原透明贴图。这是云端交付的贴图卡片，不是新增立体船模；用于 alpha 拾取的完整 Lua 几何仍保留。`full-staged-check.json` |
| 业务回归 | 152 项通过，包括真实购买、失败不扣款、阅读剪词、重复剪词、重开剪口、UI 阻挡、单一会话及内存存储隔离。`offline-v035.json/.log` |
| 文字与打包 | 8 项实际气泡文字与主线完全一致；107 个源 Lua、85 个生成 Lua 编译通过；250 条打包文件记录（含保留的旧探针），150 个完整运行资源哈希通过。实际入口 Install 注册通过，未调用 Start。`full-staged-check.json` |
| 材质资源 | 53 张使用中的 PNG 实际解码成功；26 个法线材质使用已核对的 PBRDiffNormal/PBRDiffNormalAlpha、线性 TU_NORMAL，在 Commit 前生成切线。缺失/失败切线 API 有回滚测试。`full-resource-audit.json` |

以上文件位于 `docs/evidence/v035-main-interface/`。离线 API 替身不证明 GPU 渲染、原生输入或画面流畅度。

## 尚待原生验证的风险与必须补齐项

1. **相机**：旧六网格探针曾发生原生投影失败。完整入口会测试原生相机候选基底、8 点投影及射线；未通过则显示警告并锁定场景交互。离线 Blender 投影匹配不能替代此结果。
2. **镜头路线**：完整包未提供 Brew／Seaside 相机；当前导航明确返回不可切换，不臆造已验证路线。之后须补足同一空间内的两个镜头和门洞路径并实际往返验证。
3. **法线**：本地文档具备 GenerateTangents，当前 Runtime 二进制是否暴露该 API、返回值和 UV/TBN 方向尚待验证。失败会中止载入并移除局部场景，不静默宣称成功。
4. **官方 prepare 与资源加载**：离线源包/路径通过；受管理 prepare 产物及 Runtime 资源读取未验证。必要准备继续使用官方流程，不能通过伪造身份或重新绑定绕过。
5. **前次退出**：仍没有证明具体崩溃原因的原生退出码或堆栈；此次必须保留独立会话、PID、日志和退出码。不得将工具断连当作游戏崩溃结论。

## 资源预估

预计发出 862 个 CustomGeometry 批次，9,628,365 个展开顶点。位置／法线／UV 约 293.83 MiB，额外切线约 34.84 MiB；顶点载荷合计 **328.67 MiB**。53 张纹理按 RGBA8、无 mipmap 计 **300 MiB**；仅这两项约 **628.67 MiB**。

实际内存另含 CPU/GPU 副本、索引、mipmap、阴影、引擎缓存和当前 JSON/Lua 对象，可能超过 1 GiB；上述是载荷估算，不是已测峰值。流式读取每次一份网格并释放普通 Lua 几何，但不会减少完整场景的原生常驻几何。FPS、帧耗时、设备适配仍未验证。

## 下一次单次受控验证方案（本次未执行）

1. 获得该次启动授权后，用官方 `preview status` 核实独立 Lab 会话及进程。已有不明会话、用户停止或权限不明时停止，不接管，不自动重启。
2. 只对 Lab 使用官方前台 `preview run`，显式指定现有 Runtime，`--duration-ms 600000 --json`。配置缺失由官方受管理 prepare 处理，不调用 init，不改绑定。环境继续限定 `TAPTAP_MAKER_HOME=Lab\.preview-home`，TEMP/TMP 为 `Lab\tools\tmp`。
3. 将完整 CLI stdout/stderr 落到新的证据目录。解析 `preview.started` 的 **session_id、runtime_pid、可执行文件、reload_id 和 started_at**；立即为该精确 PID 保留 Windows 只读进程句柄。不要按进程名或同一路径枚举结果认领旧会话。
4. 每秒记录该 PID 的存活、WorkingSet64、PrivateMemorySize64、CPU 时间及 UTC；退出时从已保留句柄读取 GetExitCodeProcess，分别记录 Runtime 原生退出码和 CLI 退出码。若无法取得句柄，明确记为无法取得，不能推断为 0。
5. 按同一会话保存官方 logs/status、prepare.log、supervisor.log 和本次 Runtime 日志。检查 `[V035 FULL PROGRESS]`、`SLOW_STEP`、`FRAME`、`CAMERA`、`READY` 或 `FAIL`。日志带载入墙钟时间、每步耗时、Lua 内存（可用时）、Update 均值/p95/最差值。
6. 核对实际画面后才判断载入成功；若取得帧图，必须验证 HWND 属于本次精确 PID，不移动窗口、不操作系统输入。没有原生像素时记为证据不足，不能用云端重建图代替。
7. Host 载入超过 300 秒在下一次可执行 Update 中明确失败并回滚；主线程完全阻塞时 Lua 不能自行抢占，依赖外部存活/内存/日志监测与官方前台会话的有界结束。只记录本次，失败不重试，不重启用户关闭的预览。

官方命令组成：`D:\node.js\node.exe` + `C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\dist\maker.js` + `preview run --target-dir D:\taptap\To-the-Human-World-3D-Lab --runtime D:\taptap\To-the-Human-World-3D-Lab\.runtime\UrhoXRuntime.exe --duration-ms 600000 --json`。该命令仅作为待授权方案，本轮未运行。

## 给主会话与 A2 的结论

**通过**：完整源资产离线导入、资源一致性、确认的业务映射、真实业务离线回归、隔离存储与入口打包。

**需修改／补齐**：两个缺失镜头及路线；原生验证发现的问题需按实际日志修复。

**证据不足**：完整场景原生画面、相机、切线、性能、真实点击、三种比例构图、手机表现。内存存储只证明会话内行为，不证明跨进程恢复。

当前待用户决定的映射问题：**无，已确认**。原生启动授权仍待主会话安排。可复用成果包括完整资产、导入器、稳定 ID／拾取适配、主线业务面板和存储隔离；继续 3D 的主要成本是原生投影/切线兼容、三镜头路线及性能治理。没有自动合入正式 2D，也没有最终审美接受结论。
