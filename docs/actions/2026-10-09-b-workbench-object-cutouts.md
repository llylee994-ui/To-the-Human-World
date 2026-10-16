# B 窗口工作台器物透明素材

## 状态与背景

- 任务编号：B-20261009-workbench-object-cutouts；状态：Completed（H17 v07 已纠正为右上至左下，并完成中左桌面真实叠加检验；审美采用仍由用户决定）。
- 用户以附件 `C:\WINDOWS\TEMP\codex-clipboard-5e896521-d38a-4024-938c-602c6fc1f220.png` 为造型与材质参考，要求制作独立透明底素材：书本、剪刀、钱袋、玻璃瓶装饰、铃兰、日历、药炉、词条托盘。
- 已确认调整：日历改为单月月历，清楚圈出当月某一天；词条托盘改为放着不同方向的零散词条，文字保持不可辨认。
- 输出目录遵从既有用户指定：`scripts/素材`。不覆盖同名旧样，不接入运行时、不修改背景或游戏布局。
- 2026-10-09 用户修订：玻璃瓶光泽过强，内部改为干燥花草药材；铃兰花瓶同样压低玻璃高光。新附件 `codex-clipboard-7781a400-cd9c-4a11-9a2d-dea48d6b7142.png` 指明它们放在右侧、靠近窗的桌面区域，因此所有本轮物件统一采用窗左侧的低强度暖斜光、略亮的左上缘和右下方短投影。
- 2026-10-09 用户继续修订：此前植物标本卡采用悬浮展示角度，不能直接摆在当前桌面。改制为一张窄干花书签，平放于桌面水平面；另做平放调查档案袋，作为“信件档案桌 / 调查档案”入口。参考图为 `codex-clipboard-b0e362fd-2c8f-411d-a820-99d53b0caeaf.png`（旧标本造型）和 `codex-clipboard-0eccf9f6-dea0-4873-94da-f6e71d731601.png`（当前桌面透视）。
- 历史误解：用户说“向右倾斜”后，B 曾错误解释成左上至右下。最新明确纠正的档案袋方向是右上至左下（`／`）；此前 B 对方向的解释不是用户确认项。
- 2026-10-09 用户否决 H17 v03：它像单层信封，且倾斜和透视不能自然贴合当前桌面。v04 必须是厚实的横向调查档案夹，保留画面左上至右下的浅 `\\` 方向，远端略窄、近端略宽，清楚露出下侧叠纸和侧面厚度。

## 实施措施

### 当前 H17 v07：纠正倾斜方向

- 用户明确纠正：“改变倾斜角度，是右上到左下！！！”这覆盖 B 此前对“向右倾斜”的错误解释。当前唯一方向标准为长轴／长边从右上延伸到左下（`／`），即右端高、左端低。v06 的反向斜度不符合要求，撤回推荐；不把错误方向归为用户选择。
- 本轮只改 H17 倾斜方向，保留厚实袋身与桌面中左位置。H34 不在本次授权范围内。
- 顺序：以内置 imagegen 编辑 v06，背景附件辅助校准桌面透视与原来的左上光照 → 检查透明与长边斜率符号 → 用交付 PNG 直接在中左位置等比合成并查看。
- 计划新增：`scripts/素材/H17_桌面调查档案袋_右上至左下_透明_v07.png` 和 `scripts/素材/预览_H17_中左桌面_右上至左下_v07.png`；更新本行动记录及 B 素材规划当前链接。复用已有合成脚本，不改生产代码或正式布局。
- 自验证：已完成。旧版保留为过程记录；方向要求按用户明确的“右上至左下”执行。
- 实际输出：上列 v07 素材与预览已保存；内置 imagegen 来源为 `C:\Users\YINGYI\.codex\generated_images\01a11f39-8dab-7d41-8510-dc1583f8542b\exec-18cccc4e-3bd3-4980-a78b-2642a8bf7cb3.png`，直接复制原生 alpha，无像素加工。
- Pillow 只读检查：1536×1024 RGBA，alpha 0—254，完全透明像素 753542，alpha≥8 边界 (84,114,1506,939)。分别在 x=350、700、1100 读取 alpha>200 的上沿首点，y=325、249、165；横向越靠右越高，长边约上扬 12°，确认是 `／` 而不是上一版反向。
- 实际合成：复用 `preview-thick-envelope.ps1`，v07 输入及对应预览输出参数，`-Left 90 -Top 900 -DrawWidth 365`；绘制尺寸 365×243，背景 941×1672。保持同一中左位置、等比缩放与平移，不额外旋转或透视变形。
- `view_image` 已查看最终合成：右端高、左端低，近侧厚度和侧褶仍可辨；中左桌垫位置完整承托，未见明显白底边。逐像素比较仅 (110,927,448,1123) 范围发生变化；其他背景像素不变。
- SHA-256：素材 `e2ac6d9dc12a92038f396c2068c2b53f6e78954a5da497cac0da53156d5696ca`；预览 `0a6b6e492921d1a10914355b2fec52e0d2a970149980fa525a7b6a131b077766`。未运行 Maker，仍为独立候选美术与静态实叠检验。

#### H17 v07 实际提示词

内置 imagegen；`transparent_background=true`；输入 1 为 H17 v06 编辑目标，输入 2 为用户背景附件 f889c2a2。

```text
Use case: precise-object-edit.
Input image 1 is the envelope to edit. Input image 2 is ONLY the tabletop camera and lighting reference.
Change ONE thing: REVERSE the slant of the envelope's long axis. The user explicitly requires UPPER-RIGHT TO LOWER-LEFT: ／ . The RIGHT end must be HIGHER on the image; the LEFT end must be LOWER on the image. Both long edges must rise when read from left to right, about 12–16 degrees above horizontal. This direction is the opposite of image 1. Do not repeat image 1's downward-to-the-right long edges.
Keep the same thick filled kraft-paper archival pouch: expanding side gussets, visible thick bottom, broad closure flap, two dull brown-brass discs, natural string, small glimpse of ivory paper, and matte hand-painted tan texture. Keep the same proportions, amount of wear and thickness. No new design, text, markings or extra props.
Re-render its physical orientation as a flat envelope resting on the MIDDLE-LEFT portion of image 2's desk mat, seen from the scene's camera. The long axis runs distinctly from LOWER-LEFT to UPPER-RIGHT. Keep the envelope grounded in the horizontal desk plane, not standing up or floating. Top-face geometric guide in a landscape canvas: far LEFT corner near (8% width,35% height), far RIGHT corner near (76%,12%), near LEFT corner near (20%,84%), near RIGHT corner near (91%,62%). Thus BOTH right-hand endpoints are visibly higher than their respective left-hand endpoints. Retain visible bottom thickness below this top face. Let the depth sides run down and right while the long edges run up and right.
Lighting must still come from the scene's UPPER-LEFT window; do not mirror the lighting along with the shape. Restrained warm edge, soft darker front/right folds. Very tight faint alpha contact shadow under the base, no bright halo or broad background shadow.
Deliver exactly ONE complete envelope centered with margin as a TRUE TRANSPARENT RGBA PNG. Preserve transparency, no wood or mat, no room, no opaque background or checkerboard, no labels. The final transparent asset must already have the corrected ／ slant and usable middle-left tabletop perspective, without any extra rotation when composited.
```


### 当前 H17 v05 修订

- 参考背景：用户附件 `C:\WINDOWS\TEMP\codex-clipboard-f889c2a2-c5d6-4a48-85ef-ec89094b0aac.png`。已经查看现存 H17 v04 及其预览；B 判断其连续外露叠纸和硬封面更接近册子，继续修订为能辨认侧褶、鼓起封口的厚档案袋。此判断不是用户已确认的造型选择。
- 实施顺序：内置 imagegen 参考背景重绘独立 RGBA 素材 → 检查真实 alpha 与轮廓 → 用最终 PNG 等比缩放后直接合成到该附件桌面 → 目视检查透视、倾斜与接触阴影。试放不得靠透视扭曲修正错误素材，也不得用另生成的场景冒充合成结果。
- 计划新增：`scripts/素材/H17_桌面调查档案袋_透明_v05.png`（厚袋候选）、`scripts/素材/预览_H17_桌面调查档案袋_桌面叠加_v05.png`（真实合成预览）、`.tmp/b-workbench-objects/preview-thick-envelope.ps1`（可复现的缩放合成与 alpha 检查）。完成后更新 B 分层素材规划中的当前推荐链接。
- 验证进度：v05 已检验，后被用户新增的中左摆放约束取代；最终 v06 检验见下文。保持既有版本、背景及正式布局不变；仅本轮 H17 修订，H34 不在范围内。
- v05 已生成并实际合成：1536×1024 RGBA，alpha=0 共 684614 像素，alpha≥8 边界 (57,98,1482,971)，保留原生 alpha。最终暂试位置 (450,1125)、420×280，未旋转或扭曲；与背景逐像素比较，差异仅在 (465,1152,856,1391)。初次位置过于靠近前桌沿，已在预览中上移。素材 SHA-256 `0a345ce18a35c4728b9f4259b1023c8a665d201cc5e6fd1d586d84ac65b04365`；仍为过程样本。
- **用户新增位置约束：档案袋放在桌面的中左边，并要求据此重新规划透视和角度。** 因此停止推荐前右侧 v05 的摆法，继续生成 v06；本轮把“中左部”落实为桌垫左半边附近，仅作为验证位置。保持厚实袋身和轻微向右倾斜，按这一区域重画近远边及侧褶，不把原来前右侧的 PNG 简单挪过去冒充修订。
- v06 已输出 `scripts/素材/H17_桌面调查档案袋_中左桌面_透明_v06.png` 与 `scripts/素材/预览_H17_中左桌面叠加_v06.png`；复用合成脚本，位置 (90,900)，完整透明画布缩放至 365×243，不旋转、不扭曲。v05 保留过程证据，不作为当前交付推荐。


#### H17 v06 中左桌面实际提示词

模式：内置 imagegen，`transparent_background=true`；背景附件作为唯一透视和光照参考。

```text
Use case: stylized-concept.
Deliverable: exactly one thick archival DOCUMENT ENVELOPE as a genuinely transparent RGBA game sprite.
Reference image 1 is the unchanged target room/background; use it to solve the object's physical tabletop camera and warm painterly shading. Do not depict any part of this background in the output.
NEW placement requirement: this envelope will rest at the MIDDLE-LEFT of the TABLE, on the left half of the ivory desk mat, roughly centered around image x=270,y=1040 in the 941x1672 reference. It is NOT at the front-right edge. Render it in this intended position's perspective, while outputting only the isolated object at large resolution.
Ground plane and orientation are the top priority. The envelope lies completely FLAT with its entire underside resting on the same horizontal plane as the desk mat. Camera above the desk and looking down, as in the reference. Shallow clockwise/rightward turn, NO dramatic diagonal or upright display. Both depth edges travel mostly downwards and slightly RIGHT towards the viewer, just as the desk mat edges do. Do NOT make the depth sides travel down-left like a catalog display.
Geometric guide for its top surface in a landscape output: far-left corner roughly (12% width,15% height), far-right (80%,18%), near-left (18%,70%), near-right (91%,76%). This is a perspective quadrilateral for a physical envelope lying on the reference tabletop: near edge modestly wider, broad long edges nearly level but falling only slightly to the right, near corners gently shifted RIGHT compared with far corners. This is NOT a front-facing flat rectangle, an isometric icon or a steeply leaning envelope. Keep the whole object inside the image with transparent margin.
Envelope design: substantial expandable ochre kraft-paper dossier pouch, visibly filled with documents. A wide softly bulging overlapping closure flap covers the upper face. Two small dull brass/brown closure discs and a short natural string close it. Actual folded expandable side gussets and a 3-4 cm thick bottom are visible on the near side, with a small glimpse of papers at the right seam. Weight sits on the desk. Clearly an envelope/pouch, not a hardback book or naked paper stack. The near-side thickness is clear but only about one-eighth of the top-face depth. Sparse broad paper folds, restrained surface wear, no torn edges, no ornamental decoration, no readable text.
Style: match the reference's quiet painted brushwork, matte muted tan kraft, muted ochre and sepia shadows. Softer illustrative texture, not photographic microdetails.
Light: diffuse low warm window light from upper-left/back. Subtle warm upper-left edge, darker near/right folds, low contrast brass. Tight narrow contact shadow directly under the base and just down/right, actually semitransparent and softly fading to alpha=0, not an opaque surrounding patch. No bloom or large dark silhouette. Match the background rather than studio lighting.
Output only the complete isolated envelope with soft alpha/contact shadow. True transparent outside. No tabletop/mat pixels, no solid fill, no checkerboard, no background vignette, no room, no other props. Perspective must be baked correctly so it can be composited by ONLY uniform scaling and translation at the specified middle-left position.
```

#### H17 v05 实际生成提示词

模式：内置 imagegen，`transparent_background=true`，唯一输入为上列用户桌面背景（相机、光照与笔触参考；不重绘背景）。

```text
Use case: stylized-concept.
Asset type: one transparent PNG game prop, a thick expandable investigation document envelope laid flat on a wooden workbench.
Reference image 1 is ONLY the target scene for camera, tabletop perspective, painterly texture and illumination. Do not output the room or tabletop.
Primary request: produce a single complete substantial kraft-paper archive ENVELOPE, visibly filled with many documents. It must have a real enveloping pocket, folded accordion gussets on its near and right side, 3-4 cm of softly rounded thickness, a broad overlapping closure flap on top, and two small muted brass/brown closure discs joined by a short natural cord. Slightly bulging surface from papers inside. Just a small irregular glimpse of ivory paper at the seam. It must read as a filled archival pouch, NOT a bound book, hardback volume, flat letter or stack of loose paper with a cover. No readable text, modern icons or badge.
Critical camera: visualize this envelope resting on the bare FRONT-RIGHT part of the desk in the reference, just below the ivory desk mat. Match the camera looking downward at the tabletop. Its broad top plane is foreshortened in depth with a slightly narrower far edge. Landscape envelope, mild clockwise/rightward orientation: the long top edge falls only about 5 degrees toward the right, near long edge about 7 degrees. Short depth edges must be in the same physical ground plane as the desk, NOT a standing/easel angle or floating product display. Show a clearly visible low near-side gusset about 1/8 of the projected face depth, never a vertical upright front face. Its centerline points very gently upper-left to lower-right.
Style: match the reference's soft painterly illustration, broad restrained brushwork, matte ochre-tan kraft paper, muted sepia crease shading. Modest wear at folds, not crumbling or heavy stains. Avoid photoreal sharp microtexture.
Lighting: subdued warm daylight from window at upper-left/back, gentle warm edge only, softly shaded front/right face. No glossy highlights, no halo, no dramatic rim light. Include only a tight short translucent contact shadow down/right of the base, with feathered alpha edge; no large black cast shadow.
Output: ONE isolated complete envelope centered with generous transparent margin on all sides. Genuinely transparent RGBA background; preserve soft alpha. No wood pixels, no opaque backdrop, no checkerboard painting, no background color, no labels, no second object. The rendered viewpoint must already fit the reference without subsequent image rotation or perspective warping.
```

1. 以附件作参考，逐件生成真实 RGBA 透明 PNG，保留木、旧纸、黄铜、玻璃、陶/铁的手绘质感。
2. 日历和托盘是功能化重绘，其余为参考图中可辨物件的独立提取/重建。
3. 每件检查是否为 RGBA、是否存在完全透明外部区域、轮廓和物件完整性；将合格版本复制至输出目录。
4. 记录生成来源、输出文件和事实检查；用户审美确认前不标记为正式定稿。

## 影响文件树

```
scripts/素材/H12_厚皮书_透明_v02.png              计划：配方/档案书候选
scripts/素材/H11_黄铜剪刀_透明_v02.png            计划：剪词工具候选
scripts/素材/H15_钱袋_透明_v02.png                计划：钱袋候选
scripts/素材/H28_玻璃瓶装饰_透明_v01.png          计划：玻璃花瓶候选
scripts/素材/H29_铃兰花束_透明_v01.png            计划：植物装饰候选
scripts/素材/H14_月历_圈日_透明_v02.png           计划：日期状态物件候选
scripts/素材/H09_炼药炉_透明_v02.png              计划：炼药入口候选
scripts/素材/H10_零散词条托盘_透明_v02.png        计划：词条入口候选
scripts/素材/H28_玻璃瓶干药材_透明_v02.png        已输出：窗边桌面的低光泽干药瓶
scripts/素材/H29_铃兰花瓶_透明_v02.png            已输出：窗边桌面的低光泽铃兰花瓶
scripts/素材/H30_琥珀药草罐_透明_v01.png          已输出：琥珀干药草罐
scripts/素材/H31_陶瓶干花_透明_v01.png            已输出：陶瓶干花
scripts/素材/H32_干草药束_透明_v01.png            已输出：扎束干草药
scripts/素材/H33_植物标本卡_透明_v01.png          已输出：植物标本卡
scripts/素材/H34_干花书签_桌面透视_透明_v01.png    已输出：平放桌面的干花书签候选
scripts/素材/H17_桌面调查档案袋_透明_v02.png       已输出：平放桌面的调查档案入口候选
scripts/素材/H34_干花书签_桌面透视_透明_v02.png    已输出：向右倾斜的桌面书签修订版
scripts/素材/H17_桌面调查档案袋_透明_v03.png       已输出：向右倾斜的桌面档案袋修订版
scripts/素材/H17_桌面调查档案袋_透明_v04.png       已输出：厚实、浅向右倾斜并贴合当前桌面的调查档案夹
scripts/素材/预览_H17_桌面调查档案袋_桌面叠加_v04.png 已输出：当前背景桌面上的临时原位叠加检查
scripts/素材/H17_桌面调查档案袋_透明_v05.png       已输出：厚袋过程样本，前右位置不再推荐
scripts/素材/预览_H17_桌面调查档案袋_桌面叠加_v05.png 已输出：前右位置过程检查
scripts/素材/H17_桌面调查档案袋_中左桌面_透明_v06.png 已输出：当前中左摆放候选，厚侧褶与浅右倾
scripts/素材/预览_H17_中左桌面叠加_v06.png          已输出：最终 PNG 在用户背景上的真实中左合成
scripts/素材/H17_桌面调查档案袋_右上至左下_透明_v07.png 已输出：按明确方向纠正的当前候选
scripts/素材/预览_H17_中左桌面_右上至左下_v07.png    已输出：v07 保持中左位置的真实合成
.tmp/b-workbench-objects/preview-thick-envelope.ps1 已新增：可重复的等比缩放与 alpha 合成脚本
docs/设计/B窗口_分层素材规划_v01.md              已更新：当前候选素材与预览链接
docs/actions/2026-10-09-b-workbench-object-cutouts.md  本记录
```

## 自验证方法

- 图像生成要求真实透明背景；再读取 PNG 元数据和 alpha 通道，检查 RGBA、尺寸、透明像素及 alpha 有效包围盒。
- 对每个输出作目视检查：物件不残留场景、桌面、文字 UI 或完整背景；日历为月格，词条不可阅读；玻璃和植物细部没有大面积色边。
- 不运行 Maker 构建或游戏预览：仅新增 B 窗口候选美术素材。

## 自验证结果

### 历史中左桌面 H17 v06（倾斜方向已被用户否决）

- 生成来源：内置 imagegen，原始输出 `C:\Users\YINGYI\.codex\generated_images\01a11f39-8dab-7d41-8510-dc1583f8542b\exec-f20b9327-5c0a-4de2-9497-e6f2098c7b2d.png`。原生 alpha 完整复制，无阈值抠图或像素加工。
- Pillow 只读检查：1536×1024 RGBA，alpha 范围 0—254，完全透明像素 589477；alpha≥8 有效边界 (94,109,1485,947)，物件完整，不触及画布边。最大 alpha 254 对合成只有约 0.4% 的透底，实叠未见纹理透穿。
- 实际合成复现：`& '.tmp/b-workbench-objects/preview-thick-envelope.ps1' -AssetPath 'D:\taptap\To-the-Human-World\scripts\素材\H17_桌面调查档案袋_中左桌面_透明_v06.png' -OutputPath 'D:\taptap\To-the-Human-World\scripts\素材\预览_H17_中左桌面叠加_v06.png' -Left 90 -Top 900 -DrawWidth 365`。背景 941×1672，素材等比缩至 365×243；System.Drawing SourceOver 合成，不额外添加阴影，不做旋转或透视变形。
- Pillow 只读逐像素比较：最终预览与背景的差异范围仅为 (112,926,444,1127)，其余背景保持原像素。这是交付素材的实际叠加，不是另外生成的场景图。
- `view_image` 查看最终全图：袋子位于桌垫左半边、桌面中左区域；浅右倾、近侧袋底厚度、右侧褶与纸边可辨，外缘无明显白底或色块。接触阴影较克制，外轮廓比背景笔触略清晰；这是目视匹配，未据此宣称几何标定或用户审美验收通过。
- 提示词中的四角坐标只是构图引导，生成结果未逐点遵循；最终交付依据是实际叠加后的目视结果，不能把提示词要求当成像素检测结论。
- SHA-256：素材 `2be85f2c153cdff3dd38cccc7a83be80380c9efe48bc65185a30ec33a633151d`；预览 `77c2a30f1dd4435fae553a0062b9edf6b56e3859eeeb3e44b39378ae181dd59f`。
- 未运行 Maker：本轮不改游戏资源引用或正式布局，只输出独立美术候选与静态合成检验。

### 既有批次结果（历史记录）

- 八张输出均已复制至 `scripts/素材`；逐张读取为 RGBA，均含大面积 alpha=0 的外部背景。已清理 alpha 0—7 的外围暖光残留，保留器物边缘抗锯齿及紧贴底部的轻微接触阴影。
- 目视抽查：月历为 7 列月格，有一格锈红色手绘圈；日期细节被故意压低至不可读。词条托盘有 8 张不同角度纸片，灰褐墨迹为不可读的笔画，不含可识别词语、数字或 UI 标签。
- 书本、剪刀、钱袋、玻璃瓶、铃兰及药炉均为完整单一物件，不含桌面、窗景或其他家具；玻璃瓶保留少量压花与软高光，药炉的蒸汽限制在锅口附近。
- 实际核对：未运行 Maker 构建或游戏预览；本轮为独立候选美术素材。原附件与既有版本未被覆盖。
- 文件哈希见本次会话输出；输出文件完整清单见“影响文件树”。
- 修订输出逐张读取为 RGBA，均有大面积 alpha=0 外部区域；清理 alpha 0—7 的边缘残留后，alpha≥8 的内容边界不触及画布边缘。目视检查 H28/H29：玻璃改为偏灰绿、带尘感的低光泽材质，干药材/铃兰是视觉重点，右下仅有紧贴桌面的短阴影。
- 本轮补充 H30—H33 以同一桌面视角生成：琥珀药草罐、陶瓶干花、干草药束和植物标本卡。H33 的笔记只作为装饰性、不可辨识笔画；若后续要承载内容，需要由文字层另行覆盖。
- 修订输出 SHA-256：H28 `2790313F49B588609ACE365632BF8C2AEB7214638DE4DB8057162809F4961F6A`；H29 `726655E971433A392FC243F3163DEB3B2CD9AFF1CF7064CEED5B176ECB9899C2`；H30 `928FC9DC1CA1CE88D8FF94C2DC28FEAAA9DC47F2D0DD14736C4AC651B67F9608`；H31 `106A7CB001EC455E2C122060D4AD8A74DFFC23FDFA1DC5350D0FD1F95B7B78FD`；H32 `57AA547C82B2B98990E191FF27E301936818FEB86207AF245C10243BC1A69A8B`；H33 `907645080E6CCE4BAA022782A2163161BD88DDB2537A3550DEA88D69BA0D88E4`。
- 本轮 H34 为窄书签，不沿用旧 H33 标本卡的悬浮斜角：平面沿桌面纵深由近端（下左）向远端（上右）收窄，保留纸边及向右短阴影。H17 是平放的闭合旧纸调查档案袋，以深橄榄布带、铜扣和露出的无字索引片作为可点击辨识，不使用现代刑侦元素或可读案件文字。
- 两张均读取为 RGBA，清理 alpha 0—7 的外围残留后，alpha≥8 有效内容不触及画布边缘。H34 为 1178 × 1335、有效边界 [224,131,1102,1225]；H17 为 1448 × 1086、有效边界 [91,117,1371,1014]。已用 view_image 目视检查平放透视、短阴影、完整轮廓与透明背景。SHA-256：H34 `C110B3D249215F6C094D8F0334DF706D81B31C23AA1325FAF4AB335A01029DD2`；H17 `166F34B3BA05A37CEB5463E87346DEC58DA971C5F1590B3787DA8D43B6EC6A8B`。
- 用户指出 v01/v02 的视觉方向理解错误，因此保留旧版对比，新增不覆盖的定向修订：H34 v02 与 H17 v03 均为画面 `\\` 方向，即从左上延伸至右下。两张均为 RGBA，alpha≥8 内容不触及画布边缘；H34 v02 有效边界 [96,136,1099,1208]、SHA-256 `3687BAE77D0980731E1AE498E98ACA642D688B533F221F8A1B5D0D412C689701`；H17 v03 有效边界 [95,95,1360,1004]、SHA-256 `015BDC0A490B3D1B8B12E3BB5D27B52E58726CBD74F9C5289045172733F5A43A`。生成结果已在透明底上目视确认，边缘清理只移除 alpha 0—7 的残留，不改变物件方向。
- H17 v04 已按用户否决意见改为厚实横向档案夹：近侧有连续叠纸与深色侧面，封皮被内容物轻微撑起；仍是浅 `\\` 向右倾斜，不采用陡斜展示角。实际读取为 1536 × 1024 RGBA，alpha≥8 有效边界 [47,88,1507,963]，不接触画布边缘；SHA-256 `9D4747B336BD1B365F1D309BEAB3B4F9A8445D286E4F23D565A466B4A5AB6D4D`。以当前用户附件背景在 (442,1160)、30% 尺寸（461 × 307）叠加的预览已目视检查：接触阴影与桌面衔接正常，倾斜和厚度均可辨；该位置仅用于检查，不是正式布局指令。

## 交接对象与汇报内容

- 交接对象：A 统筹与审查（由用户转发）。
- 任务编号与参考版本：B-20261009-workbench-object-cutouts；附件 `codex-clipboard-5e896521-d38a-4024-938c-602c6fc1f220.png`。
- 用户已明确选择：日历采用月格并圈日；词条托盘带零散、内容不可读的词条纸。
- 用户已明确选择：右窗附近的桌面物件不使用展示式高光；玻璃瓶填干燥花草药材，铃兰花瓶也降低反光。
- 用户已明确选择：干花书签应采用背景桌面透视；调查档案入口为放在桌面上的档案袋。
- B 建议：日历中的具体日期和月份不要烘焙进正式状态，圈选位置应由 C/状态层覆盖；托盘用作静态入口或底座，具体词条由独立纸片/文字层承载。
- 待决定：审美验收，特别是是否接受月历和词条以不可读笔画呈现。
- 若采用，C 需以每张 PNG 的完整画布作为独立可移动素材；可加统一轻投影，但不再给这些素材套大面积色块背景；月历的当天圈可在后续改为独立状态层。
- 若采用 H28—H33，C 应保持物件的原始三分之四桌面角度与向右短阴影，不把它们镜像或旋转成正面陈列；右侧窗口区域一屏建议同时摆放不超过两至三件，避免装饰密度回到旧版的满铺状态。
- 若采用 H34/H17，C 保持其烘焙透视与阴影，不在编辑器中再旋转；调查档案袋的点击热区应覆盖袋面而不是只覆盖铜扣。
- 当前 H17 推荐为 v07；H34 v02 本轮未变更。用户明确确认项：厚实档案袋，桌面中左部，倾斜方向右上至左下（`／`，右端高左端低）。此前“向右倾斜＝左上到右下”的定义为 B 误解，禁止继续沿用。v04—v06 保留为过程样本。
- 本次 H17 参考版本：背景附件 `codex-clipboard-f889c2a2-c5d6-4a48-85ef-ec89094b0aac.png` 与 v06 造型；成果为上列 v07 素材、真实合成预览及完整提示词。推荐理由：保留袋身与侧褶厚度，并通过目视和上沿坐标检查确认用户要求的倾斜方向。
- 待决定：用户对中左部角度、厚度与笔触的审美验收；“桌垫左半边”是 B 对位置的具体试放解释，未视作用户已确认的正式坐标。
- 如果采用，A 再明确制作规范并交给 C；C 使用 v07 原比例 PNG，保留烘焙透视与原生 alpha，以袋面作为点击热区。严格保持右上至左下方向，不镜像；参考预览不额外旋转或加重阴影；任何移至不同纵深区域的正式摆放应重新检查。B 未直接给 C 派发执行。
