# B 窗口主页右侧层架延长与草药装饰

## 状态与背景

- 任务编号：B-20261009-right-shelf-background；状态：Completed（背景与真实含船预览已交付，视觉采用仍由用户决定）。
- 用户要求：修改附件背景，右边架子延长一点，加入干花草药、配方图等，统一风格。
- 附件 `codex-clipboard-0fe4b19c-c05b-48cd-a919-da25f2ad5eb1.png` 为 941 × 1672 RGB；与既有欧洲商船缩小版的实际叠加预览 RGB 像素完全相同，已只读核实。
- 因当前已采用无船背景 + 独立商船层的制作流程，本轮编辑 BG04 无船 v01 的右侧架子，再按原坐标叠回已交付 H18 欧洲船 v02，交付更新背景与含船整图预览。只生成一种层架方案，旧背景/船层不覆盖。
- 用户已明确要延长架子并添加草药/配方图；B 的本次具体实现为右侧中、下两块层板向左适度延伸，草药与图纸形成两个疏密不同的小组。该摆法是候选，不自动冻结正式规范。
- 适用 AGENTS 沿用前轮已读且未更改版本；scripts/docs 未发现子级 AGENTS。已读取 project-control-report、imagegen、action-document。
- 不修改生产代码、正式排版或游戏状态，不直接向 C 派单。

## 实施措施

1. 将用户附件原样归档；内置 image_gen 仅编辑右侧窄木墙的层板和陈设。
2. 层板左端约 x815—830，不侵入 x770 左侧的窗洞；延续木板厚度、透视、木色和局部接触阴影。
3. 上层少量干花及绑绳草药，下层植物配方图和一只小草药瓶；保持木墙留白，不把桌面重新摆满，不在书写垫上加投影。
4. 检查完整画幅和局部风格。必要时仅取 AI 修改的右墙区域注册到原无船底图，以确保海景、船位和桌面不随整图生成漂移。
5. 以现有 H18 欧洲船 v02 在 (0,0)、1:1 正常 alpha 合成含船预览，检查右侧装饰是否遮窗、透视是否连贯、桌面是否空净。
6. 保存到指定素材目录，更新本行动记录与 B 素材入口；不改其他窗口已新增的器物记录。

## 影响文件树

```text
docs/actions/2026-10-09-b-right-shelf-background.md         本轮范围、完整提示词、验证和交接
docs/设计/B窗口_分层素材规划_v01.md                       新增背景候选入口
scripts/素材/参考_右侧层架修改前_v01.png                   用户附件原样归档
scripts/素材/BG05_工作台_草药配方层架_无船_v01.png         已输出：更新的无船背景
scripts/素材/预览_BG05_草药配方层架_欧洲商船_v01.png        已输出：原船层真实叠加的整图预览
scripts/素材/预览_BG05_右侧层架_局部_v01.png               已输出：层架局部对照验收
scripts/素材/过程稿/BG05_右侧层架_AI编辑_v01.png           已归档：内置编辑原稿
.tmp/b-right-shelf/export-shelf-background.ps1              已执行：区域注册/预览辅助，不接入游戏
```

## 自验证方法

- 对源附件、BG04 无船和 H18 船层读取尺寸/哈希。用 view_image 目视输出完整画面和右侧局部。
- 最终背景与预览均 941 × 1672，背景不透明；核对右侧层板确实延长，内容有草药/干花和配方图，木色、纸色、笔触与画面协调。
- 如区域注册，则只取右木墙修改，海景/桌面等区域与原底图保持逐像素一致；若未注册且有 AI 重绘偏差则如实记录。
- 预览必须是当前背景与现成船层的真实 alpha 合成；船层哈希不变，不把重新生成的有船整图当成船层可用性证据。
- 本轮为美术候选静态检查，不运行 Maker 构建或游戏行为测试。

## 自验证结果

- 内置 image_gen 输出 `exec-39fb037e-a277-4313-ba2b-277aef6b1c5c.png`，941 × 1672；两块层板左端约 x815/820，较原来约 x900 明显延长，新增支撑、干花陶罐、草药束、植物配方纸和一只草药瓶。上层同时上移约70像素，下层接近原高度，形成疏密不同的两组陈设；这是具体候选排法，未据此认定用户已经批准层板高度。
- 首稿右墙外也有轻微 AI 重绘：右墙外 x<780 的 RGB 平均绝对差 2.815/255，书写垫抽查区域差 1.261/255。为保持上一轮船层注册和桌面纹理，最终只保留右墙区域的编辑，其他像素使用原底图。
- 已执行 `export-shelf-background.ps1`：按原位取生成稿右墙，左/上边界在裸木处柔和过渡，底端沿桌面上缘停止。首轮下边界在裸木中出现可辨接痕，已移至实际桌沿并重导、重新目视核验。
- 最终无船背景与含船预览均为 941 × 1672 RGBA，alpha 全255（不透明背景）。背景改变74,884个像素，包围盒 [807,77,941,641]（右/下界不含）；设定右墙范围外改变像素0，桌面/书写垫/前景 y≥650 改变像素0。实际含船预览相对用户附件在右墙外也改变像素0，因此原船、天空、村庄、海面与室内其余区域均保留原样。
- 已用 view_image 查看全幅含船图及2倍左右对照，并在桌沿接痕修正后重新查看局部：层板有厚度与托撑，器物接触关系清楚；草药与纸张颜色低饱和，右侧窄墙仍有空隙；未遮挡窗洞或在桌面添加物件/新投影。配方纸仅为图案与小注记笔触，不是已校对的可读配方内容。
- 预览由最终背景和原 H18 v02 文件按 (0,0)、1:1 实际 alpha 合成；Pillow/NumPy 只读校验与公式最大通道差1（整数舍入）。BG04 无船哈希仍为 `633637BD2998CBE61B99207037D1CE3DA76B16829980378F9322735C426442AF`；H18 船层仍为 `1540713D01E01BB8BABB5599B4A2C17BB3363ABEF40E33E5D5611C465AEA1A07`。
- 最终 BG05 3,694,924字节，SHA-256 `0DA66503F3AD15A1708D3C4DCDAF2BE2BEDF9F684E7D7CB4A4EE0193B4FDACF2`；含船预览3,702,931字节，`C2C12D826BC8A72BE4265AB08CA51EDC821053D1C923675A751EC4DA72E31C03`；局部对照596,678字节，`61CBE65D1F8289D3E928263AEDCA3A5401303E0832457018E454358F29DCE24E`。
- 未修改生产代码/正式布局，未运行 Maker 构建或游戏行为测试；本轮证据为静态图像及文件合成核验。

## 工具与完整提示词

内置 image_gen，`transparent_background=false`；输入 BG04 无船 v01，已目视。无 CLI/API 回退。

```text
Use case: precise-object-edit.
Edit the supplied vertical hand-painted seaside cottage workbench background. Output the SAME 941 x 1672 full portrait composition.

CHANGE ONLY THE RIGHT-HAND WOODEN SHELVES AND THEIR CONTENTS, in the narrow indoor wall strip to the right of the window.
The two currently tiny shelf ends visible at the extreme right (around y320 and y500) should extend moderately farther LEFT into the right-hand wooden wall, becoming usable little shelves. Their left edges should remain around x815-830, safely to the RIGHT of the window opening at about x770. Keep the wall, window opening and room proportions in place. Do not widen the room or cover the seascape. Match existing shelf plank thickness, honey-brown wood, perspective and joinery; give each believable subtle support and soft contact shadow.

Add a small, naturally arranged apothecary grouping:
- On the upper extended shelf, one modest plain earthenware container holding a few dried stems and tiny muted cream/dusty lavender flowers, plus one small bundle of sage-colored dried herbs tied with simple twine and resting/draping at the shelf edge.
- On the lower shelf, one or two slightly overlapping warm ivory botanical recipe sheets propped against the wall, with delicate drawings of herb leaves, a small potion-vessel sketch and a few faint handwritten annotation strokes. These are decorative recipe illustrations, not readable UI text or a big sign. A single small unlabelled amber herb jar beside them is enough.
Keep the arrangement sparse and asymmetrical with visible bare wood and breathing space. Objects must sit on the shelf, not float. Keep all contents within the right-hand room strip. Do not add an entire wall of jars or oversized flower bouquets.

STYLE MATCH:
Use exactly the existing soft painted illustration style: restrained fine edges, matte ochre/honey wood, desaturated olive and sage leaves, muted dried flower heads, pale parchment. Warm evening illumination consistent with the picture, low-contrast local contact shadows; no glossy metallic trim, exaggerated wear, crisp vector art, bright UI labels or strong halo highlights. The shelves are quiet secondary decoration, with less contrast than the main window/sea view.

PRESERVE ALL ELSE:
Keep the entire outdoor sunset, mountains, village, green dock light and sea unchanged. Keep the left vine, window frame and sill, whole desk, ivory writing mat, chair/cloth and drawer unchanged. Do not add anything onto the desk or mat and do not cast new leafy shadows there. Do not add any ship: the existing separately saved merchant layer will be composited back at its original coordinates afterwards.
No camera move, zoom, canvas crop or change in scene proportions. Full opaque PNG, exactly 941 x 1672.
```

## 交接对象与汇报内容

- 交接对象：A 统筹与审查，由用户转发。
- 任务编号与参考版本：B-20261009-right-shelf-background；用户附件、BG04 无船 v01 + H18 欧洲商船 v02。
- 用户已确认：右侧架子延长，摆放干花草药/配方图，风格统一；尚未确认本轮具体摆法。
- B 推荐：只在右侧墙上形成两组小陈设，配方纸低对比，保留桌面和窗洞的阅读空间。
- 本轮成果：[BG05 无船背景](../../scripts/素材/BG05_工作台_草药配方层架_无船_v01.png)、[含船整图](../../scripts/素材/预览_BG05_草药配方层架_欧洲商船_v01.png)、[层架局部对照](../../scripts/素材/预览_BG05_右侧层架_局部_v01.png)。内置 image_gen 一次编辑生成，经右墙区域注册导出；完整提示词见上。
- 待决定：层架延伸量、陈设密度的视觉验收。
- 如果采用，C：背景替换为本轮无船图，现有 H18 欧洲商船 v02 继续按 (0,0) / 941 × 1672 原位叠加。陈设烘焙在固定背景，装饰配方图不作为可读运行时文本。
