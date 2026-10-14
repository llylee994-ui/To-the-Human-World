# 药炉动效验收后本地提交与指定分支推送

## 状态与现场

- In progress。2026-10-13，用户确认“可以，这个动效可以接受”，授权“本地提交并且 push 到对应分支”。这是对前轮不提交边界的新授权；仍不合并、不强推、不切换到 main。
- 模块：C-STOVE-PANZOOM-20261012-r1-v01 已交付药炉动效的版本归档。用户接受动效观感；不据此补写未提供的原生录屏、逐项人工测试或手机实测。
- 原工作区 fengyycon@5880d8f932221437d7621439e0e6658ad3e1ef6c，暂存区为空，13 项交付源码/记录哈希与上轮 delivery.json 全部一致。其他窗口的素材、编辑器与文档修改保留。
- 实时远端：GitHub fengyycon=b205ea1ffe9943b6f00441856237bb78991308b1，main=1cd0cdbec06487a5c60f109d5fd477198cfc8846；Maker 仅返回 main=7815675682a553f5c888bddb2688f36beab810fa，没有 fengyycon。
- Maker 状态：同一项目绑定健康。官方工具仅支持 main；历史该动作也曾因不能限定授权分支而被自动审批拒绝。本次不重复被拒动作，不改推 main，不绕过官方流程直推 Maker。
- 既有 GitHub 交付工作树 D:/taptap/To-the-Human-World-yaw-push 干净，detached HEAD 与远端 fengyycon 相同。开发分支与 GitHub 分支历史不同，不能直接普通推送开发 HEAD。

## 实施措施

1. 记录用户接受结果，沿用已完成的检查，不更改实现或重复游戏回归。
2. 在原工作区用明确文件清单本地提交本轮动效与证据；排除其他未提交成果和原始 *.log。
3. 在既有独立交付工作树，以 GitHub fengyycon 原头为唯一父节点准备普通提交。补齐当前运行画面必需、已在本地基线提交的主页/海边/HUD 组件与其实际引用资源；不复制原目录未提交的其他改动，不删除目标分支独有素材。
4. 核对依赖、源文件/提交 blob 哈希、单父提交、显式 refs/heads/fengyycon、main 未被本次操作更改，然后普通推送 GitHub。无合并提交、无强推。
5. 最终回执留本地，不为了把自身提交号入库再产生递归提交。Maker 保持未推送，明确报告分支限制。

## 影响文件树

```text
scripts/ui/landscape/                              本轮交付源码/测试；GitHub 补齐已有运行依赖
scripts/main.lua                                  仅 GitHub 同步本地已提交的当前 SafeArea 背景依赖
assets/image/misty-harbor-r1/、seaside-r1/           仅 GitHub 补齐当前场景实际引用的已有运行资源
.gitignore                                        仅 GitHub 同步已提交的原始日志排除规则
scripts/actions/2026-10-12-stove-panzoom-r1.md       用户接受补记
scripts/actions/2026-10-12-remove-stove-yaw.md       前轮已交付的后续行为说明
scripts/actions/2026-10-13-stove-panzoom-push.md     本记录
docs/验证/evidence/stove-panzoom-r1/                前轮证据/哈希与用户接受补记
docs/验证/evidence/stove-panzoom-push/              明确清单、远端核对、最终回执
```

## 自检方法

- 沿用已交付检查；本轮只做版本与发布验证，不把用户简短接受当作全量或手机验收。
- 待提交路径白名单、文本凭据特征检查、源码空白检查、Git blob 和交付 SHA256 对照。
- 同步后的运行 Lua/Python 模块和引用图片与已验收本地版本一致；缺失依赖补齐，不做新的功能修改。
- 推送后 git ls-remote 验证 GitHub fengyycon 的完整 SHA；记录 main；原工作区其他修改及索引保持。

## 自检结果

Pending。首次沙箱只读远端查询因 SEC_E_NO_CREDENTIALS 失败；使用已授权正常凭据上下文重查成功，未改凭据或代理设置。

## 交接

用户接受动效 → C 本地归档与指定分支普通提交 → GitHub fengyycon → 用户/A2 拉取。Maker 分支约束单列，未推送。无需为 GitHub 再次授权。
