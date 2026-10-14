# B6 关窗恢复后重置与桌面续测

## 状态与现场

状态：Completed（本批桌面续测完成，非 B6/A1～A19 全部完成）。用户在隔离 Maker 修复、三个退出点通过后指示“那就继续”。沿用 [上轮实验](2026-10-04-maker-preview-persistence-lab.md)，继续本机窗口验收，不改玩法、内容配置或云存档，不提交推送。

预览启动前已停止。分支 fengyycon，保留全部既有工作区改动，尤其 docs 下队友新增文案。使用同工程、原生用户 savedata/0、独立槽 b6_persist_20261004_a；已有第一单确认结果，不能清档或回填。正常跨天进入第二单，以检验重置是否保留之前的确认、剪词与库存。候选 Maker 位于 D:/taptap/.mpv，不覆盖原版安装。

## 实施措施

1. 保存续测前证据，显式启用已有独立槽；通过真实窗口正常跨天、收信、剪词和接单。
2. 第二单投料形成待确认，留存完整原生文件和窗口证据，正常关闭并重开，再操作重置。
3. 对照首次投料基准、已确认第一单、剪词与库存；正常重炼确认并继续第三单，检查实际单次扣卡与奖励。
4. 在本次窗口过程中检查按钮、滚动、来源区分与持续交互，严格区分桌面与手机、逻辑与视觉证据。
5. 结束后正常关窗并恢复 B6RunRequest=off，更新验收记录。

## 影响文件树

- scripts/actions/2026-10-04-b6-reset-and-desktop-acceptance.md：本轮事实及证据。
- scripts/debug/B6RunRequest.lua：临时选用已有独立槽，结束恢复 off。
- scripts/debug/maker-preview-lab/verify_reset_evidence.py：新增本轮原生快照比较器，只读游戏状态；结果输出到 logs。
- scripts/debug/maker-preview-lab/README.md：更新现有验收槽已确认三单的事实和复核入口。
- scripts/B6_窗口与退出恢复验收.md：增量窗口验收结果。
- scripts/README.md、scripts/本机实施计划_新内容联调与B6_2026-10-03.md：最新结果入口。
- logs/b6-persistent-reset-*、logs/b6-desktop-*：本机证据，不提交。

## 自验证方法

- 启动前后 preview status；实际窗口点击、滚动、CloseMainWindow；截图必须打开查看。
- evidence.py 读取当前原生日志、提交 generation 和完整性标记，禁止复制旧档到运行目录。
- 比较重开前后完整快照，重置后 live 与首次投料基准，确认后的金币、材料、词卡和已确认订单。
- 检查本轮 Lua 日志错误；实际窗口连续操作时间和观察结果据实记录。
- git diff --check，核对数据、入口与原版 Maker 未被本轮修改。

## 自验证结果

### 实际窗口与存档

同工程、原生用户 0、同槽 b6_persist_20261004_a，全程没有回填存档。沿用旧独立槽而未另开新槽，是为保留上轮第一单成果并验证后续重置；不改变槽身份来模拟恢复。

| 会话 | Runtime PID | 操作和结果 |
|---|---|---|
| fa29fe9a-5dc8-4384-88ae-5dbc295017e8 | 66888 | 110 金币/一单恢复；旧信剪笑；正常第2天打捞、剪手稳和抬头、接 N01；手稳+海盐+夜露形成 pending；跨天按钮禁用；正常关窗 |
| 007193e5-f8f3-4951-a42c-51602c94f29a | 3732 | 原 pending 完整恢复，Reset 后 live 完全等于首次投料前基准；重炼产生新 transactionId，药效/事实/后续/评分/消耗/奖励相同；确认 N01，再正常第4天接 N02，选诺拉来源笑+海盐+夜露确认；正常关窗 |
| 99a70f0f-e7de-42fa-822e-8fb706c5f12a | 66512 | 完整恢复三单结果；每单重复 Confirm 两次，共6次 alreadyConfirmed=true，0事件，状态及文件不变；正常关窗 |

- P：generation=16、revision=12，关窗前/关窗后/重开文件哈希与完整快照一致。Reset 后 generation=17，仍 revision=12；正式 live 与基准一致，配方和 pending 清空，订单与基准保留。第一单的归档与结果未变化。
- N01 确认 generation=19、190 金币；N02 确认 generation=28、revision=20、270 金币、deliveredOrders=3；材料海盐0、夜露1、灰烬草3、干花瓣3。两张笑分别显示“诺拉→已用于第3单”“埃利亚斯·沃德→可用”。
- 连续桌面交互：截图14至30为 2026-10-04 12:56:47～13:01:53（+08:00），306.36秒，覆盖恢复查看、重置、重新投料、确认、跨天、读信剪词、第三单及库存。客户区412×734；已逐张打开检查中文、滚动区及按钮，未见本轮布局异常或卡住。此证据是桌面观察，不能替代手机触控与安全区。
- [比较汇总](../../logs/b6-desktop-verification.json)、[重置后的窗口](../../logs/b6-desktop-15.png)、[同名卡选择](../../logs/b6-desktop-26.png)、[三单重开窗口](../../logs/b6-desktop-31.png)。原生快照分别为 logs/b6-persistent-reset-{baseline,p-before,p-closed,p-reopen,after,p-retry,n01-confirmed,n02-baseline,n02-pending,three-confirmed,three-closed,three-reopen,final-closed}.json。

### 检查命令与结果

- `python -X utf8 -B scripts/debug/maker-preview-lab/verify_reset_evidence.py`：24项证据断言通过，含三轮原生 Lua 日志无 ERROR/stack traceback。比较器首次把库存视图的 source 包装误用于平铺存档字段，KeyError；改为实际 sourceLetterInstanceId 后通过。这是采证脚本错误，没有修改游戏存档或玩法。
- 窗口剪词刷新会调整滚动位置，首次第二次点击实际又剪了抬头，未接单。`reset-accepted` 标签对应该剪词后快照，phase=false，**不作为接单基准**；真正接单证据为 `reset-baseline`（generation=14、phase=accepted）。额外抬头卡仍保留，不影响重置对照。
- 三次 `preview run` 总退出码均为1，既有 Cube/Day/DaySpecularHDR.dds 和 themis_x64.dll 资源错误仍在；存档与窗口专项成功不能表述为 CLI 全检查通过。
- 最终 `preview status`：stopped / process_alive=false。B6RunRequest 已恢复 off，没有保留玩法代码改动，未重跑与本轮无关的逻辑套件或 LSP；此前 LSP 通过记录不算本轮新增验证。
- 原安装的 self-runtime/npm 两份 Maker SHA256 均仍为 62deb6cd7adc3975d23ce5750be53116f02ef7b9b5b9d49e5ace44fbbc144652。候选本轮未改。`git diff --check` 通过，仅既有换行提示；本轮不写 docs、scripts/data、入口、运行配置，不提交推送。
- 最终核对5份更新文档的84个本地链接均存在，B6RunRequest=off，scripts/data 无差异。链接检查第一次内联命令因 PowerShell 引号传递导致 Python SyntaxError，改用 here-string 标准输入后通过；并非项目代码错误。

### 尚未验收

原版官方持久预览、手机、强杀/断电、真实窗口写盘故障注入、全部等级和全部 A1～A19 仍未完成。新文案强调/收取变体仍按独立契约与内容交接处理，不混入本轮。下一批优先补真实窗口保存失败提示与恢复路径；正式手机/官方入口另按设备与交付条件推进。
