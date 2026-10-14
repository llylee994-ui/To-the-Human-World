# main 与完整 3D 候选的一次性历史整合

## Status and situation
Completed — 本地历史整合与新分支首次上传已完成，旧候选分支已按确认范围移除；本记录随最终交接提交同步。 用户希望未来 3D 分支与 main 有共同祖先，已同意在独立整合分支保留双方历史、处理冲突，再分步接入业务更新。用户指出存储空间紧张；本轮复用现有克隆与工作目录，不新增完整游戏副本。用户已明确确认：新整合分支上传且验证后，删除本地及 GitHub 的 cloud/3d-d00aca9，保留现有文件夹。

- 唯一工作目录：D:\taptap\D3-cloud-d00aca9\D3-github-cloud-3d-d00aca9。
- 初始状态：工作区干净，`cloud/3d-d00aca9` 与远端均为 `b9194ea32ee3e8eab7bdcd0d559890d3f20e115b`。
- 本次固定 main：`41cdaf3ff0fdd083d7411373a3cc9b70e26fb2e6`，已实际获取。旧预演的 `01be6d4` 已被后续 main 清理提交取代。
- 整合分支：`integration/3d-main-20261014`。真实合并保留两个父提交，不改写历史，不使用 ours 策略伪装业务整合，不修改或推送 main/旧 3d。
- 预演只有 `.gitignore`、`scripts/main.lua` 两个 add/add 冲突；另有约 1,674 个 main 独有文件，需按实际用途筛选。
- 本轮成功标准是历史连接、文件整合与当前 3D 入口不回退。main 的 schema 4 / 新内容业务接入是后续独立变更，不能把目录合并声称为这些新功能已进入 3D 游戏。
- 用户保留手动试玩验收权；不操作游戏鼠标、焦点、存档或其他项目目录。

## Implementation measures
1. 保存基线哈希和输入提交，在当前克隆建立整合分支。
2. 执行一次允许无共同祖先的普通合并，遇到两处已知冲突按明确职责处理：入口保留完整 3D；忽略规则保留两边有用部分，确保第一方 tools 与运行所需 UI 库可继续版本化。
3. 保留 main 的核心/内容/系统/UI、编辑器、当前资产、契约和开发文档。排除 main 的 2D 项目绑定及旧 `experiments/3d-lab` 样片副本，保留当前根目录 v035 测试及 probe.json。每个排除项记录源提交和理由，不触碰其他工作目录。
4. 更新仓库入口说明、行动记录与运行边界。明确 main 的业务源码已经存在，但当前 3D 仍通过 scripts/v035 使用原业务快照。
5. 检查冲突消失、完整资产/依赖哈希、保护目录保持不变、合并父提交和 main 祖先关系；独立提交并正常推送整合分支，查询远端验证。
6. 仅在用户确认范围、新远端分支验证且旧候选 tip 未变化后，删除被授权的旧分支。复用目录无需删除；不删除或改名任何源目录/历史包/运行包。

## Affected file tree
- `.gitignore`：合并忽略规则，隔离机器状态与测试进度。
- `scripts/main.lua`：解决冲突后保留现行 3D 入口的原字节。
- `scripts/{core,data,systems,ui,debug,story-editor,layout-editor,...}`、`assets/` 中 main 独有资源：接收 main 文件，不覆盖 scripts/v035 或 v035-full。
- `docs/`、`README.md`、编辑器启动脚本：接收 main 文档与工具，说明本分支的实际入口和运行方式。
- `docs/evidence/main-integration-20261014/`：输入版本、排除清单、保护哈希与静态验证。
- `docs/actions/2026-10-14-main-history-integration.md`：唯一整合行动记录。
- 不接收 `.project/` 与 main 的旧实验样片；原内容仍可在已保留的 main 父提交中查阅。
- `.runtime-windows/`、`.windows-runs/`：继续忽略，复用现有运行器，不复制新运行器。
- `scripts/素材/`：完整保留在 Git 中，本机通过稀疏检出暂不展开；`.git/info/sparse-checkout` 为本克隆的本机设置。
- `deliverables/CURRENT.md`：增加当前整合阶段标记，保留既有交付身份。

## Self-verification method
先核对工作区与远端输入；比较受保护路径的对象/文件 SHA256；运行 `tools/audit_v035_resources.py` 和只读 Windows 启动预检；检查新代码与保留运行代码的引用边界；检查 Git 未合并索引、冲突标记及本轮修改的空白；提交后验证两个父节点、main 与旧候选均为新提交祖先，并读取 GitHub 实际分支 tip。所有静态结果与用户试玩验收分开记录。

## Self-verification results
- 合并实际出现 2 个 add/add 冲突，均已解决；`scripts/main.lua` 与候选字节完全相同，`.gitignore` 合并两边用途并保留第一方工具/运行库的版本化。
- 142 个新带入文件（3,122,927 字节）按精确清单排除：8 个 `.project` 配置和 134 个旧样片文件；原内容在 main 父提交可查，当前 probe.json 未删。
- 启用本克隆的 Git 稀疏检出，只排除工作树中的 `scripts/素材/` 展开。369 文件、361,213,559 字节（344.48 MiB）仍在当前 Git 索引与提交中，全部素材许可保留；运行资源完整展开。已验证 369 文件仍被跟踪且磁盘副本为 0。
- 488 项受保护文件 SHA256 不变；当前资源 164 项、模型 100 个、入口代理 8 个、Lua 依赖 147 文件检查通过。
- Windows 启动器 `--check` 通过，没有启动、关闭、截图或操作用户窗口。未重新试玩；main 的新业务仍未激活。
- 合并中检查：1,531 个 main 文件按 Git 对象原样保留；候选已有的 1,007 个非本轮说明/入口例外文件按 Git 对象原样保留，入口另行确认完全相同。后续只添加本轮说明的阶段标记，不改业务或资源。
- `.runtime-windows`、`.windows-runs`、`.project` 被忽略；第一方 `tools` 与 `urhox-libs` 不被整体忽略。所有实际冲突已从索引移除。
- 本轮修改文件的空白检查通过；main 原有文件保留其原始字节，不为格式检查改写上游历史资料。
- **历史连接通过**：正式合并提交 `c14376ba4f585b54c9a835647cce553e3e09844c` 的真实父提交依次为候选 `b9194ea`、main `41cdaf3`；`merge-base HEAD origin/main` 返回 `41cdaf3`，旧 17 次云端提交仍完整可达。
- **新分支上传通过**：GitHub `integration/3d-main-20261014` 已实际查询确认指向上述合并提交。其后的交接记录提交继续正常推送，不改写合并历史。
- **旧分支清理完成**：新分支验证后，`git push origin --delete cloud/3d-d00aca9` 成功；`git branch -d cloud/3d-d00aca9` 成功。本地目录完整保留供新分支使用，不建立第二份游戏目录。随后独立查询 GitHub：旧分支已不存在，新整合分支与 main/3d 指向符合预期；记录见 [历史与交接核验](../evidence/main-integration-20261014/ancestry-and-handoff.json)。
- **空间口径**：少展开 344.48 MiB 美术过程稿；并入 main 的有效源码/资产和 Git 对象仍增加占用。删除旧分支名称本身几乎不释放空间，因为所有历史保留在整合分支。详见 `space-accounting.json`，不把工作树节省量误作整合前后的磁盘净减量。
- **验证边界**：没有重启游戏、自动鼠标、截图或真实存档操作；没有将 main schema 4/新内容宣称为已接入 3D。业务共享与升级作为后续独立适配，不属于本次提交历史连接的通过结论。
