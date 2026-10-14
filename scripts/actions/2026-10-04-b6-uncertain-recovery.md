# B6 提交结果不确定的窗口恢复

## 状态与现场

Completed（本批原生窗口＋定点读回异常注入完成，非物理磁盘故障或全部A18）。用户继续上一批下一步：提交成功但读回失败时的锁定、同槽恢复与幂等验收。应用 project-control-report / action-document，沿用本机隔离 Maker 候选；不提交推送、不改内容、云存档或原版工具。当前fengyycon，origin为GitHub，预览停止；保留现有改动。

本次使用全新独立槽 b6_uncertain_20261004_a。原生File负责实际全部写入；通过SaveSystem.New已提供的storage接口，仅在用户点击测试按钮后、下一次该槽.commit真实写入成功后，注入read异常。不是OS权限/硬盘读故障，不能声称磁盘满、短写、断电已验收。

## 实施措施

1. 增加严格限定槽的调试包装，默认未启用；只有pending时可手动启用，成功写入提交标记后阻止该标记读取，直到显式解除。其他读取、写入均委托EngineStorage。
2. 正常窗口操作生成首单pending；留存完整原生证据。
3. 点击确认，核对磁盘已提交、内存未应用、没有结算事件；界面锁定并提供读取原存档入口。检查直接公共接口和错槽恢复不能绕过锁定。
4. 故障未解除时点击恢复仍失败并保持锁定；解除故障后由真实恢复按钮读取同槽，安装完整已提交结果，不重放奖励通知。
5. 关窗重开，核对完整状态与重复确认无变化。恢复off，停止窗口，更新记录。

## 影响文件树

- scripts/debug/B6UncertainStorage.lua：新增，原生存储之上的定点读回异常注入及状态观察。
- scripts/main.lua：仅在精确实验槽使用该存储装配，正常off保持原SaveSystem。
- scripts/debug/B6FaultEvidence.lua、B6PersistenceProbe.lua：本轮槽诊断按钮、门禁探针与已有确认重试。
- scripts/debug/B6RunRequest.lua：临时选择新槽，最终off。
- scripts/debug/maker-preview-lab/fault_evidence.py：仅采证支持新槽；属性修改入口仍仅旧故障槽。
- scripts/debug/maker-preview-lab/verify_uncertain_evidence.py：本轮证据比较。
- scripts/B6_窗口与退出恢复验收.md、scripts/README.md、scripts/本机实施计划_新内容联调与B6_2026-10-03.md、scripts/debug/maker-preview-lab/README.md：结果及边界。
- logs/b6-uncertain-*：本机证据，不提交。

## 自验证方法

Lua指南与既有UI示例已完整阅读沿用，核对GameState/SaveSystem公共接口；LSP、B6既有按钮回归；只读采证对比磁盘generation/内存/事件；实际窗口截图及恢复点击；关窗重开及幂等探针；检查旧槽不变、off、stopped、链接和差异格式。

## 自验证结果

### 原生窗口实测

全程同项目、用户0、新独立槽b6_uncertain_20261004_a。通过实际打捞、读信、剪睡觉、接单、睡觉+海盐投料得到generation6/pending；诊断开关此前未启用。

1. 点击“启用读回故障”，再点击正式确认。原生File成功写入完整候选快照和generation7提交标记；外部只读采证通过长度/校验摘要并解码出110金币、1单、海盐2、睡觉卡消耗。包装器只拒绝该.commit的随后的两次读取，未替换写入或生成伪存档。
2. 协调器返回SAVE_COMMIT_UNCERTAIN / recovery_required；内存仍与原pending完整相同，CanMutate=false、所有写操作门禁关闭，事件计数与确认前完全相同。窗口[锁定提示与原档恢复按钮](../../logs/b6-uncertain-locked.png)已实际查看。
3. 测试按钮通过公共接口尝试NextDay/CutWord/Accept/Confirm，均STATE_LOCKED；Load另一槽被RECOVERY_SLOT_MISMATCH拒绝，内存与事件均不变。
4. 故障未解除时点击“重新读取原存档”：仍失败，返回SAVE_READ_FAILED，内存/磁盘/事件不变，继续锁定。[窗口](../../logs/b6-uncertain-reload-blocked.png)显示本次注入的诊断文本；这是测试错误内容，不把它记成正式文案验收通过。状态名称变为corrupt表示当前读取失败，不代表本次原生文件实际损坏，外部校验仍通过。
5. 点击“解除故障”只恢复介质可读性，不自行解锁或安装候选。再点击正式“重新读取原存档”，内存完整等于磁盘已提交结果，恢复可操作；只新增SaveLoaded一次，没有PotionDelivered/MoneyChanged等结算事件重放，也没有再写存档。[恢复画面](../../logs/b6-uncertain-recovered.png)、[消耗卡](../../logs/b6-uncertain-cards.png)。
6. 正常关窗重开：完整状态与文件哈希不变；两次同事务Confirm均alreadyConfirmed=true，0事件、状态不变；新进程故障开关默认未启用。[最终窗口](../../logs/b6-uncertain-reopened.png)。其他原生槽哈希不变。

主验收会话2ac7d354-f38f-47d6-9f26-1a00f9ba146e/PID34300（2026-10-04 15:35:52+08:00开始）；重开会话a7a073fd-dc73-4e66-8ad3-5f4279b80c92/PID32624（15:40:58+08:00开始），均正常CloseMainWindow退出。

### 检查结果

- `python -X utf8 -B scripts/debug/maker-preview-lab/verify_uncertain_evidence.py`：22项通过，[汇总](../../logs/b6-uncertain-verification.json)。比较原生磁盘、只读内存快照、事件、门禁、启动快照及旧槽；不是内存File替身测试。
- `python -X utf8 -B scripts/debug/run_b6.py`：170项既有按钮回归通过，含准备专项104项；原生窗口结果独立记录，未用回归替代窗口检查。
- LSP全目录0 Error/0 Warning/0 Hint，最终off后15:43:10仍通过；本轮无需修正玩法代码。入口仅为精确实验槽增加存储装配，默认off及其他槽保持原SaveSystem。
- 两次run及preview check仍因既有Cube/Day/DaySpecularHDR.dds、themis_x64.dll资源错误整体FAIL/1；本轮原生Lua日志没有未捕获异常堆栈。故障注入异常被正常处理，不把预期失败当作崩溃。
- 已解除故障、关窗、B6RunRequest=off，最终status stopped/process_alive=false。原版Maker与隔离候选SHA256均与上轮相同；未改其文件、项目配置、scripts/data或文案。
- `git diff --check`通过（既有LF/CRLF提示保留）。5份更新文档的100个本地链接均存在，off已核对；scripts/data和.project无差异，LSP诊断进程已停止。

### 边界与剩余工作

这补齐“原生已写盘＋指定读回异常”下的窗口锁定/同槽恢复/幂等证据。拒读发生在Lua存储包装层，**不是OS拒读、物理硬盘故障或断电复现**；不能泛化为所有I/O故障通过。未测试锁定期间强杀/断电、不同用户/手机或官方持久环境。

本轮不改已接受剧情与数值，也不推进尚未共同冻结的新稿字段。B6下一批可用现有配置补同主词三种结果、不同星级与失败条件的真实窗口对照；手机/正式美术/现场扩配置仍按各自交接和条件验收。
