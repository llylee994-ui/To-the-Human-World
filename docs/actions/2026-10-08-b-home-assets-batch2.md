# B 窗口花瓶药炉工作台与海景素材

## 状态与背景

- 状态：Superseded（未完成部分不继续执行）。用户最初要求花瓶、药炉、桌子、风景四类各一张，随后转为透视讨论，现已确认合并固定背景，见[后续行动](2026-10-08-b-merchant-and-fixed-background.md)。本批不自动继续药炉重试或独立海景修图。
- 来源：用户选择的 `scripts/主页原型_晨雾魔药铺_v03.png`，沿用细线描、手绘材质、可辨认体积和暖木/冷海关系。
- 花瓶为参考原图的修复重建；药炉与工作台为统一风格的新绘；海景按恒定傍晚、雾蓝薄雾、开阔海面要求重绘。
- 三件实体物件为透明底；海景为不透明背景。海景本批合并天空与海面，属于静态排版版本，对应 H01/H02 的合并小样，尚非可独立动画的海天分层。
- 全部成图按用户要求保存到 `D:\taptap\To-the-Human-World\scripts\素材`，不覆盖上批图片、源图或生产代码；不自动导入 C 的编辑器。

## 实施措施

1. 用内置 image_gen 按四个独立提示词制作；使用用户选定 v03 作为风格和结构参考。
2. 花瓶与花枝成组；药炉不烘焙液面、蒸汽或火焰；工作台留完整空桌面及抽屉内部；海景不烘焙瓶、船或窗框。
3. 将合适的输出原样复制到指定素材目录；检查对象、透明度、边界、留白、场景约束以及文件一致性。
4. 在 B 素材规划中记录本批结果与实际限制，供用户审看及 A 交接。

## 影响文件树

```text
docs/actions/2026-10-08-b-home-assets-batch2.md       本记录、提示词与核验结果
docs/设计/B窗口_分层素材规划_v01.md                补充本批输出入口与状态
scripts/素材/H25_花瓶花枝_v01.png                  计划输出，完整花瓶花枝透明组
scripts/素材/H09_药炉_v01.png                      计划输出，锅与炉座透明组
scripts/素材/H04_工作台_v01.png                    计划输出，完整空工作台透明组
scripts/素材/BG01_雾蓝海景_v01.png                 计划输出，海天合并的静态背景
```

## 自验证方法

- 目视完整轮廓和风格；花瓶检查断枝、手柄；药炉检查炉锅连接、未烘焙特效；桌子检查空桌面和物件完整性；海景检查无晨日、山村、瓶、船或室内物件。
- 只读检查 PNG 尺寸、颜色模式和 alpha 分布；透明物件应有充分的透明外围且本体保留，不透明背景应覆盖画布。
- 校验复制前后 SHA-256 一致、v03 源图未改动、已有三张素材未覆盖。
- 本轮为美术小样检查，不进行编辑器、手机或 Maker 接入验收；图像生成不等于最终美术采用。

## 自验证结果

- 首次运行在花瓶输出后被用户中断。用户随后明确要求继续生成；原执行单元已不存在，生成目录仅发现本批花瓶文件。
- 恢复措施：保留已完成花瓶，复用下面已记录的同一提示词重新启动药炉、工作台和海景三项；不重复生成花瓶。
- 完整批次核验未完成。花瓶与工作台已保存于指定素材目录；首张海景只在生成缓存中，未作为最终背景交付；药炉无有效输出。
- 恢复后工作台与首张海景已返回；药炉返回 `image generation failed: network error: error sending request`。当时计划对药炉重试内置工具，但在用户转为透视讨论前尚未调用；未改用 CLI/API。
- 首张海景经目视存在过密浪纹与金色反光；下方局部简化提示词仅完成记录，实际修图未调用。原图仅保留在工具生成目录，不作为已通过的最终背景。

## 工具与完整提示词

### 海景局部简化

```text
Use case: precise-object-edit.
The supplied image is the EDIT TARGET: the just-created illustrated sea-and-sky background. Keep its portrait framing, horizon position, cool fog-blue palette, gentle late-afternoon sky colors, and absence of land, buildings, boats, bottles and room objects.
Change ONLY the ocean surface and the thin horizon haze. It is currently too choppy, densely detailed and full of bright metallic wave edges. Repaint the ocean noticeably calmer: large quiet horizontal blue-gray painted masses, lower wave height, much broader spacing between ripple marks, a few soft short brushstrokes in the foreground. Remove at least eighty percent of the tiny white crest marks and almost all of the long gold sparkling reflection path. Keep the water readable through slow large-scale tonal variation, not through hundreds of edge highlights. No energetic breaking waves. Add a narrow soft low-contrast blue-gray mist band at the horizon, blending distance into sky. Retain delicate hand-painted pigment variation, not flat vector color and not photographic water.
Keep the existing sky and its gently broken painted clouds nearly unchanged; do not add a sun disk, moon or stars. Keep the full scene bright enough for eternal late afternoon. The difference in water calmness and lower texture density must be clearly visible. Full-bleed opaque background, same portrait composition; no transparency, border, text, overlays or extra objects.
```

工具：内置 image_gen。三件物件 `transparent_background=true`；海景 `transparent_background=false`。均引用已目视的同一 v03 原图，不采用 CLI/API 回退。

### H25_花瓶花枝_v01

```text
Use case: precise-object-edit.
Asset type: one isolated vase-and-flowers group for a layered game homepage.
Style reference: image 1 is the user's selected v03 seaside apothecary illustration. Match its fine dark brown ink-like contours, controlled painted shading, muted natural material colors, botanical storybook detail and believable everyday object proportions. This is an illustrated game asset, with hand-drawn material marks, not a photorealistic render, glossy 3D model, flat vector icon, or a new room screenshot. Keep details selective enough to read on a phone. Soft warm ambient light from upper left. Preserve the established restrained old wood / cream ceramic / aged brass language without increasing scratches or bright rim highlights.
Image 1 also supplies the object design: the cream ceramic pitcher-vase with muted blue botanical decoration and white daisy flowers at the lower left of its window. Extract and gently reconstruct this as ONE complete, freestanding group; restore any silhouette clipped or hidden in the source. Keep the ceramic jug's single side handle, handmade cream body, blue painted leaves, and a modest natural arrangement of white daisies with olive green stems and small dried sprigs. Maintain the original illustration's proportions and fine line quality. No second vessel, book, cloth, label, tabletop, wall or frame. Leave the handle hole and gaps between stems truly transparent. Ceramic body and petals are opaque. No cast shadow extending beyond the base, no external glow.
Composition: portrait canvas, whole bouquet and whole vase visible including every tip and the base, centered with modest transparent padding. Match a gently elevated frontal view suitable for sitting on a workbench. Deliver a real transparent RGBA PNG. Do not paint a checkerboard or colored backdrop. No text or watermark.
```

### H09_药炉_v01

```text
Use case: stylized-concept.
Asset type: one isolated potion cauldron plus compact stove, a physical game interaction object.
Style reference: image 1 is the user's selected v03 seaside apothecary illustration. Match its fine dark brown ink-like contours, controlled painted shading, muted natural material colors, botanical storybook detail and believable everyday object proportions. This is an illustrated game asset, with hand-drawn material marks, not a photorealistic render, glossy 3D model, flat vector icon, or a new room screenshot. Keep details selective enough to read on a phone. Soft warm ambient light from upper left. Preserve the established restrained old wood / cream ceramic / aged brass language without increasing scratches or bright rim highlights.
Create a new modest apothecary potion stove matching the reference style. One squat round dark iron cauldron with an open oval mouth and two short practical side handles sits firmly on ONE compact cylindrical charcoal stove with a small plain firebox opening and short feet. The cauldron and stove are a single cohesive asset. Use brown-black iron and very small aged brass fasteners, thick practical shapes with believable support and gently hand-drawn contours. Show the inner cauldron dark and empty; no colored liquid, steam, smoke, flame, sparkles or magical glow, since those need separate future layers. Keep firebox interior dark and empty too. No lid, stirring stick, herbs, bottles, ground, floor, table, labels or extra equipment. Avoid spikes, horns, ornate filigree, cartoon face, fierce orange bloom and continuous glossy rims.
Composition: portrait or near-square crop fitting the whole complete appliance, gentle elevated frontal view with visible oval rim, grounded proportions, no extreme isometric angle. Keep handles and all feet intact with modest transparent padding. Deliver true transparent RGBA outside the object and through open handle gaps; do not draw a backdrop, checkerboard or exterior shadow. No text, no watermark.
```

### H04_工作台_v01

```text
Use case: stylized-concept.
Asset type: one large empty wooden workbench for a portrait game layout assembled from separate assets.
Style reference: image 1 is the user's selected v03 seaside apothecary illustration. Match its fine dark brown ink-like contours, controlled painted shading, muted natural material colors, botanical storybook detail and believable everyday object proportions. This is an illustrated game asset, with hand-drawn material marks, not a photorealistic render, glossy 3D model, flat vector icon, or a new room screenshot. Keep details selective enough to read on a phone. Soft warm ambient light from upper left. Preserve the established restrained old wood / cream ceramic / aged brass language without increasing scratches or bright rim highlights.
Use the wooden work area in image 1 as a MATERIAL and PERSPECTIVE reference, and make a clean complete wooden workbench without any of its contents or interface. A wide, sturdy simple rectangular writing workbench, dark warm walnut/brown boards with sparse long directional grain, thick tabletop, straightforward joinery and a simple supporting cabinet/short legs beneath. It is viewed frontally from a modestly elevated seated viewpoint: a generous broad tabletop plane is clearly visible and takes most of the visible object, with the front fascia and lower support beneath it. Keep the front edge broadly horizontal, mild perspective convergence, no dramatic diagonal/isometric furniture angle. The tabletop must be continuous and completely empty, suitable for a large future letter and separate tools. Under the tabletop include one modest empty recessed drawer opening/cavity for a separate future drawer-front layer; interior is dark wood, not see-through. Do not add a drawer front or handle yet. Reduce chipped edges to a few believable worn spots; no covering of scratches, glaring bright grain, gold ornament, sculpted trim, desk mat, plant, vase, bottle, lamp, books, letters, labels, buttons, chair or people. No room, window, wall, sea or floor.
Composition: landscape canvas approximately 3:2, show entire complete workbench silhouette with a small transparent margin including corners and supports. Preserve enough tabletop depth to place other objects. Match soft upper-left diffuse light; no large cast shadow outside the furniture. Deliver real transparent RGBA around the workbench and between supports, solid wood and cavity interior remain opaque. No text or watermark.
```

### BG01_雾蓝海景_v01

```text
Use case: lighting-weather.
Asset type: clean continuous outdoor sea-and-sky background for the user's portrait seaside apothecary homepage.
Image 1 is the selected illustrated scene and the style reference. Repaint ONLY its outdoor atmosphere as a full-bleed standalone landscape background, with none of the room or game UI. Preserve the fine painted storybook atmosphere, softly layered depth, quiet cool water and soft warm sky, but use the established project setting: eternal late afternoon approaching evening, still light, never night. The horizon is softened by a thin quiet veil of blue-gray mist. A restrained pale cream, dusty peach and gray-lavender sky in the upper third to two-fifths; broad fog-blue / slate-blue water in the remainder, with a small number of subtle horizontal ripple strokes and gentle foreground wave contours. Give the scene hand-painted color variation without photographic glitter, a dense web of white reflections, harsh sunbeams or heavy texture noise. The overall sea stays cool against the warm faint sky, not orange water.
Completely remove the source's sun disk, mountains, land, village, tower, shoreline, green beacon, sailboat, jetty, rocks, floating bottles and their exclusive wakes/reflections. Do not introduce new islands or buildings. No window frame, woodwork, room, hanging plants, furniture, boats, bottles, characters, interface, text, border or watermark. This is a calm unobstructed sea horizon with soft painted clouds, usable underneath separately placed bottles and a ship.
Composition: portrait 9:16 background with continuous fully painted opaque pixels to all edges; generous unobstructed sea for later object placement. No transparency, no mockup, no collage or comparison panels.
```
