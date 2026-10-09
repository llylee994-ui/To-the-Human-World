# B 窗口固定背景清理：有船与无船两版

## 状态与背景

- 任务编号：B-20261008-clean-background-pair；状态：Completed（两张背景已交付，尚未进行正式美术采用或游戏接入）。
- 用户要求：擦除花瓶、所有功能/状态纸条、托盘里的漂流瓶与信件、画纸、书本、挂画、钱袋、干花及除托盘之外的全部室内物件；交付有船、无船两张背景。
- 最新要求覆盖此前“抽屉瓶先保留”：本轮托盘/抽屉内必须清空，保留空托盘本体及自身五金。
- 编辑底稿：[商船朝向绿光码头 v02](../../scripts/素材/主页原型_v03_商船朝向码头_v02.png)，本轮已目视。历史修订见[此前行动记录](2026-10-08-b-merchant-and-fixed-background.md)。
- 保留范围：木屋、窗框/窗扇、窗台、桌子、固定结构阴影、空托盘和现有窗外景色；有船版保留当前船型及朝向，无船版仅移除商船及专属水影。
- 本轮提取的是完整不透明背景，不是透明抠件。不重新设计海景，不覆盖源图，不改生产代码或 A/C 文件，不进行游戏接入。
- 已沿用项目 AGENTS.md 与 project-control-report、action-document、imagegen 技能；本轮查询 docs/scripts 下无新增嵌套 AGENTS.md（rg 无匹配返回 1，不是工具故障）。

## 实施措施

1. 基于同一 v02 先制作有船清理背景，逐项去掉室内道具和 UI，补全背后材质。
2. 目视检查清除完整性与空托盘、窗框、桌面透视；必要时仅局部修正残留。
3. 用已清理的有船背景作为第二次编辑输入，只去掉商船及船影，获得构图尽量一致的无船版。
4. 保存两个版本到用户指定 `scripts/素材`，保留原型及此前小样。
5. 核验文件、尺寸/模式、复制哈希及视觉要求；更新 B 规划和交接记录。生成结果不代表正式采用。

## 影响文件树

```text
docs/actions/2026-10-08-b-clean-background-pair.md          本轮执行事实、提示词与检查结果
docs/actions/2026-10-08-b-merchant-and-fixed-background.md  追加后续提取入口，历史结果保留
docs/设计/B窗口_分层素材规划_v01.md                       最新背景输出和用户决定入口
scripts/素材/BG02_木屋海景_空托盘_有船_v01.png             已交付：干净有船背景
scripts/素材/BG02_木屋海景_空托盘_无船_v01.png             已交付：同构图无船背景
```

## 自验证方法

- 逐区目视：两上角无干花；左右柱无挂画、钱袋和日期；窗台无花瓶、灯和纸牌；桌面无书、布、画纸、杯钵、工具、叶片或按钮；托盘内无瓶、信、标签；仅保留空托盘。
- 核对托盘框沿及内部连续，窗框/桌面/木纹合理，清除物件投影没有明显残影；保留固定结构阴影。
- 有船版核对船头朝绿光码头，无船版核对桅杆、船体、篷顶、货物、水影一并消除，码头和绿光保留。
- Pillow 只读检查 PNG 尺寸/模式；两版预期完整不透明、画幅相同；SHA-256 比较缓存与交付，源 v02 保持 `BD55E9C09ED05261BACADF7C216315964147EB578963C295327D7AB0353241BE`。
- AI 补绘可能带来细微笔触差别，检查结果按实际记录，不承诺未编辑区域逐像素相同。
- 不涉及代码，未安排 Maker、编辑器或手机运行检查。

## 自验证结果

- 内置 image_gen 共调用三次：有船版清理一次、无船版去船一次、无船版桅杆残留修正一次；未进行 CLI/API 回退。
- 已逐区目视：两版均无挂画、钱袋、花瓶、干花、书本、布、画纸、提灯、杯钵工具、文字纸条及功能按钮；托盘内部无瓶、信封和标签，保留托盘框沿及自身铜色拉手。被遮挡的墙、窗台和桌面已补绘；未见明显物件形状残影或纸牌矩形。
- 固定木屋结构、窗框窗扇、桌面及原窗外景色保留。木柱少量嵌入式五金细节仍在，不作为独立装饰物拆除。背景清理不改变既有场景的山村、日轮等内容。
- 有船版保留当前船头朝向绿光码头；无船版首次返回仍有桅杆细线，追加局部清理后目视船体、桅杆、索具及专属水影已消除，码头与绿光保留。
- 两张均已保存到 `scripts/素材`。Pillow `Image.open/load` 检查通过：两张均 942 × 1670、RGB PNG、不透明。有船版 2,566,603 字节；无船版 2,495,723 字节。
- 有船版来源 `exec-8c8e0e24-1a9c-452e-9478-c9b9d587617b.png`；缓存与交付 SHA-256 均为 `7C131995990C0D554F0B7D87C239E530F8531BE9201ECD3BC4088609FEA8499A`。
- 无船版来源 `exec-07de990a-1e9f-4bc6-a263-667f9bd09eb7.png`；缓存与交付 SHA-256 均为 `69A2275A752D151593396067AC12A9FFD1C1BB00CEF86B142895FA1248B18FFE`。
- 使用 `Get-FileHash -Algorithm SHA256` 复核源 v02 仍为 `BD55E9C09ED05261BACADF7C216315964147EB578963C295327D7AB0353241BE`，原型未覆盖。
- AI 清理包含补绘；两版画幅与主要结构一致，但细小木纹、海浪和岸景笔触有差异，未承诺或验证逐像素一致。未做背景切换动画、编辑器、手机或 Maker 运行验收；本次仅交付两张背景。

## 工具与完整提示词

内置 image_gen；两次均为 `transparent_background=false`。第二张依赖第一张检查通过的清理结果，顺序执行以降低构图差异。无 CLI/API 回退。

### 有船背景：清除室内物件与文字

```text
Use case: precise-object-edit.
Asset type: clean opaque background plate for the SAME portrait game homepage.
Input image 1 is the EDIT TARGET. Remove ALL loose indoor props, decorations, paper signs and UI labels, keeping only the original wooden room architecture, window, workbench and the EMPTY wooden tray/open drawer. Retain the outdoor scenery and the merchant boat exactly as in this image.

REMOVE COMPLETELY:
- Both hanging herb/flower bundles at the upper window corners, their hanging ties and attachments that belong to the decorations.
- Botanical framed picture and its hanging hook on the upper left wooden post.
- The money pouch, coins and its paper number tag on the upper right post.
- The left hanging paper "第1天 清晨", including its clip/hook.
- The vase/jug and ALL flowers, stems, leaves and small sprigs; all dried flowers anywhere.
- The lantern and its localized glow, all books, stacked books, cloth/table runner, loose botanical art papers, paper sheets, loose foliage, pen/tool cup and every implement in it, mortar/bowl and contents, side containers, loose sticks/rods, rope coils and all other separate indoor objects. Clear BOTH table edges and the window sill completely.
- EVERY paper UI label/button/sign and its clip, icon and text: "海上来信 · 2", the large "打捞" sign and net drawing, all "待处理" labels, "词条", "炼药", "结束当天", "未开瓶", every number and any remaining paper rectangle.
- The upright glass message bottle INSIDE the wooden tray/open drawer, its cork/string and rolled letter; the envelope, wax seal, paper tags and all tray contents. The user now explicitly wants this tray EMPTY.
There must be NO indoor props remaining except the empty wooden tray/open drawer itself. No writing, printed illustrations, blank paper sheets, ghost labels or shadows from removed objects.

PRESERVE:
- Exactly the original wooden wall posts, top beam, open window frame and open shutters, window sill, fixed workbench planks and desk structure, their original perspective, proportions, grain and structural shadows.
- The rectangular EMPTY wooden tray/open drawer in the lower center, in its original position and size, with its original rim, inner wood bottom, front wall and small brass pull/nameplate hardware; do not erase, close, move or replace it. Its brass hardware is part of the tray, not a removable prop.
- The entire existing outdoor misty sea, sky, warm distant sun, mountains, village, green beacon and dock, rock edges, and specifically the one covered merchant boat pointing up-left toward the green dock. Keep the boat design, placement, scale, heading and reflection unchanged. No floating bottles.
Reconstruct the surfaces formerly hidden by removed objects: continuous matching wooden planks on walls, sill and tabletop, sea/sky behind herbs and flowers, and complete empty wood inside the tray. Match perspective, contour lines and painted wood grain without rectangular cutout seams or smudged object silhouettes. Retain the general warm indoor ambient light and cool sea, but no isolated lamp-shaped glow after removing the lantern.
Match the source's hand-drawn fine dark contours and softly painted materials. This is scene cleanup, not a new room design. Preserve full portrait framing and aim for the same 942×1670 size. No crop, zoom, style change, invented furniture, new props, watermark, text, transparency or checkerboard. Deliver ONE full opaque clean background WITH the merchant boat.
```

### 无船背景：从有船底图局部去船

```text
Use case: precise-object-edit.
Input image 1 is the EDIT TARGET: the already cleaned wooden seaside room background with an empty wooden tray/open drawer and a single merchant boat outside.
Create the matching NO-BOAT background by changing ONLY the small region occupied by the merchant boat and its boat-specific reflection/contact ripples. Remove the entire ship: hull, cargo, canopy, mast, rigging and furled sail, and erase its shadow/reflection/wake. Reconstruct uninterrupted blue-gray water and fine natural horizontal wave strokes seamlessly through that region, matching nearby water and perspective.
Preserve ALL other pixels/composition as closely as possible: original wooden posts and beam, open window and shutters, empty sill, clear tabletop, the EMPTY wooden tray/open drawer with its brass pull, all wood grain, structural shadows, misty sea outside the removed boat patch, sky, mountains, village, green dock beacon, wooden dock and its reflection. Do not remove the dock or its green light. Do not add or restore any indoor props, flowers, hanging herbs, framed picture, pouch, lantern, papers, books, text, bottles or envelope. There must be no ships and no floating bottles.
The two backgrounds should look like the same fixed camera scene with only the boat absent. Keep exactly the same full portrait framing, dimensions, lighting, fine drawn contours, colors and painted textures as the edit target. No zoom, crop, restyling, new objects, transparency, watermark or checkerboard. Deliver ONE full opaque clean background WITHOUT a boat.
```

### 无船版局部修正：桅杆与索具残留

第一张无船输出 `exec-8f76187e-4635-4534-9e26-ab94d47cbbd2.png` 的船体已移除，但原船桅杆区域仍有细线残留；暂未复制为最终交付。以下修正仅清除残留，保留码头和绿光。

```text
Use case: precise-object-edit.
The input is the nearly finished NO-BOAT clean background. Fix ONLY the leftover ship mast and rigging; the ship hull was removed but these thin traces remain.
In the right half of the window, just right of the green-lit wooden dock, around x=580–685, y=470–650 in this 942×1670 image, remove the tall thin vertical pole/mast at about x=630, its diagonal rigging lines, and its vertical water reflection. These belonged to the deleted merchant boat, not to the dock. In particular, erase the thin mast rising beside the distant right shoreline buildings and any ghost ship lines continuing down through the water. Repaint the small underlying shore/harbor and blue-gray water areas with continuous matching texture. There must be no isolated tall pole, spar, ropes or ship remnants in this cleared area.
Preserve the actual low wooden dock with its short posts, the GREEN beacon to the left of this area and its green water reflection. Preserve the sky, mountains, village, all other sea, the wooden room architecture and open window, clear tabletop, empty tray and brass handle, original perspective, composition, lighting, colors and exact canvas dimensions. Do not restore any indoor objects, paper labels, text, bottles, letters, flowers or ships. No crop, zoom, transparency, new objects or style change. Full opaque PNG; same no-boat background with only these mast/rigging remnants cleaned away.
```

## 交接对象与汇报内容

- 交接对象：A 统筹与审查，由用户转发；任务编号与参考版本见上文。
- 用户已确定：空托盘以外室内物件全部移除；固定结构与海景合并；输出有船和无船两版。
- 本轮成果：[有船背景](../../scripts/素材/BG02_木屋海景_空托盘_有船_v01.png)、[无船背景](../../scripts/素材/BG02_木屋海景_空托盘_无船_v01.png)，均已保存并完成本轮图像检查。
- B 推荐：两版用同一清理底图衍生；若需要到访动画，优先使用无船版作为固定底层，船另作与当前视点相符的动态层。
- 待决定：用户对清理和补绘效果的视觉验收；此处不新增到访规则。
- 如果采用，C 使用完整背景并锁定空间关系；数值、功能物件和活动素材另叠。两版先按独立背景看待，不假设生成结果能逐像素无跳变切换。
