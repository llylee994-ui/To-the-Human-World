# B6 提交不确定恢复复核与提交

## 状态与范围

In Progress。用户要求复核 `2026-10-04-b6-uncertain-recovery.md`，无阻断则提交推送。开工 fengyycon@aef9558；工作区包含累计未提交 B5/B6／一次性词卡、隔离持久预览及原生故障验收程序。队友正在编辑的 docs 文案保留，不纳入本批程序提交。

遵循 code-review-skill、action-document、project-control-report 和项目 Maker 提交流程。发布范围为 scripts 中本批程序、必要依赖、检查工具与交接记录；排除 logs、原生存档、本机 .mpv 工具副本、访问凭证与引擎开发资料。不因提交更改玩法、内容参数或重启已停止预览。

## 实施措施

1. 核对定点读回注入是否仅绑定专用槽、默认关闭，正式协调器是否保持锁定、同槽恢复与幂等。
2. 复核原生留证比较器，重跑受影响逻辑回归和完整 Lua 诊断；保留原生证据与隔离回归的边界。
3. 生成明确文件清单，检查暂存、敏感信息与远端地址（不输出认证内容）。通过 Maker 官方工具提交构建，依返回结果处理分支及推送状态，再同步 GitHub。
4. 记录提交 SHA、两端推送和构建实际结果，说明下一步与剩余验收项。

## 影响文件树

- `scripts/actions/2026-10-04-b6-review-and-publish.md`：本轮复核与发布事实。
- 待提交的 `scripts/` 既有程序／检查／计划：以最终清单为准，不新增业务范围。
- `logs/`：忽略的本轮验证日志，不提交。

## 自验证方法

静态核对 GameState、SaveSystem、B6UncertainStorage、main 默认入口和专用槽；执行 B1～B6、一次性、正式内容检查；原生证据比较器仅复核留存证据、不冒充再次操作窗口；运行本地全 scripts LSP。核对 B6RunRequest=off、预览停止、git diff --check、提交范围及构建结果。

## 自验证结果

- 复核未发现本批阻断问题：故障包装只在精确 b6_uncertain 槽装配，默认 off；真实写入后才拒绝指定提交标记读回；解除故障不自动解锁，原槽恢复只派发 SaveLoaded，确认幂等。隔离工具副本与存档均不在发布清单。
- 本轮 B1/B2/B3/B4/B5/B6：130/212/387/339/373/170 项全部通过；一次性 229 项、内容 1265 项通过，当前来源16/16、未来纯计算9/9、矩阵9/9。日志为 `logs/publish-review-*.log`。
- 原生留证比较器全部通过：持久性 C/P/F、重置／三单／双来源卡、原生只读故障39项、指定提交读回异常22项。本轮仅重跑比较器，没有重新操作窗口；其范围仍为本机隔离候选，不等于官方／手机或物理断电验收。
- 全 scripts LSP 最终 2026-10-04 17:06:48 为 0 Error／0 Warning／0 Hint；`logs/b6-publish-review-lsp/lua_diagnostics.log`。本次诊断进程已结束。
- 发布候选67个 scripts 文件，约633KB，凭证形态扫描未发现问题；git diff --check 通过，B6RunRequest=off。docs 并行改动排除。
- Maker ready/auth found；实际仅 origin 指向 GitHub。fengyycon 当前 aef9558，main 仍为历史6987db5。接下来执行官方提交入口并按其真实分支／同步结果处理，不把工具就绪视为推送完成。

## 发布准备接续

- Maker 首次在 fengyycon 拒绝提交，classification=branch_not_allowed；没有产生提交或远端构建。
- 真实 Maker main 另有 b5ac511/2205ca4 两个文案提交；原18份对应文案与本地内容一致，唯一程序侧重叠为队友计划。已采用原有 main 分支的独立 Git worktree `D:/taptap/To-the-Human-World-b6-submit` 快进到最新内容，不新建 Maker 项目、不运行 init；原开发目录保持 fengyycon。
- 队友计划三方合并仅一个进度段冲突：采用已验证的 story-v0.4-r1 进度，并保留远端卢卡新来信／五分支待定／旧联动停用说明。其余发布文件与已审原文件逐字节相同，远端新增提交没有改运行 Lua/data，不重复运行无变化的逻辑测试。
- 复用当前项目的本机绑定，独立提交目录的 Maker status 确认为同一既有项目 bound/ready。github 远端明确保留为 GitHub，origin 由官方工具管理为 Maker。67份 scripts 发布清单已检查，队友文案作为已发布父提交继承，本批不另改 docs。
- 提交、双端推送与远端构建结果待下节实际回执。
