# 本机 Maker 持久预览实验

这是用户于 2026-10-04 授权的隔离本机修复，**不是 Maker 官方发布版修复**。只允许 Windows 上当前 `D:/taptap/To-the-Human-World` 单机工程显式启用；不改变服务环境、不提交或构建游戏。

## 结构和行为

- `patch.py` 校验当前 0.0.36 bundle 的 SHA256，再生成 `D:/taptap/.mpv/cli/dist/maker.js`、`candidate.patch` 和 `manifest.json`；原版安装文件不写入。固定版本变化则停止，不盲目替换新版本。
- `persistence.mjs` 为同一真实工程保留短缓存目录、随机访问 capability 和 loopback 端口。原生 File 直接写在这个运行目录，从未在停机时导出或重开时回填存档。
- 缓存位于 `D:/taptap/.mpv/data/<工程路径哈希>/cache`；身份文件位于其上层。该文件含本地资源服务访问 capability，不能公开、提交或发给工单。端口被占用时明确失败，不杀其他进程或分配另一端口。
- 候选保留整个实验资源缓存（其中含 savedata），尚未实现资源缓存单独回收。避免超长路径而采用短根目录。保留官方 Host/Origin 校验、资源白名单、关闭服务及进程所有权校验。
- 关闭开关时沿用官方临时缓存行为。项目准备仍依赖官方资源索引网络；下载失败不会退回旧产物，也不会清实验档。

## 生成与检查（PowerShell）

```powershell
Set-Location D:/taptap/To-the-Human-World
python -X utf8 -B scripts/debug/maker-preview-lab/patch.py
& D:/node.js/node.exe --check D:/taptap/.mpv/cli/dist/maker.js
& D:/node.js/node.exe scripts/debug/maker-preview-lab/test.mjs
```

`test.mjs --original` 预期失败于存档存续断言，是原版红色对照；无参数候选 11 项通过。测试文件位于 `.mpv/test-*`，不是游戏存档，不清理整个 `.mpv`。

## 显式启动验收

先查 status，确认没有他人运行的会话；按本轮授权启动。若验收当前证据槽，将 `scripts/debug/B6RunRequest.lua` 的 `off` 显式改为 `b6_persist_20261004_a`，该槽已经确认三单（270金币），**不要当新档或清掉它**。需要另一条路线时另选唯一 `b6_*` 槽；已有幂等探针只绑定本次证据槽。

```powershell
$env:MAKER_PREVIEW_PERSISTENCE_LAB='1'
& D:/node.js/node.exe D:/taptap/.mpv/cli/dist/maker.js preview run --target-dir D:/taptap/To-the-Human-World --json
```

窗口关闭或 CLI 正常停止后保留实验档。另一个终端可用同一候选 `preview status/logs/check/stop --target-dir ... --json`。无需更改全局 PATH/MCP 配置。`preview run` 默认 10 分钟上限；本次退出验收均在上限前调用该窗口的 CloseMainWindow，等价于正常关窗，未用进程名强杀。

`evidence.py <label>` 只读当前原生提交标记、完整性校验、启动原生 Lua JSONL 和快照。**按提交 generation 选银行，不能按业务 revision 选银行**。CLI 会脱敏游戏 tokenId，可能截断长 JSON，因此启动证据读当前轮唯一原生 Lua 日志，不把截断输出当作完整快照。

`verify_evidence.py` 检查已留存本轮证据；不会启动或模拟游戏。它证明这份证据，不代表未来任意版本再次运行通过。

`verify_reset_evidence.py` 检查后续真实窗口的 pending 重开重置、三单累计、双来源同名卡及最终重开证据，见[续测记录](../../actions/2026-10-04-b6-reset-and-desktop-acceptance.md)。旧证据标签保留，不用当前三单存档覆盖首轮证据。

## 回退

1. 用候选 `preview stop` 或关闭本项目窗口，并确认 process_alive=false。
2. 恢复 B6RunRequest 为 `off`（本次交付已恢复）；若当前终端设置过开关，执行 `Remove-Item Env:MAKER_PREVIEW_PERSISTENCE_LAB -ErrorAction SilentlyContinue`。
3. 后续改用原来的 `taptap-maker`/Maker MCP 即完成回退，原版 bundle 始终未被覆盖。实验存档保留在 `.mpv`，不会自动进入原版临时预览或玩家默认档。

不要为了“回退”删除缓存或拷贝旧档。跨机迁移、不同登录用户、移动端、强杀/断电、并发预览及缓存长期回收未在本轮验收。官方支持仍以 [Issue #568](https://github.com/taptap/instant-games-open-mcp/issues/568) 回复为准。

本次结果和实际文件责任见[行动记录](../../actions/2026-10-04-maker-preview-persistence-lab.md)。

## 原生写入故障验收

[故障验收记录](../../actions/2026-10-04-b6-native-save-failure.md)使用新槽 `b6_fault_20261004_a`，目前已确认1单/110金币，不当新档或清除。精确选用该槽时，底部“验收留证（只读）”记录内存快照、门禁和事件；off和其他槽不显示。不开启自动故障。

`fault_evidence.py collect <新标签>` 只读原生文件和本轮日志，需先点留证按钮，拒绝覆盖旧证据。`readonly snapshot <标签>` 或 `readonly commit <标签>` 仅临时将该槽下一写入银行的现存文件设只读，原属性先记入 `logs/b6-fault-lock.json`；不得操作其他槽。执行后必须用 `fault_evidence.py restore` 恢复，核对active=false，不要删恢复记录或删除文件。工具不能模拟提交不确定、短写、断电或磁盘满。

`verify_fault_evidence.py` 复核已留存的39项窗口故障证据，不重新操作Runtime。与前两轮比较器一样，只证明留存证据。验收结束已关窗、off、四次原属性全部恢复，旧三单槽未改。

## 提交读回不确定的窗口实验

`b6_uncertain_20261004_a`目前已确认1单/110金币，保留原档。只有明确选择该槽时，入口使用`B6UncertainStorage`包装原生EngineStorage；off和其他槽不变。实际所有写入仍由原生File完成，仅在pending时手动点击“启用读回故障”后，下一次提交标记成功写入的后续读取被注入异常。“解除故障”不解锁业务；仍须点击正式“重新读取原存档”对账。进程重开默认无故障。

用`fault_evidence.py collect <新标签> b6_uncertain_20261004_a`采集本槽，不支持给本槽改文件属性。`verify_uncertain_evidence.py`复核22项留存证据，见[窗口实验记录](../../actions/2026-10-04-b6-uncertain-recovery.md)。本实验不代表OS拒读/断电测试，不能与上一批原生只读属性故障混称。已解除开关、关窗并恢复off。
