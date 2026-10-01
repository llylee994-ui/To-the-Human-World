# 《寄往人间》 To the Human World

叙事经营 + 轻推理 + 配方组合 + 多结局游戏。

玩家经营一间位于“人间之外”海岸边的魔药铺：打捞漂流瓶、阅读来信、从信中裁剪词条、炼制魔药、
按“字面要求”完成订单并寄回人间。在满足陌生人愿望的过程中，信件、地址与人物后续会逐渐拼出
一桩谋杀案的真相，以及玩家自己的身份。

> TapTap 游戏比赛主题：**涌现**
>
> 核心句：**魔药从不理解愿望，它只理解文字。**

---

## 设计文档

| 文档 | 内容 |
|---|---|
| [游戏大纲草稿（更新版）](docs/寄往人间_游戏大纲草稿_更新版.md) | 核心概念、玩法循环、漂流瓶/词条/魔药/商店系统、多结局结构、比赛版本原则 |
| [系统模块拆分与依赖设计](docs/寄往人间_系统模块拆分与依赖设计.md) | 14 个模块的职责与输入输出、事件总线、分期开发计划、推荐目录结构 |
| [主线案件角色档案与完整故事线](docs/寄往人间_主线案件角色档案与完整故事线.md) | 灰港谋杀案、核心角色档案、真凶与线索链 |
| [五类玩家身份与结局判定规则](docs/寄往人间_五类玩家身份与结局判定规则.md) | 倾向值 + 身份证据 + 身份确认 Gate 的判定公式与权重建议 |
| [开发计划与验收标准](docs/寄往人间_开发计划与验收标准.md) | 阶段划分、每阶段的验收标准、风险与对策（**开工先看这份**） |

---

## 技术方案

使用 **TapTap Maker**（UrhoX 引擎 / Lua 脚本）开发，工程已绑定 Maker 项目「寄往人间」。

- 引擎：UrhoX —— Lua 脚本 + NanoVG 矢量绘图 + Yoga Flexbox 布局（`urhox-libs/UI` 提供 45 个控件）
- 入口：`scripts/main.lua`（实现 `Start()` / `Stop()`），起手模板为 `templates/scaffold-2d.lua`
- 模块引用：`require "systems.Potion"` 对应 `scripts/systems/Potion.lua`
- 资源引用：相对 `assets/` 且不带前缀，例如 `Textures/letter.png`
- 存档：`File` API（项目 + 用户双重隔离）+ `cjson`
- 远端构建 / 提交：Maker MCP（`maker_build_current_directory`）
- 本地窗口预览：`taptap-maker preview run --target-dir "D:\To the Human World"`

代码目录（`scripts/README.md` 有各目录与设计文档模块的对应表）：

```text
scripts/
├─ main.lua        入口
├─ core/           事件总线、存档、GameFlow、工具
├─ data/           内容配置（NPC / 信件 / 地址 / 词条 / 材料 / 配方 / 商店 / 案件 / 结局）
├─ systems/        玩法逻辑：Letter / Archive / WordToken / Potion / Order / Economy /
│                  Shop / WorldState / Narrative / Case / Identity
├─ ui/             界面：打捞 / 读信与剪词 / 炼药 / 商店 / 信件档案桌 / 案件 / 结局
├─ meta/           存档点、成就、结局记录
└─ debug/          调试面板（身份数值、世界状态、事件日志）
assets/            美术、字体、音频资源
docs/              设计文档与开发计划
```

> 开发顺序与每阶段的验收标准见 [开发计划与验收标准](docs/寄往人间_开发计划与验收标准.md)。

---

## 仓库说明

| 远端 | 地址 | 用途 |
|---|---|---|
| `github` | `git@github.com:llylee994-ui/To-the-Human-World.git` | 设计与代码主仓库（本仓库） |
| `origin` | `https://maker.taptap.cn/git/76909fb8-...` | Maker 远端构建与提交 |

> 说明：Maker 会接管 `origin` 远端，因此 GitHub 使用独立的 `github` 远端名，两者互不干扰。
> 日常推送用 `git push github`；提交构建走 Maker MCP 的 `maker_build_current_directory`。

`CLAUDE.md`、`AGENTS.md`、`urhox-libs/`、`engine-docs/`、`examples/` 等为 Maker 安装到本地的
AI 开发辅助资料，已通过 `.gitignore` 排除，不入库。
