# 转头验证双端推送记录

## 状态与现场

- Blocked（Maker 分支授权待用户确认；GitHub 已完成）；用户本轮明确授权双端推送到对应分支，此前纠正过“只推送当前分支，不合并”。不将本轮解释为合并 main、强推或改应用绑定授权。
- 本地分支 fengyycon，HEAD c59c59044218e6be626edb86f66dc950f6943bd2；暂存区为空。其他窗口的文档、素材删除/新增和编辑器修改保留。
- 本次候选范围为 C-HOME-YAW-PROBE-20261012-r1-v01 的 11 个源码/行动文件、422 个证据文件和 delivery.json；433 项清单哈希逐一匹配，未检测到凭据模式。默认开发开关仍关闭。沿用刚完成的 0 Error Lua 诊断与已交付检查，本轮不修改实现。
- 只读远端核验：Maker 当前 main=9394938f13d95a08565681b06d836b0208f53bc0，未返回 fengyycon 分支；GitHub fengyycon/main 均为 d1b2d06cb31948a33b1e8d7bfbadb858550255af。GitHub 分支包含上次同步历史，位于当前本地 HEAD 之后。
- 沙箱首次 ls-remote 报 Windows SEC_E_NO_CREDENTIALS；在允许读取正常凭据上下文后，两个端点查询成功。未改代理、凭据或 Git 配置。

## 实施措施

1. 依据 project-control-report/action-document 记录范围；Maker 状态查询已确认原项目绑定健康。
2. 按项目规则先调用 Maker 官方提交工具，显式限定本轮文件；不得为了绕过分支限制切换/合并到 main。
3. 核实官方返回及远端历史。如无法在用户授权的分支边界内同步，给出具体阻碍和最小决定；不强推、不改写共享历史、不混入其他窗口工作。
4. 推送成功时分别读取两端具体分支 SHA；回执只保存在本地，不为归档再次触发远端构建。

## 影响文件树

- scripts/actions/2026-10-12-home-yaw-dual-push.md：本次操作记录。
- scripts/ui/landscape 下本轮转头源码/检查：仅提交已有交付，不再改实现。
- scripts/actions/2026-10-12-home-yaw-probe-r1.md 与 docs/验证/evidence/home-yaw-probe-r1/：对应交付记录与证据。
- 其他既有修改保持工作区原状，不广泛暂存。

## 验证方法

- 核对交付清单 SHA256、默认关闭开关、当前分支、空暂存区。
- Maker 官方状态与结果中的 failure_stage/code_submit_status/remote_build_status。
- 两端 git ls-remote 指定 refs/heads，核对快进关系及最终提交；main 不因本轮操作改变。

## 验证结果

- 自动审批拒绝 Maker 官方提交工具：不能证明会推至当前 fengyycon，可能写入用户未授权的 main；工具未获执行，不是远端构建失败。已向用户询问 Maker 分支选择，未切分支、未绕过拒绝。
- GitHub 仍在用户已授权范围内。其 fengyycon 的 d1b2d06 包含旧同步提交，是 c59c590 的后代；本轮 landscape 源码在这两个基线之间无差异。准备独立的 detached 工作树，以现有 GitHub 分支头为父提交，仅复制已核对的转头交付，新增普通提交后显式推送到 GitHub fengyycon。此步骤不写 Maker，不产生 merge，不改原工作区分支或文件。
- GitHub 完成：独立工作树 `D:/taptap/To-the-Human-World-yaw-push` 生成普通提交 `0f6c248c9f4b51797df5626867ecfd0fcb318fec`，唯一父提交 `d1b2d06cb31948a33b1e8d7bfbadb858550255af`。显式 434 文件清单与暂存区相同，没有新增 merge 提交。
- 已执行 `git push github HEAD:refs/heads/fengyycon`，返回 `d1b2d06..0f6c248 HEAD -> fengyycon`。随后 `git ls-remote github refs/heads/fengyycon refs/heads/main` 核实 fengyycon=`0f6c248...`、main 仍为 `d1b2d06...`。未推 main、未强推。
- 全暂存内容的 whitespace 检查只报告原生 LSP 原始日志中的行尾空格（退出 2），为保留原始证据与交付哈希未清洗日志。源码/行动/说明文档的限定 whitespace 检查退出 0。源码相对已验收交付哈希一致，未重跑与推送无关的游戏检查。
- 原开发目录末次核验仍是 fengyycon@c59c590，暂存区为空，原有工作区修改保留；没有为了同步 GitHub 改写该目录的分支或索引。GitHub 新提交保存在上述独立工作树，避免与其他窗口并发工作冲突。
- Maker 端未提交、未推送、未远端构建。等待已发出的选择：保持当前分支要求、Maker 暂不推送；或明确授权 Maker 使用 main 而 GitHub 保持 fengyycon。收到决定前不执行依赖该授权的操作。
- 本回执仅留本地，不为归档再次提交或构建。交接对象：用户与 A2；待决定事项仅 Maker 目标分支。
