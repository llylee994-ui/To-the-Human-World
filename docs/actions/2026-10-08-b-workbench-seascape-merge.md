# B 窗口工作台去投影与窗外海景融合

## 状态与背景

- 任务编号：B-20261008-workbench-seascape-merge；状态：Completed（去桌面投影与海景融合的有船/无船两版均已交付）。
- 用户要求：去掉现在工作台上的阴影，将新附件的窗外风景融合到当前图片窗口，输出有船和无船两版。
- 图 1 / 室内编辑底稿：[BG03 无捞网 v03](../../scripts/素材/BG03_工作台_透明窗景_无捞网_v03.png)，保留大书写垫、椅子布、攀藤、桌柜与窗框。
- 图 2 / 窗外景色供体：附件 `C:/WINDOWS/TEMP/codex-clipboard-43f5ef5b-65fa-41f2-9d38-e813efff9e5d.png`。仅取海天、山村、绿光码头和商船，不移入该图的木屋、窗扇或托盘。
- 两张输入已用 view_image 目视。图 1 SHA-256：`D175D761DBC5FF504E73BA146EBDC27B93085C31C033A2F5DCD5FC31C36806FB`；附件 SHA-256：`FC70E8985C25F9C4775395E54E0E483901C63217C0BAAEFBC54C5770F1319A5D`。
- 阴影范围：桌面和书写垫上的叶影、斜向窗框暗带及残留物件投影；补成均匀柔和光照，保留材质纹理和垂直结构本身的体积明暗。
- 窗口由透明区域变为融合后的不透明景色；输出是两张完整背景，不覆盖原 BG03 场景层。
- 使用内置 image_gen，输出 `transparent_background=false`。不改生产代码、正式布局或 A/C 文件，不将输出自动认定为最终美术规范。

## 实施措施

1. 原样保留附件参考副本到素材目录。
2. 以图 1 为室内主底稿、图 2 为窗外供体，先制作无桌面投影的有船融合版。
3. 逐区检查去影、窗口衔接、海景透视、室内结构保留与船朝向；需要时仅针对明确问题局部修正。
4. 用通过检查的融合版作为输入，仅去船体/桅杆/索具/专属水影，制作无船版以保持构图一致。
5. 将两版保存至指定素材目录，核对尺寸、模式、完整性、复制与源文件哈希；更新 B 规划入口及交接记录。

## 影响文件树

```text
docs/actions/2026-10-08-b-workbench-seascape-merge.md        本轮事实、完整提示词和检查
docs/设计/B窗口_分层素材规划_v01.md                       最新融合背景成果入口
scripts/素材/参考_待融合海景_v01.png                      已保存：本轮用户附件原样副本
scripts/素材/BG04_工作台融合海景_有船_v01.png               已交付：去桌面投影、有船的完整背景
scripts/素材/BG04_工作台融合海景_无船_v01.png               已交付：同构图无船背景
```

## 自验证方法

- 目视桌面和垫子无树叶剪影或窗框斜向暗带，木纹、缝线及暖色保留。
- 目视海景在原窗形内，前景攀藤遮挡关系正确，无透明黑洞、双框或亮色碎边；海景比例合理，不上下挤压船与山村。
- 核对室内仍为 BG03：大垫、椅子布、攀藤、抽屉/桌柜；不从参考图带入托盘等已去除物件。
- 有船版保留朝绿光码头的篷船，无船版清除全部船体、索具、桅杆与水影，绿光码头保留。
- Pillow 只读检查尺寸、模式及透明度；两版应同画幅、完整不透明。Get-FileHash 对照缓存与输出、输入参考保持原样。
- AI 融合包含补绘，不承诺两版未改区域逐像素一致；本轮不做游戏或编辑器接入验收。

## 自验证结果

- 两次内置 image_gen 调用完成，无额外返工或 CLI/API 回退；有船版用两张参考图融合，无船版从有船版局部去船。
- 逐区目视通过：桌面/垫子的叶影和斜向暗带消除，垫边缝线、木纹和暖色保留；室内沿用 BG03 的大书写垫、椅子布、攀藤、窗框、桌柜，未带入参考图托盘或窗扇，未恢复已移除道具。
- 目视海景完整填入原透明窗洞并位于攀藤后；窗沿无黑洞或亮色杂边。供体海景按较短窗口重新取景/补绘，山村、塔楼、绿光码头与夕照保持可辨；不是原海景逐像素搬移。色温和小纹理有 AI 重绘变化。
- 有船版保留小篷船且船头朝向绿光码头；无船版船体、桅杆、索具和专属船影消除，绿光及码头保留。两版桌面去影结果均保持。
- Pillow `Image.open/load` 检查两张均为 941 × 1672、RGB PNG、不透明。有船版 2,210,144 字节；无船版 2,153,922 字节。比 BG03 输入高度多 1 像素，未另作缩放。
- 有船生成缓存 `exec-96b74a16-37ca-46e5-86a9-d66a8a2b2c31.png` 与交付 SHA-256 均为 `BA284BCBDD035CF668F57C461E876B94DBCD6E2FE3E29D3BC009ACA5730BCA59`。
- 无船生成缓存 `exec-754ce673-f9be-45e4-99a7-9d72c675df68.png` 与交付 SHA-256 均为 `633637BD2998CBE61B99207037D1CE3DA76B16829980378F9322735C426442AF`。
- Get-FileHash 核对 BG03 源图仍为 `D175D761DBC5FF504E73BA146EBDC27B93085C31C033A2F5DCD5FC31C36806FB`，附件参考副本为 `FC70E8985C25F9C4775395E54E0E483901C63217C0BAAEFBC54C5770F1319A5D`；均未覆盖修改。
- 两版画幅及主构图一致，但细微海浪/木纹/笔触并非逐像素相同，未做无跳变背景切换验收。未进行编辑器、Maker 或手机接入。

## 工具与完整提示词

内置 image_gen；有船版同时引用两个已目视输入，无船版引用已完成的有船版；两次顺序执行，均 `transparent_background=false`，无 CLI/API 回退。

### 有船融合版

```text
Use case: compositing.
Asset type: one finished opaque portrait game homepage background.
Image 1 is the PRIMARY EDIT TARGET and authoritative indoor scene: the cleaned workbench with a large pale writing mat, chair with cloth, climbing vine, empty wooden shelving, and a transparent upper window; no net, calendar, lamp or loose props.
Image 2 is an OUTDOOR SCENERY DONOR ONLY: use its view through the window (misty blue-gray sea, peach-gray clouds and low warm sun, layered mountains, foggy shoreline village and hilltop tower, the green-lit dock, and small covered merchant boat). Do NOT transfer Image 2's room, window framing, shutters, thick dark beams, tabletop or wooden tray.

Perform these two changes:
A. Remove all cast shadow patterns from the TOP of Image 1's workbench and writing mat. Erase the leafy silhouettes across the left side of the mat and tabletop, broad diagonal/window-frame dark bands, and any lingering prop shadows. Repaint the same wood grain and pale mat texture with smooth, even, soft warm ambient illumination over the entire horizontal working surface. No leaf-shaped shadows, hard sun patches or striped light/shadow boundaries. Keep natural material color variation, seams, stitches and the mat's drawn edge. Preserve depth shading on vertical desk faces, drawer and chair; do not flatten their three-dimensional form.
B. Fill the transparent window opening of Image 1 with a naturally integrated version of ONLY Image 2's outdoor scenery. Reframe the landscape for Image 1's wider, shorter window opening without squashing or stretching the mountains, village or boat. Adapt scale and crop coherently so there is sky above the misty coast and a readable area of water in front; keep the green beacon/dock and a small merchant boat on the right-side water visible. Boat keeps its same canvas canopy, cargo barrels/crates and heading up-left toward the green-lit dock, with a restrained water reflection. Do not bring any floating message bottle into the scene.
Keep the original window shape, posts and sill from Image 1. Fit the scenery completely behind the retained vine leaves, including their small gaps. Match the soft hand-painted detail and distance contrast of Image 1, keeping the sea cool and the room warm. Blend window-edge colors cleanly: no black window fill, transparent gaps, bright red/yellow edge speckles, pasted rectangles, double frames or halo around the vine. Maintain a coherent water plane and viewing height from the seated workbench viewpoint.

STRICT INVARIANTS: The ENTIRE indoor layout, camera and perspective are from Image 1. Keep its large pale rectangular stitched writing mat, desk and drawer, chair and draped botanical cloth, climbing vine, foreground leaves and shelves in their original position, size and form. Preserve the original portrait framing, aiming for 941×1671. Do not add a tray, paper, UI, words, calendar, lantern, net, books, cauldron or any prop. Apart from removing tabletop cast shadows and filling the window, preserve Image 1's room appearance. No zoom, new decorations, heavy contrast or style redesign.
Deliver ONE full opaque PNG WITH the merchant boat. No transparency anywhere in the finished combined background.
```

### 无船融合版

```text
Use case: precise-object-edit.
Input image is the EDIT TARGET: the finished fusion of the clean pale-mat workbench and misty seaside view, with one small merchant boat near the green-lit dock.
Make the matching NO-BOAT version by removing ONLY the whole merchant boat and its dedicated water reflection/shadow/contact wake. Remove the hull, cargo, canopy, mast, furled sail and EVERY rigging line, including thin remnants extending above the canopy. Reconstruct uninterrupted blue-gray sea and the tiny underlying shore areas as needed, using adjacent natural painted water strokes.
Keep the green beacon, its green reflection, the real wooden dock and short dock posts. Do not confuse any boat mast with a dock post. The window must contain no boat, floating bottle or ghost hull/mast/wake.
Preserve ALL remaining content of the edit target as closely as possible: exact portrait framing and dimensions; the soft warm room; the cleaned evenly lit tabletop and pale stitched mat with NO leafy/diagonal cast shadows; desk, chair and cloth, vine, shelves, window frame and sill; sky, mountains, fog, village, tower and water outside the boat patch. Do not reintroduce tabletop shadows, removed objects, text or a tray. No zoom, crop, camera shift, style change, new objects or transparency.
Deliver ONE full opaque PNG WITHOUT a boat, otherwise matching the with-boat background.
```

## 交接对象与汇报内容

- 交接对象：A 统筹与审查，由用户转发。
- 任务编号与参考版本：B-20261008-workbench-seascape-merge，BG03 无捞网 v03 + 新附件 43f5ef5b。
- 用户已确定：去掉桌上投影，当前室内与附件窗外景色融合，有船/无船各一版。
- B 推荐：有船先融合，再局部去船；桌面采用均匀光照，便于以后叠放独立物件。
- 本轮成果：[有船融合版](../../scripts/素材/BG04_工作台融合海景_有船_v01.png)、[无船融合版](../../scripts/素材/BG04_工作台融合海景_无船_v01.png)，均已保存和核验；此前背景和独立捞网保留。
- 待决定：用户对融合、去影效果的视觉验收。
- 如果采用，C 按 A 审查结果使用完整背景，保持主场景视角；活动素材匹配该水面/桌面透视，不能据示意图认定到访逻辑已经实现。
