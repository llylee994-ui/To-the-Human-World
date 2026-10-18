# 新手引导代码实现记录

## Status and situation

Completed（代码与隔离回归；未生图、未提交、未推送、未触发远端构建）。用户要求按 [新手引导设计 v01](../superpowers/specs/2026-10-18-onboarding-design.md) 执行代码部分，生图跳过。

本轮接入开场便签、网兜/海边/读信/剪词/接单、工作台四步与结果说明、首单寄出完成、跳过和存档恢复。本轮未执行生图；设计文档 §7 已有的四格概念图仅作参考，不接入运行资源。

## Implementation measures

1. schema 4 新增可选 `onboarding` 字段（版本、步骤、完成、跳过、便签已读）；旧档缺字段时不启用，新旅程初态明确启用。
2. `GameSession` 在显式 `onboarding=true` 时写入新旅程初态；`GameState.SetOnboarding` 使用完整整档保存，不递增业务 revision、不派发经营事件。
3. 新增 `Onboarding.lua` 表现层：55%～65% 暗色遮罩、暖光边、单目标光区、小纸笺提示、跳过按钮、便签展开、完成提示；目标按实时 widget 布局或主页 manifest 光区定位，不写死手机坐标。
4. 目标动作全部走现有模型/协调器；成功事件或真实快照变化推进，事件在业务提交期间只记待推进，下一帧再保存引导状态。
5. 工作台拖动步骤不封锁整个工作台；条件未满足的“开始熬制”也保留普通操作，避免把玩家堵在引导里。
6. 已保存的结局/试做只做展示层等待，不重复确认、发奖或推进事务；中断/重入按真实快照恢复，不重播已完成的剪词、接单或试做。
7. 引导层关闭/销毁时清理 EventBus 监听、拖动/遮罩状态，并恢复进入前的物件提示开关。
8. 设置面板增加“回顾新手便签”；它只重开便签，不改变当前旅程步骤或业务状态。
9. 设置开启、应用失去焦点、最小化或竖屏时暂停引导层并停止推进，恢复后重新定位；阅读步骤只准备真实入口，不替玩家读信；工作台投词/投料推进等待投放飞行动画结束。

## Affected file tree

- `scripts/core/SaveSchema.lua`：可选 `onboarding` 结构与显式校验。
- `scripts/core/SchemaProjection.lua`：schema 2 投影剥离 onboarding，避免旧审计拒绝新字段。
- `scripts/core/GameSession.lua`：仅在显式请求时为 schema 4 新旅程写入引导初态。
- `scripts/core/GameState.lua`：新增整档保存的 `SetOnboarding`。
- `scripts/main.lua`：正式入口请求新旅程引导初态。
- `scripts/ui/landscape/AppView.lua`：创建/更新/销毁引导控制器，并把设置面板接入便签重读。
- `scripts/ui/landscape/MusicSettingsView.lua`：新增“回顾新手便签”帮助入口。
- `scripts/ui/landscape/Onboarding.lua`（新增）：引导状态机、遮罩、便签和提示层。
- `scripts/ui/landscape/tests/OnboardingTest.lua`、`run_onboarding.py`（新增）：隔离回归与运行器。
- 本记录；设计文档顶部补充实施状态。

## Self-verification results

| 检查 | 结果 |
| --- | --- |
| `python -X utf8 -B scripts/ui/landscape/tests/run_onboarding.py` | PASS：新旅程开场、便签收起、跳过、旧档不启用、完成/跳过持久化；设置/焦点/最小化/竖屏暂停恢复；手动阅读入口；投料飞行门禁 |
| 真实命令链 | PASS：真实收信/读信/剪词/接单/更新词条草稿/原料草稿/打开并收起条件/预览/确认各推进一次；首单寄出后 completed |
| 暂停优先级 | PASS：设置打开、失焦、最小化、竖屏均隐藏引导并停止推进；恢复后重新同步场景 |
| 阅读入口 | PASS：打捞完成不自动打开阅读器；点击海边按钮或来信抽屉卡片后才读信并推进 |
| 投料动画 | PASS：投词/投料飞行期间步骤保持，飞行结束后才推进；草稿事件不能单独跳步 |
| 逐日回溯兼容 | PASS：含 onboarding 的完整备份通过 Rewind 校验，RestoreDay 正常返回 |
| 真实 EventBus 事件 | PASS：业务 busy 期间 0 次 STATE_LOCKED 提示，下一帧推进 |
| 中途续接 | PASS：brew.word 重入后 scene=brew、词条面板存在、遮罩保持 |
| 遮挡放行 | PASS：letter.accept 与 complete 不封锁正文/重试/滚动，complete 仍可跳过 |
| 帮助重读 | PASS：设置入口重开便签，关闭后不改变当前进度 |
| `run_release.py --suite saves` | PASS，26/26；schema 2/3/4 旧档边界未回退 |
| `run_release.py --suite ui` | PASS，11/11 |
| `run_release.py --suite endings` | PASS，7/7 |
| `run_preload.py --suite all` | PASS，catalog/loader/entry/navigation 全部通过 |
| `run_first_batch.py / run_word_tray.py` | PASS，966 / 64 断言 |
| Maker Lua LSP（9 个变更/新增 Lua 文件） | 0 Error |
| `git diff --check` | PASS |

## 已知边界

- 本轮未执行生图；设计文档 §7 的四格概念图仅作设计参考，不接入运行资源；运行时只用现有纸面、暖光和 NanoVG 绘制。
- 本地预览在刷新时结束为 stopped，未自动重启；本轮没有新的原生遮罩视觉、拖动路径或手机触碰证据。
- 首次加载/字体布局与引导光区的原生层级、弱网重连后的步骤恢复、手机安全区与长文滚动仍需真机验收。
- 设置面板与引导层的实际层叠、切后台/最小化后的焦点恢复、投放飞行动画与步骤提示的观感仍需真机复验。
- 本轮本地离线 EmmyLua 客户端未加载标准库与引擎全局，诊断 Error 均为 `undefined global variable`，未作为类型诊断证据；相关 Lua 已由隔离运行加载并完成回归。
- 帮助入口已接入设置面板的“回顾新手便签”；`Onboarding:ShowNote()` 也可直接复用。
- 原生/手机验收按设计文档第 8 节执行，隔离测试不能替代真机结论。


## r4 手机截图反馈修复

依用户最新要求废止强制炼药与结果/发货引导；五项均为知道了说明。修复便签实际字形高度、木板按钮、词语级光区和接单浮层；详见 [r4 验收](../验证/2026-10-18-onboarding-review-r4.md)。
