# B 窗口商船组合层与原位叠加验收

## 状态与背景

- 任务编号：B-20261008-registered-merchant-layer；状态：Completed（组合层与实际叠加 QA 已交付，用户审美采用及游戏接入不在本轮完成范围内）。
- 用户要求：以无船版为底图，商船组合层包含船体、完整索具、倒影与附近水纹；允许少量周边水面，外围自然衔接。真实透明 PNG，画布与底图一致、船保持原位置，并附原位叠加预览检查接缝。
- 底图：[BG04 无船](../../scripts/素材/BG04_工作台融合海景_无船_v01.png)，941 × 1672，SHA-256 `633637BD2998CBE61B99207037D1CE3DA76B16829980378F9322735C426442AF`。
- 船型与位置参考：[BG04 有船](../../scripts/素材/BG04_工作台融合海景_有船_v01.png)，相同画幅，SHA-256 `BA284BCBDD035CF668F57C461E876B94DBCD6E2FE3E29D3BC009ACA5730BCA59`。
- 两张图已目视，属于注册在相同构图上的 AI 版本，局部笔触并非逐像素相同，因此不能把大块有船海景简单覆盖到底图而忽略接缝。
- 本轮只交付独立组合层及 QA 预览，不修改底图、不开发编辑器、不接入游戏，不向 C 自动派发。

## 实施措施

1. 内置 image_gen 以无船图作为水色与空间底准、有船图作为船型和坐标参考，制作全画幅透明层。
2. 组合层保留船和完整索具，连同倒影/近船水纹及少量海面；水面外沿柔和过渡到透明，窗口木沿前方不被船或水覆盖。
3. 核对真实 RGBA、尺寸与非透明内容边界。严格保持原位，不用把素材放大居中来替代全画幅要求。
4. 用最终 PNG 和未修改底图以 (0,0)、1:1、正常 alpha 直接渲染全幅叠加预览；预览是实际文件合成，不使用 AI 另画的结果充当接缝证据。
5. 为目视检查输出局部放大预览，检查船头/船尾、桅杆和索具、倒影、水面羽化边缘及窗沿遮挡；有明确问题则局部修正后重新原位合成。
6. 将组合层和预览放入指定素材目录，记录实际验证和供 A/C 交接的使用坐标。
7. 第三次内置编辑仍有画幅/坐标漂移，改在导出阶段做确定性的画布注册：使用 System.Drawing 对已生成的 RGBA 组合层等比缩放、移回原船坐标，并按底图窗沿做遮挡裁切。主体画面继续使用内置 image_gen 输出；本地不重画船、不改无船底图。最终 PNG 的预览仍严格在 (0,0) 按 1:1 叠加。

## 影响文件树

```text
docs/actions/2026-10-08-b-registered-merchant-layer.md          提示词、制作事实、接缝验收与交接
docs/设计/B窗口_分层素材规划_v01.md                          新组合层成果入口
scripts/素材/H18_商船组合层_原位_941x1672_v01.png               已输出：全画幅透明船/索具/倒影/水纹组合
scripts/素材/预览_BG04_商船组合层_原位叠加_v01.png              已输出：最终 PNG 在底图 (0,0) 的实际 alpha 合成
scripts/素材/预览_BG04_商船组合层_接缝放大_v01.png              已输出：原图、底图、透明层和实际合成的 2 倍放大对照
scripts/素材/过程稿/H18_商船组合层_AI提取_v03.png              AI 提取过程稿，仅供追溯，不是使用资产
scripts/素材/过程稿/检查_BG04_原船局部.png                    目视标记原船位置
scripts/素材/过程稿/检查_H18_生成局部.png                     目视标记生成稿位置
.tmp/b-merchant-layer/export-registered-merchant.ps1            本轮导出及实际叠加 QA 辅助脚本，不接入游戏
```

## 自验证方法

- 内置图像编辑制作主体素材；预览使用本地标准图像渲染将交付 PNG 直接叠在底图，制作验收证据。Python/Pillow 仅作读取、尺寸/alpha/差异统计，不生成或编辑素材。
- 组合层必须 941 × 1672，RGBA，大片非船区域 alpha=0；记录 alpha 范围、有效内容包围盒、边缘像素情况。
- 目视船仍在右侧原水面位置，桅杆顶部约 (625,397)，船身约 x546—689/y460—525；不能沿着整体画布居中或被任意缩放。
- 实际预览与底图在透明范围外应逐像素一致；不能出现室内木纹/椅子/天色被 AI 顺带改写。
- 局部检查无矩形水面块、双重海浪、亮边、索具截断，倒影与水线合理，窗沿遮挡正确。AI 修复与像素级严格对齐的实际局限如实记录。
- 保存哈希、完整输入及输出尺寸；源文件哈希保持不变；不以整图另生成替代原位 alpha 叠加验收。

## 自验证结果

- 最终导出：941 × 1672、RGBA，alpha 范围 0—255；1,561,565 个完全透明像素、11,694 个部分透明像素。画布四边 alpha 全为 0；有效内容包围盒 [502,396,724,533]（右/下界不含）。
- 坐标校准：第三稿等比缩放 0.617，平移 (207.291,68.756)，桅杆顶约 (625,397)，船身回到原图约 x546—689/y460—525 的区域。导出裁去窗沿前方内容，1.5 像素抗锯齿过渡；真实底图始终未改。AI 船型存在细节重绘，不声称与原有船图逐像素相同。
- 实际检查已执行：`export-registered-merchant.ps1` 直接读取交付 PNG，按 (0,0)、1:1、正常 alpha 合成；Pillow/NumPy 仅只读校验。透明区域外改变像素数 0，y≥550 的室内/桌面改变像素数 0；按 alpha 公式独立读取核对与预览最大差 1（整数混合舍入）。
- 已使用 view_image 查看全幅预览与 2 倍局部对照：桅杆、横桁、左右索具均可见，船仍在右侧原位置；局部水面无明显矩形拼贴边、粗亮边或索具截断；窗沿保持前景遮挡。倒影仅保留窗沿上方实际可见的一窄段，不补出穿过木头的长倒影。2 倍图可见 AI 船身线条比原船略清楚，属于重绘差异；原尺寸观感供用户最终选择。
- 源图 SHA-256 均与开始时一致。未运行 Maker/编辑器/游戏接入测试，因为本轮仅交付 B 小样与静态叠加检查。
- 输出文件：H18 54,238 字节，SHA-256 `5EB5B2158C62ED4FB2E6B51C0924A15A93EAE0A323A1BDB3C022C2AFDE28F083`；全幅预览 3,683,506 字节，`33EA42CE4575CAF03C7FF4D8B41213BAFF376F267DD6ED5446C5E21BF85CFA47`；局部对照 547,465 字节，`E84ADB298DA586E0152F74C61049E9976315490773A5363F81641BD40E0CE7C9`。

### 未采用的中间结果

- 第三次 `exec-c582fa19-d9a1-4366-a214-73c8ed46da0d.png` 为 941 × 1671 RGBA；索具及船型完整，但 alpha ≥16 包围盒 [488,530,828,777]，未满足原位。以原图桅杆顶与船身左右端作标记，导出时校准，完成后重新验收，不将原始生成稿作为合格交付。
- 第二次输出 `exec-6e6c97f8-f478-4e59-bea4-ad26078419f5.png` 为 981 × 1602 RGBA，尺寸与位置都不符。alpha ≥16 包围盒 [490,579,773,828]，未作为成果保存。改用有船整图作直接擦除目标，避免对漂移的透明稿继续迭代。
- 首次输出 `exec-7cf66f20-f106-42cd-a15a-c97687dfaae1.png` 是 941 × 1672 RGBA，画布正确，但船过大、位置偏下，不能交付。alpha ≥16 包围盒为 [492,489,810,776]，会覆盖目标窗台；局部海水还带有与底图船位不符的金色反光。
- 校正措施：以当前透明稿为编辑目标、原有船图和无船底图为校准参考，要求组合缩至 66.7%，桅杆顶回到约 (625,397)，并让水面退到窗沿后。后续须以真实原位预览核验，不能仅凭提示词判定通过。

## 工具与完整提示词

主体组合层：内置 image_gen，`transparent_background=true`；引用已目视的无船、有船两个输入。无 CLI/API 回退。

```text
Use case: compositing / background-extraction.
Deliverable: an IN-PLACE TRANSPARENT MERCHANT-BOAT COMPOSITE LAYER, not a new scene and not a centered isolated boat.

Image 1 is the authoritative NO-BOAT BASE BACKGROUND. It is 941 pixels wide by 1672 pixels tall. It fixes the canvas, registration, local water colors and window-sill occlusion.
Image 2 is the registered WITH-BOAT SOURCE. Extract/use the merchant boat at its EXISTING POSITION AND SCALE in this image, including its COMPLETE mast, furled boom/sail, every visible rigging rope, canopy, cargo, hull, reflection and nearby contact ripples. The boat points up-left toward the green-lit dock. Keep this exact design, viewpoint and heading.

CRITICAL CANVAS AND POSITION REQUIREMENTS:
- Output canvas MUST be exactly 941×1672 pixels, matching Image 1.
- DO NOT crop to the boat. DO NOT center, enlarge, rotate or relocate the boat. Leave the large empty areas of the full portrait canvas transparent.
- The visible boat stays in the upper-right window area, approximately x=546–689 and y=397–525 in the full canvas. The mast reaches about x=625,y=397; hull center about x=617,y=502. Use Image 2 as the exact positional reference, not a new design.
- Keep all visible mast-top, thin rigging and furled sail intact, including the ropes above and beside the canopy.

LAYER CONTENT AND SEAM:
Retain the complete boat together with its reflected dark hull shapes and adjacent short water ripples as ONE combined layer. A small irregular patch of surrounding sea is explicitly allowed so the reflection and ropes do not need a harsh cutout. Match this local water to Image 1's water exactly in color, brightness, wave direction and painted texture at the same position. Make the outer water-patch boundary fade naturally to alpha zero across a narrow soft irregular feather, following the wave shapes rather than a rectangular crop. There must be no hard rectangle, opaque beige/blue backing, colored halo or abrupt wave cutoff when alpha-composited onto Image 1 at (0,0).
Boat hull, cargo, canopy and mast remain solid and readable. Rigging edges are carefully antialiased. Reflection and ripple edges use appropriate partial alpha. Do not fade the boat itself as though it were a ghost.
The boat is close to the lower window sill. Respect the BASE window sill silhouette: the ship/water patch must stop behind it. Do not paint ship reflections, hull or water over indoor wood. Do not invent parts hidden behind the sill.

EVERYTHING ELSE IS TRANSPARENT:
No full ocean, landscape, dock, green light, village, sky, house, window frame, vine, desk, writing mat, chair, text or UI in the output. No other boat, no message bottle, no drop shadow outside the local water patch, no checkerboard and no black background.
Keep original fine painted illustration quality. Output REAL straight-alpha RGBA PNG. This full-canvas layer must add just the registered boat+rigging+reflection+ripples to Image 1 when placed at x=0,y=0, scale=1, rotation=0, normal opacity=1.
```

## 交接对象与汇报内容

### 原图直接擦除提示词

```text
Edit Image 1 by ERASING its background to real transparency. Image 1 is a 941 x 1672 portrait scene. Keep the ORIGINAL FULL CANVAS and the original small boat at exactly the same position and scale. Do not move, crop, center, enlarge or redraw the boat.

Keep only the existing boat in the window, its whole mast and all thin rigging ropes, the reflection and a little nearby sea water. The mast starts around (625,397), hull occupies x546-689, y462-525. Everything outside that small original region becomes fully transparent, including ALL wood, furniture, sky, mountains, village, plants and other scenery.

Image 2 is the no-boat background this layer will overlay at (0,0) without resizing. Match the small retained water patch to the water at the same location in Image 2. Gently feather the outer water edge to transparent, while retaining opaque boat details and the complete ropes. Water may only remain above the sloping window sill (approximately y534 at x550 to y525 at x690). No part of the wood sill may appear in the transparent output. Preserve the tiny amount of reflection actually visible above the sill; do not invent extra reflection below it.

This is background erasure with in-place preservation, NOT a new illustration of a boat. Output a real transparent PNG with the original 941 x 1672 full canvas.
```

### 首稿位置与水面校正提示词

```text
Use case: precise-object-edit.
Image 1 is the TRANSPARENT LAYER TO CORRECT (941×1672). Its boat is too large and too low.
Image 2 is the CORRECT BOAT POSITION/SCALE reference (the full with-boat scene).
Image 3 is the NO-BOAT BASE to blend against.

Make a precise registration correction to Image 1, keeping a 941×1672 RGBA canvas:
- Scale the existing boat+rigging+water group to 66.7% of its current size, without rotating.
- Translate the reduced group so the mast top lands at x=625,y=397. It currently lands near x=667,y=490.
- Consequently the boat hull must occupy approximately x=546–688,y=463–523, matching Image 2. The full transparent canvas must NOT be cropped or scaled.
- The final ship should be SMALL, exactly the size it was in the window of Image 2. Do not make an enlarged object presentation. Most of the image stays empty transparent.

Correct the surrounding water patch: retain only the nearby blue-gray water/reflection necessary around the hull, matched to Image 3 at this exact position. Remove the bright golden reflection streak on the LEFT of the patch; that reflection is not present at the boat's position in the base. Feather the remaining patch gradually into alpha zero, not a solid oval sticker. There is only a narrow strip of visible water below the boat before the window sill, so keep the reflection compact and physically plausible.
Use the actual window-sill silhouette of Image 3 as foreground occlusion: no alpha-visible ship/water pixels may cover the wooden sill. Near x=550 the sill begins around y=534, near x=690 it begins around y=525. Mask the water/reflection at this boundary; do not copy the sill itself into the layer.

Preserve ALL visible ship rigging, mast, furled sail, cargo, canopy and hull, at the corrected scale. Match Image 2's shape and heading as closely as possible. Outside this registered small ship/water area, every pixel must be transparent: no scene, dock, mountains, furniture, text, colored backdrop or checkerboard. Real RGBA PNG, exactly 941×1672.
```

- 交接对象：A 统筹与审查，由用户转发。
- 任务编号与参考版本：B-20261008-registered-merchant-layer，BG04 有船/无船 v01。
- 用户已确定：同画幅、原位置、真实透明；船体/索具/倒影/附近水纹组合，允许海面柔和过渡。
- B 建议：该组合层保持与底图注册的坐标，只切换显示/透明度；带有周边水面的组合层不作为可随意拖动到别处的船体切片。
- 本轮成果：[真实透明组合层](../../scripts/素材/H18_商船组合层_原位_941x1672_v01.png)、[实际原位叠加](../../scripts/素材/预览_BG04_商船组合层_原位叠加_v01.png)、[接缝放大](../../scripts/素材/预览_BG04_商船组合层_接缝放大_v01.png)。主体由内置 image_gen 制作，最终采用上方“原图直接擦除提示词”，再按记录的参数导出注册；无 CLI/API 回退。
- 待决定：用户对原位叠加的视觉验收。
- 如果采用，C 在底图上以左上角 (0,0)、原尺寸 941 × 1672、旋转 0、正常透明混合显示；同一整体缩放应用于底图和组合层。
