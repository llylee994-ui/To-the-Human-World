# 新手引导验收复核 · 2026-10-18

结论：复核时未通过验收；下列 P1/P2 问题已在 2026-10-18 修复记录中处理，仍待原生遮罩、手机触碰与连续动效复验。代码范围为相对 `896d10d` 的工作区引导实现与新增 Onboarding 模块；方案依据为该提交中的新手引导设计。复核本身仅后台静态核对、概念图查看与隔离内存存档探针，没有桌面控制、玩家存档访问、源代码修复、提交或构建。

## 实现规范与稳定性

1. P1：新旅程带有 onboarding 字段后，逐日回溯失败。SaveSchema 接受该字段，但 RewindHistory 的完整备份校验白名单未接入；真实 StartJourney 后可用回溯点调用 RestoreDay 返回 STATE_INVALID，嵌套 UNKNOWN_FIELD 路径为 chapter.rewind.backup.snapshot.onboarding。跳过或完成教程仍保留字段，问题不会随教程结束消失。
2. P1：中途继续游戏无法回到引导目标场景。Onboarding 的 syncScene 只定义未调用，重建 View 仍在 home；存储 brew.word 后推进十秒仍为 home、无 brewWordPanel、引导遮罩可见。目标缺失会形成全屏阻挡。此项也属于方案续接要求未满足。
3. P2：真实同步 EventBus 的 WordCut 等业务事件会在协调器 busy 期间立即尝试 SetOnboarding，产生 STATE_LOCKED 误报，0.6 秒后重试才推进。现有专项使用的夹具总线不向全局 EventBus 派发，未覆盖生产事件路径。

## 方案符合度

1. P1：上述恢复场景缺失违反设计 §5、§8.6。
2. P1：结果说明点“知道了”进入尚未正式完成的 complete 步骤后，只放行 confirmOrder，遮罩挡住重新调配及正文滚动，且跳过按钮隐藏。违反设计 §3、§4、§8.5 的试做自由返回及每步可跳过。
3. P2：剪一张词后 letter.accept 只放行 acceptOrder，正文剪词和滚动被四周拦截层挡住。违反设计 §3 保留继续阅读和剪词机会。
4. P2：推进依据为面板状态、快照和业务事件，没有等待读信展开、剪词收取及投料飞行动画完成。违反设计 §3、§5 的成功加动画完成门禁。

## 概念图与记录

- 概念图四个阶段的空间关系和便签无署名方向符合方案。便签格的药炉及海面仍较亮，聚光焦点不够集中；网兜金边及点光偏强，正式实现应使用文档要求的柔光。
- 当前设计文档开头及实现记录写“概念图未制作/未生成”，但四格图已存在并记录在设计文档 §7，状态冲突。
- 实现记录前部及代码中已接入设置帮助入口，末尾却写“帮助入口重读便签尚未接入”，状态冲突。

## 新鲜验证证据

- `python -X utf8 -B scripts/ui/landscape/tests/run_onboarding.py`：退出 0。该专项通过不能证明场景续接、遮罩命中或真实事件回调通过。
- `python -X utf8 -B .tmp/review_onboarding_acceptance.py`：仅用 B5Fixtures 内存介质，分别复现回溯失败、真实总线误报和工作台步骤重入后停留主页。探针输出：

```text
rewind: ok=false, STATE_INVALID, UNKNOWN_FIELD chapter.rewind.backup.snapshot.onboarding
realBus: stateLockedErrors=1, stepBeforeRetry=letter.cut, stepAfterRetry=letter.accept
resume: step=brew.word, scene=home, panel=false, hasWordPanel=false, overlayVisible=true
```

当前没有原生遮罩、手机触碰或连续动效证据，以上结论不冒充真机验收。

## 修复记录（2026-10-18）

- **P1 回溯**：`RewindHistory.full` 白名单接入 `onboarding` 并校验；`PlanRestoreDay` 保留当前引导状态。复核探针 `rewind.ok=true`。
- **P1 续接**：`Onboarding.Update` 现在实际调用 `syncScene`；`brew.word` 重入后 `scene=brew`、`hasWordPanel=true`、遮罩保持。
- **P2 真实事件**：业务 busy 期间不再提示 `STATE_LOCKED`，只保留待推进并在下一帧重试；复核探针 `stateLockedErrors=0`。
- **方案符合度**：`letter.accept` 与 `complete` 不再用四周拦截层封锁正文/重试/滚动；`complete` 仍显示“跳过引导”；结果说明的“知道了”等待结果页展开动画稳定；剪词推进等待纸条收取动画结束。
- **文档冲突**：设计文档顶部与实现记录改为“本轮未执行生图，§7 概念图仅作设计参考”；“帮助入口未接入”的旧表述已删除，设置面板的“回顾新手便签”已接入并通过专项。
- **复跑**：`run_onboarding.py`、复核探针、`run_release.py --suite saves` 26/26、FirstBatch 966 均通过；相关 Lua LSP 0 Error。
