# 埃利亚斯确认稿提交协作分支

## 状态与情况

- 进行中。用户已授权“提交推送分支”，目标为既有 GitHub `fengyycon`；起点 `558aa099e2bb8b965ba5c9b33684960dde7ef8d1`，与远端分支一致。
- 按项目规则先调用 Maker 官方提交入口，因 `branch_not_allowed` 在提交前停止，没有提交、推送或构建。本轮按用户明确的分支交付范围推送 GitHub，不切换、合并或发布 main。
- 保留队友主线设计文档与未跟踪的本地预览记录，不纳入提交。

## 实施措施

1. 核对本线程埃利亚斯文案与运行接入的差异、归档及验证证据。
2. 将文案检查脚本的加粗断言同步为整句心愿；保留现有运行六词的独立断言，不调整游戏规则或词库。
3. 验证后只暂存明确的本线程文件，提交并推送 GitHub fengyycon，核对远端提交号。

## 影响文件树

- `docs/文案/README.md`、`开场与首封来信_定稿_v01.md`、`普通订单/首单_埃利亚斯_后续定稿_v01.md`：已确认文字与当前剪词待定说明。
- `scripts/data/{content,followup,letters,stage1}.lua`、`scripts/systems/{Narrative,OrderAudit}.lua`、`scripts/debug/NarrativeTest.lua`：此前已授权且验证的文案接入与旧存档兼容，本轮不再改 Lua。
- `scripts/debug/check_elias_copy.py`：只同步文档加粗检查。
- `docs/actions/2026-10-04-elias-user-copy-replacement.md`、`docs/actions/2026-10-05-elias-wish-format.md`、`scripts/actions/2026-10-04-elias-approved-copy.md`、`scripts/actions/2026-10-04-elias-runtime-copy.md`：此前文案替换、撤销、接入与标注的行动记录。
- 本文件：提交范围与验证记录。

## 自检方式

- 运行 `python -X utf8 -B scripts/debug/check_elias_copy.py`，检查来信、六个既有运行词源、七版后续及旧存档兼容。
- 核对已完成的 Lua 验证记录及未发生新的 Lua 修改；本轮不重复启动预览或远端构建。
- 暂存差异检查、明确文件清单及 GitHub 远端分支提交号核对。

## 自检结果

- Maker 提交前拒绝非 main 分支，未改变代码提交状态。
- 首次受限网络无法连接本机代理；受审执行后 `git ls-remote --heads github fengyycon` 成功，远端为上述起点。
- `python -X utf8 -B scripts/debug/check_elias_copy.py`：3 项通过，含首信全文、既有六词来源、七版实际后续、十组旧稿存档恢复及伪造拒绝。
- Lua 未新增修改；沿用此前接入记录的 B2 212／B4 339／B5 373／Story 1265 项通过及完整 LSP 0 Error／0 Warning／0 Hint，不声称本轮重跑这些检查。
- 提交与远端回执待核对。
