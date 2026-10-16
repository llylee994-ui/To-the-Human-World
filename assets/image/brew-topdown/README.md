# 俯视炼药素材 v01

2026-10-16，按用户认可的四格俯视托盘概念稿生成。使用内置 image_gen 工具（imagegen skill），不是 CLI/API 脚本。Maker 上一轮已返回 INSUFFICIENT_BALANCE，本轮没有重试 Maker 生图、改变服务环境或生成远端映射。

- `cauldron-v01.png`：1448×1086 RGBA，alpha >16 的可见框 `(97,37)-(1352,1054)`；仅药锅，无炉腿、工作台、UI 或文字。
- `four-cell-tray-v01.png`：2087×753 RGBA，可见框 `(27,122)-(2061,605)`；正交俯视、三道木隔板、四个空格及四块空白标签。物品和名称由 UI 另行绘制。
- 两图 alpha 范围均为 0–255，未用脚本改图/去底，保留原生透明度。
- 参考：用户认可的 `exec-1732f9b7-6d31-479e-99cc-d5c6f171f67d.png` 概念稿。原始生成文件保留在本机 Codex generated_images；当前目录为游戏正式引用的副本。

## 生成提示词

### 铜锅

Extract/recreate ONLY the high-angle copper cauldron from the reference as one production-ready 2D game sprite on a genuinely TRANSPARENT background (real alpha). Match this approved painterly illustration exactly in identity: warm hammered copper broad rim, dark antique copper bowl, two copper ring handles, visible golden amber potion with sparse chamomile, leaves, petals and tiny ripples. Camera clearly looking down about 60 degrees, potion surface takes most of the sprite; retain a modest amount of rounded outside pot wall and the full double handles. Complete standalone cauldron, lower bowl has a natural rounded closed bottom; no tall legs or furnace. All edges fully visible with a small transparent margin. Center it large in a landscape 4:3 canvas. Do not include any background, tabletop, parchment, UI, text, labels, ingredient inventory, tray, smoke, glow haze, or opaque ground shadow. Preserve natural fine antialiasing on transparent edges, no white or checkerboard background. One cauldron asset only.

### 空四格托盘

Extract/recreate ONLY the four-cell wooden ingredient organizer from the reference as one production-ready UI frame sprite with a genuinely TRANSPARENT background (real alpha), EMPTY compartments. Strict orthographic 90-degree top-down view. One complete long horizontal rectangular walnut shallow tray with four equal cells in ONE ROW separated by exactly THREE straight wooden divider boards. Outer top and bottom edges parallel, side edges parallel, all four corners right-angle in screen space; NO trapezoid perspective and NO visible outside front/side wall fascia. Beautiful detailed warm brown grain, raised rounded wooden rim, dark recessed wood bottom in each cell, subtle interior shadows and small brass corner pins. Rectangle width-to-height about 5:1. All four cells EMPTY so code can independently place interactive ingredients. Preserve four small cream parchment name plaques lying flat on the lower rim, one per cell, but plaques must be completely BLANK, NO letters or digits. Wide landscape canvas, tray fills almost all image width and height with small transparent outer margins. Do not include pot, ingredients, bowl, vial, herb, pouch, flowers, background, tabletop, labels/text, UI, buttons or drop outlines. This is the single empty flat wooden four-compartment tray frame, consistent with the reference game's painterly handpainted look.
