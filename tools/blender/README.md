# Blender 编辑与导出工具

从旧完整导出包迁移的 8 个编辑、烘焙、导出、重建和校验脚本。原始映射与诊断保存在 `mappings/baseline-65e640c`，这些是基线资料，**不代表当前 100 模型候选的完整重新构建配方**。当前运行资源始终以 `assets/v035-full` 为准。

- `D3_BLENDER_SOURCE`：由操作者指定现有 `.blend` 文件绝对路径。脚本禁止执行嵌入脚本，不保存回源文件。
- `D3_BLENDER_OUTPUT`：必须是本仓库 `.windows-runs/blender/<独立批次>` 的子目录。输出只进暂存区，不会发布到当前资源目录。
- `mappings/import_group_plan.json`：从保留的原 `groups.json` 重建语义分组；修改源工程后先核对新增/删除物体。
- `mappings/interaction-contract.json`：从当前候选提取的 8 入口代理和契约；不再依赖已移除的旧小样导出路径。

有 Blender 和源工程时，使用 Blender 后台 `--python` 依次执行 `prepare_full.py`、`camera_reference.py`、`bake_full.py`、`export_full.py`，再用 Python 执行 `complete_contract_metadata.py`、`validate_full.py`、`check_projection.py`。可用 Blender 执行 `rebuild_full_json.py` 做重建观察。所有步骤使用同一个新输出目录；完成元数据后才运行验证。

当前源工程在本仓库之外，本轮未读取、修改或重新导出它。迁移只验证语法、路径约束、映射完整和原相机投影；未声称 Blender 端到端重导出通过。云端后续法线修复、材质调整及新增架子原料仍需在未来重导出任务中逐项合并；禁止用本基线脚本产物直接覆盖 `assets/v035-full`。
