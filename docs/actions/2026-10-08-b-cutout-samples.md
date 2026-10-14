# B 窗口三件透明素材小样

## 状态与背景

- 状态：Completed（3 张透明小样已交付，尚未由用户确认或作为正式素材验收）。2026-10-08，用户明确要求先提取钱袋、提灯、植物画框的透明底小样。
- 任务范围：H15 钱袋、H26 提灯、H27 植物图鉴画框各一张；风格和形态来源为 `scripts/主页原型_晨雾魔药铺_v03.png`。
- 使用内置 image_gen 的 background-extraction 编辑模式，分别输出真实透明背景。AI 编辑可能重绘局部细节，不承诺原像素级无损抠图。
- 产物为供用户审看的设计小样，不自动成为正式美术或进入编辑器；不修改源图、代码、运行数据或 C 的文件。
- 钱袋去除数值纸签及纸签上的图标；提灯保留灯体和内部火苗，去掉原环境与外投影；植物画框保留框内纸面和植物图案，只去除外部木墙背景。

## 实施措施

1. 沿用已目视的原图，三个物件分别通过内置 image_gen 编辑，不把三个物件拼成一张素材。
2. 将三张输出原样保存到项目内，保留透明通道；按用户后续指示统一迁入 `scripts/素材/`。
3. 读取 PNG 格式、尺寸和 alpha，检查真正透明而非画出的棋盘格；目视核对物件、完整边缘、残留背景与明显风格变化。
4. 在聊天展示三张图片；记录实际生成结果和局限，供用户反馈与转交 A。

## 影响文件树

```text
docs/actions/2026-10-08-b-cutout-samples.md                  本记录及最终提示词
scripts/素材/H15_钱袋.png                                独立透明钱袋
scripts/素材/H26_提灯.png                                独立透明提灯
scripts/素材/H27_植物画框.png                            外框外透明，框内纸面保留
docs/设计/B窗口_分层素材规划_v01.md                      补充三张小样的结果入口
```

素材规划中的数量与候选分类保持不变，新增本次小样入口；本次实际制作结果以本记录为准。

## 自验证方法

- 目视原图与输出，检查对象身份、轮廓、原有配色和线描；确认钱袋无数值标签，画框纸面没有误抠透明。
- 读取三张 PNG 的模式、尺寸、alpha 极值、透明/半透明/不透明像素数量及非透明包围盒，检查画布边缘透明。
- 检查复制前后哈希一致、源图未改动。
- 不运行网页编辑器、Maker 预览或手机验收，不把透明小样视为已接入资源。

## 自验证结果

- 内置 image_gen 三次独立编辑均成功；输出已按原始字节复制到项目设计小样目录，未通过代码修改图片。
- 已目视三张输出：钱袋无数值纸签；提灯包括完整提环、灯体、蜡烛与火苗；画框保留纸面、植物和顶部悬挂结构。
- 忠实度限制：钱袋的绳结、币面图案与皮纹有重绘；提灯的金属、蜡烛和玻璃细节被重新诠释；植物画框的花叶排布及装饰细节也有变化。三张是 AI 提取重建小样，不是原像素抠图，不能据此声称完全还原。
- Python/Pillow 只读检查通过：三张均为 RGBA PNG，实际存在大量 alpha=0 像素；没有用实色底或画出的棋盘格代替透明。alpha 的 240—255 区间视为近乎不透明，不把 253/254 误认成严重缺失。

| 素材 | 尺寸 | 完全透明像素 | 近乎不透明像素（alpha 240—255） | 画布边缘 alpha 最大值 |
|---|---|---:|---:|---:|
| H15 钱袋 | 1187×1326 | 905149 | 645526 | 1 |
| H26 提灯 | 1024×1536 | 949818 | 598591 | 1 |
| H27 植物画框 | 1024×1536 | 875028 | 677992 | 1 |

- 透明边界限制：三张的画布边缘均存在极低 alpha=1 残留；不是已完成生产级净边的资源。提灯玻璃在不同底色上的穿透感未做合成实测。
- 画框纸面抽样点 alpha 均不低于 240，纸面未误抠为空洞。
- 复制前后 SHA-256 相同；源图 SHA-256 仍为 `541efc5052131534a35673fbbc6adae645a073245bd2c3b8cd7ddd249c096625`，源图未改动。
- 三张文件 SHA-256：钱袋 `8659ac677ae9ca867a237e3b3802c9ca90d8d155fb16e47cb2d3f805ce18a1aa`；提灯 `28529cd0c5c84bbbe0e854d35c77cf521673aa3af64ac8247b35029bd96901e0`；画框 `03d43c13cc7dfcdfb02476663bb4143090c31bbce2eaeddad80b6ce3213b33d2`。
- 未运行排版编辑器、Maker 或手机验收；未批量扩展其他素材。A 可审查此小样，C 尚未收到制作指令。

## 成果路径

- [H15 钱袋](../../scripts/素材/H15_钱袋.png)
- [H26 提灯](../../scripts/素材/H26_提灯.png)
- [H27 植物画框](../../scripts/素材/H27_植物画框.png)

## 素材目录调整

- 2026-10-08 用户指定：以后本项目图片统一放在 `D:\taptap\To-the-Human-World\scripts\素材`。
- 状态：Completed。上述三张 PNG 已从原设计小样目录移入指定目录，未改图像内容，未移动其他历史原型或 C 的文件。
- 检查方法：核对源/目标绝对路径均在项目内，目标无同名文件后逐文件移动；移动后检查三张 SHA-256 与原记录一致，并检查文档成果链接可解析。
- 检查结果：通过。三张目标文件的 SHA-256 均与原记录相同，旧目录中对应三文件已不存在，三个成果链接均可解析；新的交付目录约定已同步到 B 的素材规划文档。

## 提示词与工具

工具：内置 image_gen；三次独立编辑；每次 `transparent_background=true`，引用同一原图路径。以下为完整调用提示词。

### H15_钱袋

```text
Use case: background-extraction.
Input image 1 is the EDIT TARGET, the user's existing vertical illustrated seaside apothecary homepage, not merely a style reference.
Deliver exactly ONE isolated existing object from this image as a transparent RGBA PNG cutout for a layered layout editor. Preserve the source object's recognizable shape, proportions, viewpoint, fine dark hand-drawn contours, muted painted colors, and existing material treatment as closely as possible. Do not redesign, modernize, embellish, or turn it into a 3D product render. Only minimally reconstruct an edge where background removal requires it.
Target: the BROWN DRAWSTRING MONEY POUCH attached to the wooden wall at the UPPER RIGHT of the source image, above the small white label marked 0. Extract ONLY this one pouch, including its gathered leather neck, ties, and the round gold/brass coin ornament on the pouch itself. REMOVE the white hanging price/balance label below it, the 0 text and the coin icon on that label. Remove the wall, hooks belonging to the wall, all neighboring objects and every cast shadow from the old wall. Keep the pouch brown with its original illustrated leather folds; do not add piles of coins or extra strings.
Composition: center the complete pouch upright, with its original orientation and a modest transparent margin on all sides; fit the canvas reasonably closely to the object. Background must be truly alpha-transparent, including any gaps between ties. No white background, no painted checkerboard, no caption, no border, no watermark.
```

### H26_提灯

```text
Use case: background-extraction.
Input image 1 is the EDIT TARGET, the user's existing vertical illustrated seaside apothecary homepage, not merely a style reference.
Deliver exactly ONE isolated existing object from this image as a transparent RGBA PNG cutout for a layered layout editor. Preserve the source object's recognizable shape, proportions, viewpoint, fine dark hand-drawn contours, muted painted colors, and existing material treatment as closely as possible. Do not redesign, modernize, embellish, or turn it into a 3D product render. Only minimally reconstruct an edge where background removal requires it.
Target: the BRASS CANDLE LANTERN standing at the LOWER RIGHT edge of the window, on the sill just above the tools cup and the drawer. Extract ONLY this one lantern with its complete top carrying handle, domed ventilated cap, vertical metal frame, glass enclosure, base, candle and small existing warm flame. Match its original viewpoint, silhouette and restrained amber-brown colors. Remove all wooden sill and wall, leaves, tools, neighboring objects and cast ground shadows. Clear the old room/sea colors visible through the glass; use true partial alpha transparency for the glass where appropriate while keeping subtle glass tint, the candle and flame. Open gaps in the top handle must be transparent. No new halo or external glow, no larger flame, no electric bulb, no extra candle.
Composition: center the entire upright lantern, complete handle to base, with modest transparent margins and no clipping. Background must be truly alpha-transparent, not a painted checkerboard or solid color. No caption, no border, no watermark.
```

### H27_植物画框

```text
Use case: background-extraction.
Input image 1 is the EDIT TARGET, the user's existing vertical illustrated seaside apothecary homepage, not merely a style reference.
Deliver exactly ONE isolated existing object from this image as a transparent RGBA PNG cutout for a layered layout editor. Preserve the source object's recognizable shape, proportions, viewpoint, fine dark hand-drawn contours, muted painted colors, and existing material treatment as closely as possible. Do not redesign, modernize, embellish, or turn it into a 3D product render. Only minimally reconstruct an edge where background removal requires it.
Target: the TALL NARROW WOODEN BOTANICAL PICTURE FRAME at the UPPER LEFT of the source image, above the paper date label. Extract ONLY this existing frame and its interior botanical illustration: slim brown wood frame, cream paper, the same white daisy-like flowers, olive-green stems and leaves, and its small visible hanging loop above. Preserve the original design, tall rectangular proportions, fine ink-like lines and painted paper surface. The cream paper INSIDE the frame must remain opaque: it is part of the object and must NOT be removed. Remove all surrounding wooden wall, the separate date paper below, hanging herbs beside it, wall cast shadows and any neighboring objects. Do not add flowers, text, decorative carvings or a different frame.
Composition: center the complete upright frame including its small hanging loop with modest transparent margins. Only the area OUTSIDE the frame and the hole in the hanging loop should be transparent. True alpha transparency, no checkerboard drawn into the image, no solid background, no caption, no watermark.
```
