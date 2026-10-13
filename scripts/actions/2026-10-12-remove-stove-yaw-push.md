# 取消药炉动效 · 提交推送记录

## 状态与现场

- In progress。用户在取消药炉动效、自测交付后要求“提交推送”。提交本次已验收结果及其关联源码、测试和证据；不纳入其他窗口修改。
- 原工作区 `D:/taptap/To-the-Human-World` 仍为 `fengyycon@c59c59044218e6be626edb86f66dc950f6943bd2`，大量既有未提交修改保留，暂存区原状保留。
- GitHub 实时核对：`fengyycon=978a738c7c8b46b2f05e00a0a1dfc8903ff0f392`、`main=27aaa971e7dc0377e67cea1e3dc8dd2a8ff35ca7`。既有交付工作树 `D:/taptap/To-the-Human-World-yaw-push` 干净，detached HEAD 与目标分支相同。
- Maker 状态查询：绑定健康。远端只读分支查询本次 HTTP 502；官方 taptap-maker-local 规则与工具说明仍限定只接受 main。上轮 Maker 提交曾被自动审批拒绝，原因是不能证明只操作用户授权的 fengyycon。用户未授权改推 main；本次不重试被拒动作、不切换分支、不合并、不强推、不改绑定。Maker 保留未推送状态。
- GitHub 目标源码尚未包含本地上一轮药炉接入的部分关联修改。提交当前已自测的最终 AppView、默认关闭开关、HomeYawProbe/Scene 与相关专项测试，保持交付版本一致。正常药炉入口无转头路径；保留的独立开发探针默认关闭。

## 实施措施

1. 已完整读取 project-control-report、action-document；读取适用 AGENTS 提交规则和 Maker 工作流的提交限制，核对远端与工作区。
2. 以 GitHub 当前 fengyycon 为父提交，在既有独立交付工作树复制明确清单，不改变原工作区分支/索引。只追加普通提交，不产生 merge。
3. 核对取消动效 delivery.json 的源码哈希，扫描待提交文本的凭据特征，检查显式暂存清单和 blob 与源文件字节。
4. 非强制推送 `HEAD:refs/heads/fengyycon` 至 GitHub，随后读取该远端分支 SHA；检查 main 未被本次操作更改。
5. 最终回执只存本地，不为归档自身提交号再次提交或触发 Maker 构建。

## 影响文件树

```text
scripts/ui/landscape/AppView.lua                       已验收的直接导航与覆盖层层级
scripts/ui/landscape/DevChecks.lua                     关联检查开关，全部默认关闭
scripts/ui/landscape/HomeYawProbe.lua                  当前关联组件版本；正常入口不调用
scripts/ui/landscape/HomeYawScene.lua                  当前资源释放修正
scripts/ui/landscape/tests/StoveYawEntryTest.lua        已验收 F→P / P→P 专项
scripts/ui/landscape/tests/StoveYawNativeProbe.lua      已验收原生内部输入检查
scripts/ui/landscape/tests/run_stove_yaw.py             检查入口及开关隔离
scripts/actions/2026-10-12-stove-yaw-entry.md           被取消的历史任务记录
scripts/actions/2026-10-12-remove-stove-yaw.md          最终实现与验证记录
scripts/actions/2026-10-12-remove-stove-yaw-push.md     本轮提交前记录快照
docs/验证/evidence/remove-stove-yaw/                    已交付证据与哈希清单
docs/验证/evidence/remove-stove-yaw-push/               本地提交/推送回执，不另推
```

## 自检方法

- 原工作区和交付工作树的 HEAD、暂存区、目标远端分支前后核对。
- 待提交源码/证据与已验收交付逐文件 SHA-256 比对；声明式精确暂存，核对零删除、零其他目录修改。
- 源码/文档空白检查、文本凭据特征扫描；原始日志不清洗以保留证据。
- 提交父节点唯一且等于远端基线；实际远端分支 SHA 等于提交 SHA。
- 本轮不修改实现，不重复游戏回归或启动预览。沿用上一轮 144 / 383 / 303 断言及原生专项结果，手机和整体 Maker 检查限制照旧。

## 自检结果

- 提交前核对：59 个明确文件（含实现、测试、关联源码和原始证据），约 9.47 MB。凭据特征扫描无命中；交付源码与取消动效 delivery 清单一致；全部暂存 blob 与源文件 SHA-256 一致，零删除、零其他目录修改。
- 默认源码空白检查退出 2：两个 Lua 专项文件末行分别为 `return T\r\n`、`return N\r\n`，报告 CR 为尾部空白。仅对本次命令声明允许 CRLF 后，源码/文档检查退出 0；未改全局配置或原文件。包含原始证据的默认整体空白检查仍退出 2，保留原始日志格式，不当作通过。
- 沿用上一轮已运行的自测；本次未改实现、未重复运行游戏。GitHub 提交与远端 SHA 核对 Pending，完成后回执保留原工作区。

## 交接

- 对象：用户与 A2，由用户转发。
- DAG：已验收取消动效成果 → 显式清单与哈希核对 → 普通提交 → GitHub fengyycon → 用户/A2 拉取。
- GitHub 范围无待用户决定事项。Maker 仍受仅 main 的工具限制与用户仅当前分支约束阻挡；未获 main 授权前不执行。
