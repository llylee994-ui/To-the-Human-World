# 《寄往人间》宣传素材

本目录保存原文件副本，不覆盖游戏资源。实机图为项目已有截图，未重新操作游戏或手机；部分 UI 属于截图当时的版本，不代表 2026-10-18 最新界面。

| 文件 | 来源/说明 |
|---|---|
| 01-主页-实机存档.png | docs/验证/evidence/harbor-chrome-r3/chrome_r3_home-clean.png；包含旧 UI 和平台胶囊 |
| 02-海边-实机存档.png | docs/验证/evidence/ship-reflection-r1/fullscreen_r2_seaside_20x9.png；包含旧 UI |
| 03-炼药工作台-实机存档.png | docs/验证/evidence/story-reveal-r1/brew_native_prepared.png；包含配料状态与 UI |
| 04-标题页-纯背景.png | assets/image/title-screen-r1/shop-doorway-soft.png；当前 TitleView 引用 |
| 05-共用海面-纯背景.png | assets/image/misty-harbor-r1/sea-calm.png；当前 SeaArt 引用 |
| 06-主页-透明室内前景.png | assets/image/misty-harbor-r1/home-foreground.png |
| 07-海边-透明码头前景.png | assets/image/misty-harbor-r1/dock-foreground.png |
| 08-炼药-透明药炉.png | assets/image/brew-topdown/cauldron-v01.png |
| 09-炼药-透明原料托盘.png | assets/image/brew-topdown/four-cell-tray-v01.png |
| 10-游戏图标-漂流瓶-v01.png | 本轮内置 image_gen 新生成，1254×1254 RGB，无文字；未设置为线上游戏图标 |

当前主页由共用海面、室内前景和 LayoutManifest 中的独立物件叠加；海边由共用海面、码头前景、商船和漂流瓶叠加。炼药工作台复用室内场景，并绘制药炉、原料托盘、词条栏和记录书。因此这些画面的完整效果并非一张纯背景文件；宣传需要整页时，可使用上方实机存档或另行制作无 UI 合成版。

图标生成：内置 image_gen，非 CLI；参考当前标题背景和 assets/image/seaside-r1/bottle.png。完整提示词见 icon-prompt.txt。原始生成文件保留在 Codex generated_images，项目内保存原字节副本。
