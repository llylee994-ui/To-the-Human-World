# 新手引导二轮验收 · 2026-10-18

结论：上一轮主要阻塞已修复；本轮 3 项 P2 已在“修复记录”中处理，代码与隔离回归通过，仍待原生/手机复验。以下保留复核时的原始证据。仅后台代码检查和内存夹具验证；没有桌面控制、玩家存档读写、源代码修复、提交或构建。范围仍为相对 896d10d 的工作区新手引导实现。

## 实现规范与稳定性

已复验通过：

- 含 onboarding 字段的逐日回溯、返回回溯前均成功，字段保留。
- 重建视图后，读信及工作台步骤能够恢复到对应画面。
- 真实全局 EventBus 中剪词、接单不再产生锁定错误提示。
- 销毁视图后，四个新增事件监听均移除。

仍有 P2：设置与后台暂停优先级未实现。Onboarding.lua:456–478 的更新未检查设置可见性、焦点、最小化或竖屏。引导层 zIndex=1800 高于设置的 200；正常 brew.word 打开设置后两层均可见，教程继续覆盖设置。隔离情况下，设置开启且 focused=false，待推进仍能保存为 brew.book。应暂停引导更新并隐藏其遮罩，恢复后再定位；依据设计 §5。

## 方案符合度

已复验通过：letter.accept/result.explain/complete 不再使用四周拦截层封锁阅读及重新调配，complete 保留跳过；真实重新调配可返回工作台；读信展开与剪词收取已有动画检查。

仍有 2 项 P2：

1. 点击阅读步骤被自动跳过。Onboarding.lua:347–354 的 sea.read 分支主动调用 ctx.Read(id,true)。真实接收一封未读信后，设为 sea.read 并建立视图，不执行阅读点击，2.4 秒后已为 panel=reader、step=letter.cut。正常演出完成后的 AppView 自动打开路径亦需一并核查。依据设计 §3，玩家应点击实际阅读入口；恢复应准备入口而不替玩家执行阅读。
2. 投词与原料落锅仍提前推进。Onboarding.lua:388–391、441–447 只检查草稿，没有检查 brew.interaction.flight。真实保存草稿，并设置现有投放飞行状态 accepted=true、elapsed=0，仅更新引导后，word→book、ingredient→conditions，flight 仍有效。剪词的门禁修复未覆盖工作台两步。依据设计 §3、§5，真实命令成功后仍需等投放动画结束。

## 本轮验证

| 验证 | 结果 |
|---|---|
| run_onboarding.py | exit 0 |
| run_release.py --suite saves | 26/26，exit 0 |
| run_preload.py | 4 套全部通过，exit 0 |
| .tmp/review_onboarding_acceptance.py | 首轮回溯/总线/工作台恢复探针已通过 |
| .tmp/review_onboarding_standards2.py | 复验回溯及返回、真实总线、监听清理；复现设置覆盖与失焦推进 |
| .tmp/review_onboarding_acceptance2.py | 独立复现自动阅读、投词/投料飞行未完成即推进 |

关键探针输出：

```text
rewind: ok=true
realBus: stateLockedErrors=0
resume: scene=brew, hasWordPanel=true
noReadClick: panel=reader, step=letter.cut
wordFlight: step=brew.book, flightActive=true
ingredientFlight: step=brew.conditions, flightActive=true
settings: settings=true, onboarding=true, tutorialZ=1800, settingsZ=200
paused: focus=false, settings=true, tutorial=true, step=brew.book
```

概念图未在本轮改动；上一轮指出的聚光与金边效果仍以现有概念稿为准。当前没有新增原生或手机连续动效证据。

## 修复记录（2026-10-18）

- **设置/后台暂停**：`Onboarding.Update` 在激活状态下检查设置面板、焦点、最小化和竖屏；暂停时隐藏引导根层，不执行场景同步、待推进保存和遮罩定位。恢复时清空同步节流与布局缓存，重新定位目标；设置帮助便签仍可在设置层上方单独重读。`AppView` 暴露 `settings` 与 `IsInputActive()` 供该判断使用。
- **阅读入口**：`sea.read` 不再调用 `ctx.Read`。有打捞结果时保留海边“阅读捞到的信”按钮；重建后没有内存打捞态时打开来信抽屉，并把收到的信件卡片或列表作为光区。`AppView` 在引导的 `sea.salvage`/`sea.read` 步骤中，正常演出完成和“跳过演出”都不再自动打开阅读器，只提示点击实际入口。
- **投料动画门禁**：`brew.word`、`brew.ingredient` 的推进新增 `brew.interaction.flight.accepted` 检查；投放飞行未结束时保持当前步骤。删除 `DraftChanged` 立即推进旁路，改由统一进度轮询在动画结束后推进。
- **回归测试**：`OnboardingTest.lua` 新增设置/焦点/最小化/竖屏暂停与恢复、抽屉和海边按钮两种手动阅读入口、打捞完成不自动阅读、投词/投料飞行门禁，以及“草稿事件本身不能跳步”的断言；同时验证真实打捞后信件在点击前保持未读。

复跑结果：

| 验证 | 结果 |
|---|---|
| `run_onboarding.py` | exit 0，新增 4 组 PASS |
| `.tmp/review_onboarding_acceptance2.py` | `noReadClick={"panel":"letters","step":"sea.read"}`；`wordFlight`、`ingredientFlight` 均保持原步骤且 flightActive=true |
| `.tmp/review_onboarding_standards2.py` | 设置开启时 `onboarding=false`、失焦时步骤仍为 `brew.word`；销毁后 3 个监听均移除 |
| `.tmp/review_onboarding_acceptance.py` | `rewind.ok=true`、`stateLockedErrors=0`、`scene=brew/hasWordPanel=true` |
| `run_release.py --suite saves` | 26/26，exit 0 |
| `run_release.py --suite ui` | 11/11，exit 0 |
| `run_preload.py --suite all` | 4 套全部通过，exit 0 |
| `git diff --check` | PASS |

本轮本地离线 EmmyLua 客户端未加载标准库和引擎全局，诊断中的 Error 全部是 `undefined global variable`（`require`、`assert`、`graphics` 等），过滤后没有 `undefined-field` 等类型错误；因此未把该客户端输出记作 0 Error 证据。Lua 代码已由 Lupa 实际加载并跑完上述回归。原生遮罩层级、设置面板与引导的实际层叠、手机焦点切换和投放动画观感仍需真机验收。
