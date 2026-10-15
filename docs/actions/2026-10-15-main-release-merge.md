# main 首发更新合入当前完整 3D 分支

## Status and situation
Completed（代码合并、冲突处理与记录整理；未运行测试）。2026-10-15 用户明确授权按 main 首发范围保留案件资料、隐藏玩家案件入口，处理两处配置冲突，在当前 integration/3d-main-20261014 分支正常合并、提交并 push；不继续测试。本记录随普通合并提交保存；远端交付状态以随后实际 push 和分支 tip 核验为准。

- 唯一工作目录：D:\taptap\D3-cloud-d00aca9\D3-github-cloud-3d-d00aca9。
- 修改前本地与 GitHub 分支均为 11a09ac69f34bb17e215aed7c0accc1230af83aa；工作区和索引干净，无未提交用户文件或 Git 写入锁。该提交为本轮回退定位点。
- 已重新获取的 main：7f1f6d44b6d9d56166ced231afedac17d217eb3f；共同基线 41cdaf3ff0fdd083d7411373a3cc9b70e26fb2e6。
- 权威范围：[首发规格](../superpowers/specs/2026-10-13-ordinary-release-design.md)、[首发计划](../superpowers/plans/2026-10-13-ordinary-release.md) 与 [接口手册](../../scripts/前端接入接口手册.md)。案件资料保留、普通玩家入口隐藏，开发查看能力保留；不补写案件业务，不把占位页称为完整玩法。
- 保留 d584352 场景、材质、位置、灯光、Windows 启动方式和隔离内存存档。其他项目、Blender 源工程、正式存档及用户已打开的游戏窗口不操作。

## Implementation measures
1. 核对 HEAD、分支、干净状态与远端；记录此次真实输入，不回退已有成果。
2. 正常合并固定 main 提交，保留两个父提交，不使用强制覆盖、历史重写或全局 ours/theirs。
3. `.gitignore` 保留当前 3D 运行器/存档/下载分块/私密资料的忽略规则，添加 main 新增的 `scripts/layout-editor/.local/`；第一方 tools 与 urhox-libs 继续版本化。
4. `.project/project.json` 继续保持本分支已删除状态，不恢复旧 2D Maker 项目绑定；上游原文件仍在 main 历史中。
5. 接收 main 的共享玩法、界面、首发结局和相关文档。3D 主界面接收共享页面传入的正式/开发模式，隐藏正式模式下的案件点击与提示，保留档案模型和稳定对象标识。
6. 同步当前运行说明和 main 来源标记。只做 Git 冲突、文件差异、保护路径和提交祖先关系核对；遵照用户要求不运行任何游戏、自动测试或实际点击。
7. 保存普通合并提交，正常推送且只更新 integration/3d-main-20261014；读取 GitHub 分支 tip 核实结果。

## Affected file tree
- `.gitignore`：合并本机隔离配置。
- `.project/project.json`：解决 modify/delete 冲突，保持删除，不作为新增配置提交。
- main 更新的 `assets/image/`、`scripts/core`、`scripts/data`、`scripts/systems`、`scripts/ui`、编辑器和文档：接收主线首发能力，保留本地 3D 装配差异。
- `scripts/v035/lab35/Integration.lua`、`HomeView.lua`：按共享首页传入的 release/developer 模式隐藏案件入口及提示，模型与镜头不变。
- `scripts/v035/lab35/Bootstrap.lua`：更新共享 main 来源提交标记，不修改存储行为。
- `scripts/v035/lab35/tests/MainIntegration.lua`：仅同步既有用例的正式模式装配和案件关闭预期；仍保留八个语义对象、七个玩家入口，未执行该用例。
- `README.md`、`docs/WINDOWS-RUN.md`：更新首发功能范围与本轮未测试边界。
- `docs/actions/2026-10-15-main-release-merge.md`：本轮唯一行动记录。
- `docs/evidence/main-release-merge-20261015/git-merge-review.json`：输入版本、精确文件清单、冲突处理及保护路径核对记录；不属于运行或游戏测试证据。
- 受保护路径：`scripts/main.lua`、`assets/v035-full`、`assets/v035-main-image`、`urhox-libs`、根目录 `v035`、Windows/云端启动与观测工具；与修改前对象比较。

## Self-verification method
仅进行 Git 合并及交付核对：冲突索引、变更清单、保护路径对象一致性、案件资料保留、提交父节点/祖先关系及远端目标分支。既有游戏测试、静态测试脚本、启动器预检、运行、截图和鼠标验收全部跳过；之前 d584352 的验证不能代表合并后的运行通过。

## Self-verification results
初始工作区干净；已获取双方最新提交，实际合并仅出现预演中的两处配置冲突，均按用户确认范围解决，未合并索引已清空。

- 合并前待调整的 7 个已有文件已在仓库外完整备份并逐项核对字节，目录为 D:\taptap\D3-cloud-d00aca9\docs\actions\main-release-merge-20261015-160112-356975；包含 backup-manifest.json，未混入 Git 提交。
- `.gitignore` 保留本地原有规则，只补充 main 新增的 `scripts/layout-editor/.local/`。`.project/project.json` 按本地既有删除状态解决，不恢复 2D 绑定。
- main 的共享 AppView 保留本地 nativeScene、homeFactory、model、bind 和 panels 接缝，同时接收 main 首发入口限制。3D HomeView 使用同一共享页面传入的 developer/releaseMode，正式模式不注册案件提示并拒绝该对象点击；档案模型、八个语义对象标识和场景锚点不删改，开发模式仍可查看占位页。
- 只同步原有 MainIntegration 用例对案件入口的预期，不执行它；旧 344 项检查结果不可沿用为此次合并通过结论。
- 游戏测试、静态测试脚本、启动器预检、真实窗口和鼠标验收均按用户要求未执行。已有游戏窗口与玩家存档未操作。
- Git 合并范围核对完成：固定父输入为 11a09ac 与 7f1f6d4；保护路径与修改前 Git 对象一致，包括 3D 入口、完整场景资源、主参考资源、运行库、旧独立测试快照、启动工具、加载器、灯光、镜头和内存存档实现。主线文案、完整案件故事线及案件查询文件均未删除或修改。
- 暂存内容与合并预演树相比，仅有已列明的配置处理、3D 首发入口适配、来源标记、既有用例预期和本轮文档差异；共享 AppView 等于 Git 自动合并结果，本地 3D 接缝保留。新证据记录加入前共 141 个变更路径，精确清单见 [Git 核对记录](../evidence/main-release-merge-20261015/git-merge-review.json)。证据记录本身另计 1 个新增路径。
- 本轮手工修改文件的 Git 空白核对通过；保留上游原有文件字节，不为格式检查改写上游内容。此结果只证明提交范围与冲突处理状态，不证明玩法或画面通过。
