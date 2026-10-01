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

---

## 技术方案

计划使用 **TapTap Maker**（UrhoX 引擎 / Lua 脚本）开发：

- 引擎：UrhoX —— Lua 脚本 + NanoVG 矢量绘图 + Yoga Flexbox 布局（`urhox-libs/UI` 提供 40+ 控件）
- 入口：`scripts/main.lua`
- 远端构建 / 提交：Maker MCP（`maker_build_current_directory`）
- 本地窗口预览：`taptap-maker preview`
- 引擎能力：2D/3D 渲染、物理、音频、网络、本地存档（`File` + JSON，项目/用户双重隔离）

开发目录规划（绑定 Maker 工程后按此建立，对应设计文档的模块拆分）：

```text
scripts/          游戏逻辑（Lua）
  ├─ core/        事件总线、存档 / 回溯、GameFlow
  ├─ data/        内容配置：NPC / 信件 / 地址 / 词条 / 材料 / 配方 / 案件 / 结局
  ├─ systems/     Letter / Archive / WordToken / Potion / Order / Economy / Shop /
  │               WorldState / Narrative / Case / Identity
  └─ ui/          读信 / 炼药 / 信件档案桌 / 商店 / 案件 / 结局
assets/           美术、字体、音频资源
docs/             设计文档（当前目录）
```

---

## 仓库说明

| 远端 | 地址 | 用途 |
|---|---|---|
| `github` | `git@github.com:llylee994-ui/To-the-Human-World.git` | 设计与代码主仓库（本仓库） |
| `origin` | 由 `taptap-maker init` 绑定后自动指向 Maker | Maker 远端构建与提交 |

> 说明：Maker 会接管 `origin` 远端，因此 GitHub 使用独立的 `github` 远端名，两者互不干扰。
