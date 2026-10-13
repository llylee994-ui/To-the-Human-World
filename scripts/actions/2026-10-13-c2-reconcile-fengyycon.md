# C2-RECONCILE-FENGYYCON-20261013-r1：修复本地与 GitHub 同名分支历史分叉

## 状态与现场

- In progress。用户要求“尝试解决分支”，并解释本地可合并、GitHub PR #10 却冲突的原因。
- 本地 `fengyycon=54eff6e2b4716031f1944465fe287f053cb34f0e`，GitHub `fengyycon=ff463d874d0fb5ff7aacdb93af6309b30369d1e5`，GitHub `main=1cd0cdbec06487a5c60f109d5fd477198cfc8846`。本地包含 main，GitHub 同名分支的共同祖先仍为 `0f6c248c9f4b51797df5626867ecfd0fcb318fec`。
- 依据 `2026-10-13-stove-panzoom-push.md`，此前交付在两套历史分别提交相同文件，以不合并、只推指定分支的当时范围完成发布；没有把本地 main 历史带到远端分支。因此内容同步不等于提交历史同步。
- GitHub PR #10 的 main/远端分支模拟合并确有 5 个代码冲突：AppView、DevChecks、HomeView、SceneBackdrop、HomeEntryTest。但这 5 个文件在本地 HEAD 与 GitHub fengyycon 的 Git blob 全部相同。
- 将本地已含 main 的 HEAD 与真实 GitHub fengyycon 合并，运行源码无冲突；仅有 17 份 `docs/验证/evidence/remove-stove-yaw/` 历史证据因 CRLF/LF 差异发生 add/add 冲突，逐份规范为 LF 后内容完全相同。
- 开发目录尚有 28 个修改、68 个删除、262 个未跟踪路径，暂存区为空。不得混入这些未提交成果。最新用户接受的炉具平移缩放行为按已提交 `54eff6e` 保留，不恢复自动 HomeYawProbe。
- 范围仅 GitHub fengyycon 与本地同名分支；不合入 GitHub main、不操作 Maker 提交/构建、不访问外部 3D-Lab、不操作 OS 输入。

## 实施措施

1. 保存当前分支、索引与所有未提交路径的 SHA-256/删除状态；对本地同步可能碰到的同名未跟踪/忽略文件先核对并逐项备份。
2. 在独立 detached 工作树 `D:/taptap/To-the-Human-World-c2-reconcile-20261013` 中，以本地已提交 `54eff6e` 为基线，合并已获取的 GitHub `ff463d8`；不创建额外执行者，不占用其他窗口的工作树。
3. 逐项证明 17 份证据只有换行差异，沿用本地已提交版本，不修改证据含义。保留两边已提交的文件与提交历史；不选入原工作区的未提交修改。
4. 验证运行代码、业务数据、运行素材、项目配置与原本地 HEAD 一致，源码冲突消失、三条旧头均为新头祖先；必要检查按实际内容变化安排。
5. 用一个双亲合并提交连接两套历史；本地开发分支快进到该提交并恢复原有未提交字节。普通推送仅 `HEAD:refs/heads/fengyycon`，不用强推。
6. 重新核对 GitHub PR #10 可合并状态、两处 fengyycon 头一致、main 未被更改。最终发布回执保留在本地备份证据中，避免为了记录自身提交号递归提交。

## 影响文件树

```text
scripts/actions/2026-10-13-c2-reconcile-fengyycon.md  本次历史修复行动记录
docs/验证/evidence/remove-stove-yaw/                 17 份既有证据仅统一合并选择，不重写事实
两条分支已提交的素材、文档与历史证据                由 Git 合并保留，完整路径写入证据清单
D:/taptap/.sync-backups/20261013-c2-reconcile-fengyycon-r1/  基线、冲突对比、路径清单、验证及发布回执
```

## 自检方法

- 精确核对实时远端 SHA 与 PR base/head，不凭分支名判断相同。
- 比较冲突两侧字节及换行归一内容；运行目录、数据、素材和项目配置与本地已提交基线进行 Git tree/blob 对比。
- 检查合并父节点、祖先关系、`git diff --check`、无未解决索引项、PR 可合并性。
- 同步前后比对所有原有未提交文件 SHA-256 或删除状态；Git 已忽略但将被远端同名路径覆盖的文件也单独备份并保留。
- 若运行内容完全相同，则不重复整套测试或刷新预览；不把分支修复当成原生、截图动画、OS 人工或手机验收。

## 自检结果

- 已在独立工作树执行真实 merge，17 项冲突全部确认只有 CRLF/LF 差异并选用本地既有提交字节；`git ls-files -u` 为空。
- 合并树与本地 `54eff6e` 比较：`scripts/ui`、`scripts/main.lua`、`scripts/core`、`scripts/systems`、`scripts/data`、`scripts/debug`、`assets`、`.project` 均无差异。5 个 PR 源码冲突通过接回已有历史消除，没有重写游戏代码。
- 相对原本地 HEAD 新增的 153 个路径均逐项确认 Git blob 与原 GitHub `ff463d8` 一致；来源是远端既有证据、素材和 2 份行动记录，不含开发工作区的未提交成果。完整清单在备份目录 `merged-paths.txt`、`incoming-paths.json`。
- 153 个新增路径在开发目录均已有同名未跟踪或忽略文件：151 个字节相同，2 份行动记录有本地后续回执差异。同步时逐项备份并恢复原字节，2 份本地后续回执保留为未提交修改，不覆盖或上传。
- 全量 `git diff --cached --check` 退出 2：命中远端原有日志和素材记录的尾随空白。153 个新增 blob 全部等于远端既有 blob，确认不是本轮新增空白；保留历史证据原件，不扩展成清理任务。本轮行动记录单独检查，结果见发布回执。
- 本轮没有改变运行内容，按相同 tree/blob 的静态证据验证，不重跑整套测试。引擎原生／内部指针、截图与动画、OS 人工、手机均未新增验证；未刷新已有预览。旧 DDS/DLL 问题没有纳入本次修复或宣称解决。
- 基线保存于 `D:/taptap/.sync-backups/20261013-c2-reconcile-fengyycon-r1/baseline.json`，含原有 358 个未提交路径与本行动记录；原索引和完整工作区差异已备份。17 项两侧哈希及解决选择在 `conflicts.json`。
- 当前合并内容已准备；提交、普通推送、本地对齐、GitHub PR 可合并性及最终保全结果，在同一备份目录的 `receipt.json` 记录。此入库记录不预先宣称这些后续动作成功。

## 交接

- 对象：用户与 A2，由用户转发。
- 必须修改项：连接分叉历史，消除 PR #10 冲突。
- 待用户决定事项：无；已授权的本分支修复直接推进，不合并 PR 或更新 main。
