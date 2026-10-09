# B 窗口原图七件透明素材提取

## 状态与背景

- 任务编号：B-20261009-seven-source-cutouts；状态：Completed（七件透明 PNG 和实际合成总览已交付，用户审美采用与游戏接入不在本轮完成范围内）。
- 用户提供附件 `codex-clipboard-7290d4b3-eab8-450b-8c16-608ed3ff1be6.png`，要求提取小灯、药炉（蒸汽和阴影）、草药半圆盆、蓝书、小日历（阴影）、墙挂档案袋；随后补充木托盘，内有零散词条、字迹各异但不可辨认，保留内部阴影。当前共七件，均需独立透明 PNG。
- 已目视源图。灯、药炉、草药盆、蓝书及托盘部分被画面边缘裁切，需要局部补全；包含 AI 重建，不声称是原图逐像素无损裁剪。
- 本轮蓝书指画面最右侧小蓝书，不是下方中央厚皮书；小日历按本附件日翻页与“第1天”提取，不覆盖另一轮已制作的月格日历。
- 图片仍放 `scripts/素材`，已有器物 v01/v02 和背景不覆盖。不修改正式布局、代码或游戏状态，不直接向 C 派单。
- 适用 AGENTS 沿用已读未变化版本；scripts/docs 未发现子级 AGENTS。已读取 project-control-report、imagegen、action-document，并核对既有器物清单。

## 实施措施

1. 归档用户附件，七件分别调用内置 image_gen（真实透明），共用源图和材质规范；每次只生成一件，避免整张素材板混抠。
2. 药炉保留全套炉座/火/勺及半透明蒸汽、投影；小日历保留投影；托盘保留内侧暗部和纸条接触阴影。
3. 逐件核对 RGBA、透明外部、物件完整性；药炉检查蒸汽是否留下、盆与蓝书检查补全是否忠于可见设计；档案袋保留袋组自身挂件，不带木墙。
4. 输出灰/浅色底检视图，核对阴影和蒸汽的真实半透明，而非背景色块；七件分别保存，并制作总览。
5. 记录实际生成结果、保存路径和限制，更新 B 素材规划入口。

## 影响文件树

```text
docs/actions/2026-10-09-b-seven-source-cutouts.md          本轮事实、逐件提示词和验收
docs/设计/B窗口_分层素材规划_v01.md                     最新候选入口
scripts/素材/参考_七件器物提取原图_v01.png               用户源图归档
scripts/素材/H26_桌面小油灯_透明_v02.png                  已输出：灯
scripts/素材/H09_药炉_蒸汽阴影_透明_v03.png                已输出：药炉组合
scripts/素材/H30_草药半圆盆_透明_v01.png                  已输出：盆及草药
scripts/素材/H31_蓝色书本_透明_v01.png                    已输出：右侧蓝书
scripts/素材/H14_小台历_含阴影_透明_v03.png                已输出：日翻页台历
scripts/素材/H17_墙挂档案袋组_透明_v01.png                已输出：档案袋组
scripts/素材/H10_木托盘_零散词条内阴影_透明_v03.png        已输出：托盘及纸条
scripts/素材/预览_七件器物透明素材_v01.png                已输出：实际透明 PNG 合成总览
.tmp/b-seven-cutouts/render-overview.ps1                   已执行：总览渲染辅助，不修改源 PNG
```

## 自验证方法

- Python/Pillow 仅只读检查像素尺寸、alpha 范围、透明量、边界及哈希；图片生成/编辑使用内置 image_gen，不调用 API/CLI 回退。
- 实际预览使用标准图像渲染合成最终 PNG，目视完整对象与关键细节：小灯玻璃、药炉蒸汽/脚下阴影、盆内草药、蓝色封面、小日历投影、档案挂环、托盘内暗部和不同不可读字迹。
- 不将展示底色写回素材，不把真实透明与显示器黑色预览混淆。保留源图，记录补全与文本烘焙限制。
- 本轮为静态美术输出，不执行 Maker 构建或运行时接入测试。

## 自验证结果

- 七件分别生成并复制到指定目录；均为 RGBA PNG，包含大片 alpha=0 的背景。直接保留生成 alpha；没有把工具黑底/金色晕影显示当成不透明素材。七张画布边缘最大 alpha 均为1/255，存在极低透明度残留，未粗阈值清除以免损伤蒸汽/投影；主要外部区域完全透明，灰底预览未见可辨背景边。
- 已运行 Python/Pillow/NumPy 只读检查尺寸、alpha和 SHA-256，见下表。源附件与归档字节相同，哈希 `FA981ED2FEA03E55F21CEBF838BA66DD85C26893FF3C4D57F8404276C2941504`。
- 蒸汽抽查区域 y60—439/x420—849 内 alpha8—239 的像素68,764个；药炉下投影抽查有11,658个此范围像素，小台历下投影抽查19,988个，确认半透明效果实际保存在 PNG 中。
- 已用 `render-overview.ps1` 将最终七个 PNG 在棋盘底上真实 alpha 合成并用 view_image 查看：小灯独立完整，药炉蒸汽透出底色且脚下有软投影；草药盆有完整口沿和叶束；蓝书是蓝色封面；小日历“第1天”及下方投影保留；档案组挂环通透、未带木墙；托盘的不同方向纸片上字迹各异、不可读，内缘和角落仍有下沉阴影。
- 总览只裁取预览区域并等比缩放展示，各 PNG 文件保持完整原画布；棋盘格未写入素材。总览为1200 × 1530，SHA-256 `A9ADC50FF05981ABA8A2C224EFC3749FDFD1DBDEBD87E0CFE89AFD8506992EC6`。
- 局限：原图边缘缺失的器物部分含 AI 重建，尺寸为独立素材分辨率，不承诺与原场景逐像素对齐。日历“第1天”是原图文字的静态保留，未替代上一轮月历或运行时日期逻辑。未运行 Maker 构建/游戏行为测试，未修改正式布局。

| 素材 | 像素尺寸 | 完全透明像素 | SHA-256 |
|---|---|---:|---|
| 小灯 | 1024 × 1536 | 1093320 | `1815C4552782C5B0BB8DCF907A7238816BE9E552A9B5710C851D3CF78602F3CB` |
| 药炉 | 1146 × 1373 | 913463 | `D4F0909A654EB478DA8EC7298AFD1E651009C5E464AE1EF2987CBD747078BFB9` |
| 草药盆 | 1536 × 1024 | 1056077 | `0B36B4878E2431E737AF7B22CECC5D2D0B65053BB0020D6A20CEDC50E40A66FF` |
| 蓝书 | 1536 × 1024 | 1019111 | `58E04871BCE27625D05A7B93B957731E91B669AA2DE199C7B412E1AEAB30A780` |
| 小日历 | 1402 × 1122 | 948259 | `5AD14211E0FF8C959364D76ECDDBFCEBE189BC242876645AFCBF45031EA2996B` |
| 档案袋组 | 1098 × 1432 | 879178 | `1B724E5BE5E9936CCAC2A9D943C56B3941DDE1C5EB472B5A0EA1E7482D8362F6` |
| 词条托盘 | 1536 × 1024 | 775189 | `D2E059BE1E610592930EAD91CF5EFC6D760609E732357BA30B500E2D5432B091` |

### 内置生成源文件追溯

- `H26_桌面小油灯_透明_v02.png` ← `exec-28c08eee-c879-43a2-b829-2e57fa1ce13d.png`。
- `H09_药炉_蒸汽阴影_透明_v03.png` ← `exec-70bbef18-caf6-4190-be90-5ed960beade2.png`。
- `H30_草药半圆盆_透明_v01.png` ← `exec-90fe624a-67e3-4b1b-b946-44b064ceb070.png`。
- `H31_蓝色书本_透明_v01.png` ← `exec-fc5262f1-0426-461b-87a3-0658699bff78.png`。
- `H14_小台历_含阴影_透明_v03.png` ← `exec-60ee80ad-8c48-472a-aeb3-b46025a1f970.png`。
- `H17_墙挂档案袋组_透明_v01.png` ← `exec-58b89d2b-3567-4c37-932b-c0efaeb76d71.png`。
- `H10_木托盘_零散词条内阴影_透明_v03.png` ← `exec-0dfde4a9-3b6f-4f0d-b08c-2ccec5fc91b1.png`。

## 工具与完整提示词

全部使用内置 image_gen，`transparent_background=true`，源图为用户本轮附件。

### 小灯

文件：`H26_桌面小油灯_透明_v02.png`

```text
Use case: background-extraction / precise-object-edit.
Input is the user's hand-painted seaside workbench illustration (941 x 1672). Extract/reconstruct ONLY the requested object as ONE independent asset on REAL TRANSPARENT RGBA PNG. Preserve the source's object design, warm painted texture, restrained fine linework, material colors, original three-quarter viewpoint and light direction. Do not redesign it as a glossy photoreal product or a flat icon.
Remove ALL room, wood tabletop grain, ocean, writing mat, nearby objects and unrelated decorations. If the object is partly outside the source frame, complete only the missing continuation of its own shape consistently, so it is usable as a whole cutout. Do not recreate a rectangular patch of the source background.
Keep the object centered with sufficient completely transparent margin on all sides; no cropped extremities. Preserve antialiased edges and genuine transparency through openings and glass. Do not draw a checkerboard, opaque white/beige/black ground, labels or watermarks. Shadows, where requested below, must be neutral translucent shadow pixels fading to alpha zero, not a painted table surface.

TARGET: the SMALL BRASS OIL LAMP at the extreme LEFT table edge, approximately x0-62,y715-985. It has a circular brass foot, a narrow transparent cylindrical glass lantern/chimney, a small burning wick and brass cap/fittings. This is the table lamp, NOT the hanging bell at upper right. Complete the clipped left side into a full symmetric lamp while preserving its source proportions and side view. Keep glass softly transparent, warm local highlights and the tiny flame; exclude the nearby flower vase, leaves, calendar and desktop. No broad glow backdrop or detached shadow sheet; only a very small soft contact shadow if needed. One lamp only.
```

### 药炉（蒸汽与阴影）

文件：`H09_药炉_蒸汽阴影_透明_v03.png`

```text
Use case: background-extraction / precise-object-edit.
Input is the user's hand-painted seaside workbench illustration (941 x 1672). Extract/reconstruct ONLY the requested object as ONE independent asset on REAL TRANSPARENT RGBA PNG. Preserve the source's object design, warm painted texture, restrained fine linework, material colors, original three-quarter viewpoint and light direction. Do not redesign it as a glossy photoreal product or a flat icon.
Remove ALL room, wood tabletop grain, ocean, writing mat, nearby objects and unrelated decorations. If the object is partly outside the source frame, complete only the missing continuation of its own shape consistently, so it is usable as a whole cutout. Do not recreate a rectangular patch of the source background.
Keep the object centered with sufficient completely transparent margin on all sides; no cropped extremities. Preserve antialiased edges and genuine transparency through openings and glass. Do not draw a checkerboard, opaque white/beige/black ground, labels or watermarks. Shadows, where requested below, must be neutral translucent shadow pixels fading to alpha zero, not a painted table surface.

TARGET: the dark round POTION CAULDRON AND ITS CYLINDRICAL METAL STOVE at the RIGHT of the tabletop, approximately x780-941,y570-855, including the wooden/brass stirring ladle leaning up-right from the pot. Treat pot, glowing fire, stove body, legs, ladle, rising steam and cast shadow as ONE assembly. Complete the small clipped right portion and handles consistently. Preserve the pot's hammered dark bronze/iron finish, golden rim accents, round stove door/openings and orange fire below the pot.
CRITICAL: KEEP THE RISING STEAM ABOVE THE POT, as wispy pale gray-white partly transparent curls fading into alpha zero; leave generous headroom so no steam is cut. KEEP THE ORIGINAL-STYLE CAST SHADOW below and extending toward the lower-right, plus darker contact under the feet, all softly fading semitransparent. Do not flatten steam to opaque smoke or erase the shadow. Remove all flower jars, herbs, money bag, bowl, wall and tabletop pixels. No other object.
```

### 草药半圆盆

文件：`H30_草药半圆盆_透明_v01.png`

```text
Use case: background-extraction / precise-object-edit.
Input is the user's hand-painted seaside workbench illustration (941 x 1672). Extract/reconstruct ONLY the requested object as ONE independent asset on REAL TRANSPARENT RGBA PNG. Preserve the source's object design, warm painted texture, restrained fine linework, material colors, original three-quarter viewpoint and light direction. Do not redesign it as a glossy photoreal product or a flat icon.
Remove ALL room, wood tabletop grain, ocean, writing mat, nearby objects and unrelated decorations. If the object is partly outside the source frame, complete only the missing continuation of its own shape consistently, so it is usable as a whole cutout. Do not recreate a rectangular patch of the source background.
Keep the object centered with sufficient completely transparent margin on all sides; no cropped extremities. Preserve antialiased edges and genuine transparency through openings and glass. Do not draw a checkerboard, opaque white/beige/black ground, labels or watermarks. Shadows, where requested below, must be neutral translucent shadow pixels fading to alpha zero, not a painted table surface.

TARGET: the shallow rounded gray-beige stone/ceramic HERB BOWL at the far RIGHT table edge below the stove, approximately x888-941,y820-943. It has an elliptical open rim and hemispherical bowl body with a few small dark speckles; loose green herb leaves are inside, with a few olive-green leafy sprigs lying immediately beside/under its lower-left edge. Extract this bowl with its herbs as ONE group. Restore the missing right half to a complete rounded bowl in the same elevated three-quarter view, not a literal sliced half-bowl. Keep the thick ceramic rim, subtle earthy irregularities and restrained shading. Remove the stove, book, table and unrelated plants. Do not add a pestle, spoon, flowers or potion bottles. Minimal contact shadow only.
```

### 蓝色书本

文件：`H31_蓝色书本_透明_v01.png`

```text
Use case: background-extraction / precise-object-edit.
Input is the user's hand-painted seaside workbench illustration (941 x 1672). Extract/reconstruct ONLY the requested object as ONE independent asset on REAL TRANSPARENT RGBA PNG. Preserve the source's object design, warm painted texture, restrained fine linework, material colors, original three-quarter viewpoint and light direction. Do not redesign it as a glossy photoreal product or a flat icon.
Remove ALL room, wood tabletop grain, ocean, writing mat, nearby objects and unrelated decorations. If the object is partly outside the source frame, complete only the missing continuation of its own shape consistently, so it is usable as a whole cutout. Do not recreate a rectangular patch of the source background.
Keep the object centered with sufficient completely transparent margin on all sides; no cropped extremities. Preserve antialiased edges and genuine transparency through openings and glass. Do not draw a checkerboard, opaque white/beige/black ground, labels or watermarks. Shadows, where requested below, must be neutral translucent shadow pixels fading to alpha zero, not a painted table surface.

TARGET: the SMALL DARK BLUE BOOK partly clipped at the RIGHT edge of the image, approximately x895-941,y969-1092. It has a muted navy/slate blue cover, warm brass corner fittings and a tan page block. This is NOT the large olive-brown leather book centered at the bottom of the source. Reconstruct the rest of this BLUE closed book, preserving the right-side source perspective: lying flat on the table, seen obliquely from above, with the spine/near page edge visible and a slightly diagonal orientation. A single slim-to-medium blue book only, no stack. Keep modest corner metalwork and soft cover grain; avoid ornate oversized medallions, straps or a green cover invented from the central book. No readable title or extra props. Minimal soft contact shadow only.
```

### 小日历（含阴影）

文件：`H14_小台历_含阴影_透明_v03.png`

```text
Use case: background-extraction / precise-object-edit.
Input is the user's hand-painted seaside workbench illustration (941 x 1672). Extract/reconstruct ONLY the requested object as ONE independent asset on REAL TRANSPARENT RGBA PNG. Preserve the source's object design, warm painted texture, restrained fine linework, material colors, original three-quarter viewpoint and light direction. Do not redesign it as a glossy photoreal product or a flat icon.
Remove ALL room, wood tabletop grain, ocean, writing mat, nearby objects and unrelated decorations. If the object is partly outside the source frame, complete only the missing continuation of its own shape consistently, so it is usable as a whole cutout. Do not recreate a rectangular patch of the source background.
Keep the object centered with sufficient completely transparent margin on all sides; no cropped extremities. Preserve antialiased edges and genuine transparency through openings and glass. Do not draw a checkerboard, opaque white/beige/black ground, labels or watermarks. Shadows, where requested below, must be neutral translucent shadow pixels fading to alpha zero, not a painted table surface.

TARGET: the SMALL STANDING FLIP DAY CALENDAR on the LEFT tabletop, approximately x43-207,y617-780. Preserve the dark triangular A-frame desk stand, warm ivory single page, small metal binding rings across the top, original three-quarter angle and the short handwritten inscription exactly: "第1天". This is the small day calendar shown in THIS source; do not change it into a monthly grid, circle a date or invent headings.
CRITICAL: retain the visible soft cast shadow below/to the right of its foot and the darker contact under its stand, as realistic semitransparent gray-brown shadow fading to alpha zero. The shadow may occupy transparent margin but must contain no woodgrain or opaque desktop. Keep all metal rings, paper corners and A-frame complete. Remove lamp, flower vase, net and wall.
```

### 墙挂档案袋

文件：`H17_墙挂档案袋组_透明_v01.png`

```text
Use case: background-extraction / precise-object-edit.
Input is the user's hand-painted seaside workbench illustration (941 x 1672). Extract/reconstruct ONLY the requested object as ONE independent asset on REAL TRANSPARENT RGBA PNG. Preserve the source's object design, warm painted texture, restrained fine linework, material colors, original three-quarter viewpoint and light direction. Do not redesign it as a glossy photoreal product or a flat icon.
Remove ALL room, wood tabletop grain, ocean, writing mat, nearby objects and unrelated decorations. If the object is partly outside the source frame, complete only the missing continuation of its own shape consistently, so it is usable as a whole cutout. Do not recreate a rectangular patch of the source background.
Keep the object centered with sufficient completely transparent margin on all sides; no cropped extremities. Preserve antialiased edges and genuine transparency through openings and glass. Do not draw a checkerboard, opaque white/beige/black ground, labels or watermarks. Shadows, where requested below, must be neutral translucent shadow pixels fading to alpha zero, not a painted table surface.

TARGET: the WALL-HANGING FILE/LETTER POCKET ASSEMBLY at TOP LEFT, approximately x20-132,y38-233, behind/above the landing net. Keep it as one complete compact vertical organizer: two overlapping warm brown kraft-paper/document pouches, brass hanging hooks/rings/clips, visible cream letters/cards including the front sealed envelope, and the slim dark wooden retaining lip at the bottom if it belongs to the assembly. Preserve the source's layered paper construction and small botanical marks, with no new readable words or labels. Complete edges hidden by the nearby vine/net only as needed. Remove ALL wooden wall/background, the vine, flowers, fishing net and window frame. Keep open gaps inside brass loops transparent. No extra frame, shelves, lamp or floating hardware. Only a close soft contact shade belonging to the layered organizer, not a rectangular wall shadow.
```

### 木托盘（词条与内部阴影）

文件：`H10_木托盘_零散词条内阴影_透明_v03.png`

```text
Use case: background-extraction / precise-object-edit.
Input is the user's hand-painted seaside workbench illustration (941 x 1672). Extract/reconstruct ONLY the requested object as ONE independent asset on REAL TRANSPARENT RGBA PNG. Preserve the source's object design, warm painted texture, restrained fine linework, material colors, original three-quarter viewpoint and light direction. Do not redesign it as a glossy photoreal product or a flat icon.
Remove ALL room, wood tabletop grain, ocean, writing mat, nearby objects and unrelated decorations. If the object is partly outside the source frame, complete only the missing continuation of its own shape consistently, so it is usable as a whole cutout. Do not recreate a rectangular patch of the source background.
Keep the object centered with sufficient completely transparent margin on all sides; no cropped extremities. Preserve antialiased edges and genuine transparency through openings and glass. Do not draw a checkerboard, opaque white/beige/black ground, labels or watermarks. Shadows, where requested below, must be neutral translucent shadow pixels fading to alpha zero, not a painted table surface.

TARGET: the shallow WOODEN RECTANGULAR TRAY at lower LEFT of the table, approximately x0-275,y1080-1395. Preserve the same honey-brown wood, raised rim, oblique perspective, subtle joinery and small brass decorative fitting on the front. Complete the clipped left portion so the whole tray is visible.
User-requested modification: put 6 to 8 small individual warm ivory word slips loosely INSIDE the tray, at differing angles, naturally scattered with a little overlap and visible gaps of wood. Each slip has a DIFFERENT short cluster of tiny gray-brown handwritten ink strokes. All text must be too indistinct to read: no identifiable words, digits, repeated printed labels or legible UI.
CRITICAL: retain the recessed tray's original interior shadows beneath the inner rim and at the corners, so the base visibly sits below the walls; add subtle contact shadows where the slips overlap. Do NOT erase or brighten away the inner shadow while extracting. The tray's wooden bottom is opaque and remains part of the object; only the outside of the tray is transparent. Remove scissors, the large book, leaves, chair and surrounding desk. A subtle close external contact shadow is allowed, but no tabletop grain outside the rim.
```

## 交接对象与汇报内容

- 交接对象：A 统筹与审查，由用户转发。
- 任务编号与参考版本：B-20261009-seven-source-cutouts；本轮原图附件。
- 用户明确：上述七件；药炉蒸汽/阴影与日历阴影要保留；托盘有各不相同但不可辨认的词条，保留内阴影。
- 本轮成果：上方文件树中的七件真实透明 PNG 与[实际合成总览](../../scripts/素材/预览_七件器物透明素材_v01.png)，完整提示词已记录。无未完成生成项。
- B 建议：七件作为单独可摆素材。药炉蒸汽和投影本轮合在炉层，避免接入时重复加一份阴影；托盘文字仅作装饰。
- 待决定：补全物件的审美采用；本轮不自动替代正式素材。
- 如果采用，C：正常 alpha 混合导入，保留各自完整画布以容纳蒸汽/阴影，勿按实体包围盒裁掉效果；日历数字烘焙为本轮原图“第1天”，动态日期替换需后续另作状态层。
