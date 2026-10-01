# scripts/ —— 游戏代码目录（UrhoX / Lua）

本目录是 Maker 工程的用户代码区，同时是 Lua 的模块根目录。

- 入口：`main.lua`，引擎调用其中的 `Start()` 与 `Stop()`
- 引用模块用点号路径，相对本目录：`require "systems.Potion"` 对应 `scripts/systems/Potion.lua`
- 引用引擎库：`require "urhox-libs.UI"`、`require "urhox-libs.Platform.PlatformUtils"`
- 资源引用相对 `assets/`，且不带 `assets/` 前缀：`Textures/letter.png`
- `urhox-libs/` 是只读参考副本，运行时使用引擎内置的同一份库，修改它无效

## 目录职责

| 目录 | 职责 | 对应设计文档 |
|---|---|---|
| `core/` | 事件总线、存档系统、GameFlow（天数/时段/阶段）、通用工具 | 系统模块拆分 ②⑭ |
| `data/` | 纯内容配置，不含逻辑：NPC、信件、地址、词条、材料、配方、商品、升级、案件证据、成就、身份规则、结局 | 系统模块拆分 ①Content |
| `systems/` | 玩法逻辑：Letter、Archive、WordToken、Potion、Order、Economy、Shop、WorldState、Narrative、Case、Identity | 系统模块拆分 ③～⑬ |
| `ui/` | 界面：打捞、读信与剪词、炼药、商店、信件档案桌、案件、结局 | 游戏大纲 十九 |
| `meta/` | 存档回溯节点、成就、结局记录 | 系统模块拆分 ⑭Meta |
| `debug/` | 调试面板：身份数值、世界状态、事件日志（仅开发期使用） | 身份与结局判定 十一 |

## 约定

- **内容与逻辑分离**：所有剧情、人物、信件、配方的数值与文案写在 `data/`，系统只读不写死剧情。
- **模块间通过事件通信**：跨模块协作走 `core/EventBus`，禁止 `Potion` 直接改 `Narrative` 的数据。
- **模块可整块删除**：删除任一系统不应破坏核心闭环。

完整模块说明见 `docs/寄往人间_系统模块拆分与依赖设计.md`，开发顺序与验收标准见
`docs/寄往人间_开发计划与验收标准.md`。
