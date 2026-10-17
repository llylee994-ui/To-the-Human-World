# 标题页替换与结局概念第二轮

基线：fc81a17。用户认可四格概念右下标题页，要求直接替换；指出离开结局的灰港屋顶不符合出发地，提出去看人间日出日落和四季流转；否定信纸中的“商人捎来的信”标题与愿望纸面材质。

## 实际修改

- `ui/landscape/TitleView.lua`：独立室内望海背景、左侧大标题和文字菜单，移除原右侧纸框、书本与两条说明文案。顶部标题与下方可滚动菜单分开，48 单位点击行，4:3 背景裁切左对齐保留木墙。原控件 ID、查询、继续、回顾、恢复、确认、留念和过期回调防护保留。
- `assets/image/title-screen-r1/shop-doorway.png` 与 `.meta`：从已认可构图重绘无字背景，实际尺寸 1672×941。文字通过 UI 绘制。
- `data/release_endings.lua` 与三结局正文：离开段落改为魔药铺灯光渐远、想看人间日出日落并走过春夏秋冬；没有修改任何玩家存档或旧留念。
- 学徒与愿望拼贴仅生成第二轮概念，没有改运行界面。店主信中不应出现叙事说明标题；新纸面方向为暖白信笺、轻折痕、自然纸边。概念文字与分类仅作示意。

## 验证

- `debug.EndingPresentationUITest`：5 passed / 0 failed，修改前后均运行。
- `debug.EndingPresentationTest`：12 passed / 0 failed。
- `python -X utf8 -B scripts/debug/run_release.py --suite ending-saves`：24 passed / 0 failed。
- Maker Lua LSP 对 TitleView 的 Error 诊断列表为空；`git diff --check` 通过。隔离检查不代表实际 Yoga 排版、鼠标或手机验收。
- 两个相关代码/资源批次后均查询官方 preview status，process_alive=false，保持停止。
- 独立代码复核发现原标题字号未计入 pt→px 的 4/3 换算，可能裁字；已降低字号并预留字距。最终标题文字宽度小于列宽，图片按实际 1672×941 比例左锚定裁切。修正后重跑界面检查和单文件诊断。

## 素材与边界

Maker edit_image 返回 INSUFFICIENT_BALANCE，execution_state=unknown，没有重试或报基础设施缺陷；随后通过会话内置 imagegen 生成。原标题素材保持不变。新背景已检查，原图存于 Codex generated_images，游戏引用项目内副本。

本轮无提交、推送或远端构建。没有启动停止的预览；标题实际窗口画面和触控仍未验证。离开场景的正式美术与演出仍属下一阶段，不把文案修正称为场景替换完成。

## 用户追加：轻微虚化并本地启动

用户随后明确要求暂停学徒与拼贴、给标题背景加一点虚化并本地启动。使用内置 imagegen 对无字背景作轻微柔焦，另存 `assets/image/title-screen-r1/shop-doorway-soft.png`（1672×941）及独立 meta，原图保留。仅 TitleView 的背景路径切换，真实标题与菜单仍清晰绘制。

代码/资源批次后官方 status 确认为 stopped，再按本次明确授权执行官方 console open 和 preview start。启动 session `111f2d21-665c-4161-82d1-5f9c903bf504` / reload 0 / runtime PID 9428，窗口保持开启。当前轮日志含数据校验与“寄往人间启动完成”；未见标题脚本错误。TitleView 单文件 LSP Error 列表为空。

通过既有只截图工具读取已核对 PID 的客户区，实际查看 1450×815 原生画面：背景轻微虚化，标题四字完整，英文副标题与“开始游戏”清晰可见。截图为 `docs/验证/evidence/title-screen-r1/native-title-soft.png`。没有代用户点击开始、推进经营或改存档。此证据支持标题显示，不替代交互和手机验收。

官方 preview check 仍返回 FAIL，错误为既有 `Cube/Day/DaySpecularHDR.dds` 缺失与 `themis_x64.dll` 加载失败；实际标题窗口正常显示，不宣称整体引擎检查通过。无远端构建或提交。
