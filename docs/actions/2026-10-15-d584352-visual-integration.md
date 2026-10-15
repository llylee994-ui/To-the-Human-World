# d584352 美术包整合到共享 main 玩法

## Status and situation
In progress. 用户授权先本地提交检查点，再从完整包导入已确认美术、逐项适配加载/灯光/交互，分阶段本地提交并进行 Windows 验证；不切换分支、不更新 main、不 push。

- 实际仓库：D:\taptap\D3-cloud-d00aca9\D3-github-cloud-3d-d00aca9。
- 实际分支：integration/3d-main-20261014。
- 修改前 HEAD：135334dc997023a1bbbc35c1b994364a24504c3a；无后续提交，工作区与索引干净。未发现 Git 写入锁；本机进程命令行查询被系统拒绝，不能据此声称已读取其他聊天的任务状态。后续每阶段提交前复核状态与 HEAD，发现外来修改即保留并协调。
- 现行玩法依据：scripts/前端接入接口手册.md；3D 宿主经 Bootstrap 使用共享 core/data/systems/ui.PlayModel、ordinary-release-v2/schema 4 和 MemoryStorage。保留 135334d 的全部共享玩法接入及 main 合并、开发计划、接口文档与清理成果。
- 上轮外层清理没有仓库源码改动，已在仓库外记录并验证；本次初始提交保存本基线说明，不伪称存在待提交源码。
- 完整包来自 C:\Users\YINGYI\Downloads\2，11 个分块及恢复工具 ZIP 已找到；版本 d584352a8e5cd0a776f91b41e1f3d7f7e7a6d35d。预期整包 194958529 字节，SHA256 d18cf2d3435bf3fae3cda06f3be64ae4dbd29a3b8916ed98302b8a121c4a85e1。
- 参考恢复目标 D:\taptap\D3-visual-d584352-reference，当前不存在。独立恢复，不写 Downloads，不解压覆盖仓库。不使用旧增量包。
- 当前 .runtime-windows、.windows-runs、.tmp 是本机忽略数据；源分块、恢复目录、运行器、测试进度、Blender 源工程不提交。

## Implementation measures
1. 仅提交本基线行动记录，保留当前代码检查点。若出现新未提交改动，先在仓库外完整备份并核验，不能混入本次暂存。
2. 按已阅读的恢复脚本安全路径、分块哈希、整包 SHA256、ZIP CRC、项目清单验证逻辑，在新目录恢复完整包。
3. 比较本地、云端共同候选基线与完整包；写出精确新增/替换/删除清单与理由，不以包内缺失为删除依据。
4. 分阶段导入最新模型/贴图/位置/材质/灯光元数据及资源清单。引用检查通过后仅暂存资源与相关记录，保存资源提交；未适配加载前不宣称运行通过。
5. 逐项合并场景加载、灯光和点击适配，保留本地共享玩法装配/状态/UI。按原有八入口契约同步点击区域，保持包内确认的座钟、台灯、四原料构图，不另做美术设计。
6. 检查共享玩法、Lua/资源/点击契约、Windows 启动器；用本机官方运行器启动当前仓库，验证完整画面及实际鼠标交互。存档固定为隔离内存槽，不能读取或覆盖正式进度。
7. 按真实完成情况记录静态、启动、画面与鼠标验证，保存第二阶段相关提交和必要后续验证记录。失败/未验证明确标注。

## Affected file tree
- docs/actions/2026-10-15-d584352-visual-integration.md：本轮唯一仓库行动记录与分阶段结果。
- docs/evidence/d584352-integration/：精确导入清单、资源/代码检查及必要验收证据（不引入旧连续截图）。
- assets/v035-full：候选模型、贴图、场景元数据及哈希清单；精确文件表待恢复后生成。
- scripts/v035/lab35 与相关 3D 加载器：仅合并必要美术/加载/灯光/点击适配，精确文件表待比较后生成。
- 现行运行说明：完成后同步版本、操作步骤及验证边界。
- scripts/core、scripts/data、scripts/systems、scripts/ui 与根目录 v035：以本地为准；不被完整包的旧玩法副本覆盖。
- D:\taptap\D3-visual-d584352-reference：仓库外只读参考；不作为运行验收入口。

## Self-verification method
分块/ZIP/项目清单 SHA256 与 CRC；三方文件比较；资源引用与清单；现有 shared main 344 项隔离检查及相关变更测试；Lua 语法；Git 精确暂存与 diff --check；官方启动器 --check；Windows 窗口/日志/截图/加载时间/内存与实际输入记录。原生画面、真实鼠标和脚本替身检查分层报告。

## Self-verification results
Pending. 初始目录、分支、HEAD、干净状态、完整包下载文件数量已核对；未开始资源导入或运行验收。
