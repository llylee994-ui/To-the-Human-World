# B 窗口商船增补与固定背景准备

后续任务：用户已列出清除对象，要求空托盘、有船/无船两版背景，最新进度见[固定背景提取记录](2026-10-08-b-clean-background-pair.md)。下文“抽屉瓶保留”仅是当时整图版本要求，本次提取按用户最新指示清空。

## 状态与背景

- 任务编号：B-20261008-merchant-background；状态：Completed（首轮整图及商船朝向绿光码头的追加修订已完成；固定背景提取尚未执行）。
- 用户确认：木屋、窗框、桌子、固定结构阴影与窗外海景合为一张固定背景，减少独立拼接的透视问题。
- 本轮请求：在 `scripts/主页原型_晨雾魔药铺_v03.png` 中补出窗外商船，为后续提取背景准备底稿；追加要求去掉海上漂流瓶。随后用户明确“抽屉里的瓶子先别去掉”，因此当前整图保留抽屉瓶及其标签。
- 参考版本：晨雾魔药铺 v03；功能参考为《寄往人间_前端界面设计草案_移动端竖版更新》和《主页原型与分层说明_v02》（含后续 v0.4 记录）。
- 已核对：小商船是商店入口，有到访状态；既有说明要求船及水影独立显示/隐藏。因此先交付带船位置示意整图，固定背景提取时不烘焙商船或漂流瓶。
- 源图含远山、村落、日轮、清晨文字及纸牌式导航，与既有最终场景要求尚有差异。本次局部编辑不全面重设计；背景小样不等于这些细节已冻结。
- 本轮属于 B 创意美术小样。使用内置 image_gen，原图保持不变，输出统一存放 `scripts/素材`；不开发编辑器、不改生产代码、不向 C 自动派发。

## 实施措施

1. 目视 v03，核对商船入口和固定/状态层关系。
2. 将右侧远处普通帆船调整为能看清篷顶与货物的小商船；只移除海上的两个漂流瓶及专属水纹，保留抽屉里的瓶及标签和室内原构图。
3. 检查并保存整图。本轮先保留用户要求暂留的抽屉内容；固定背景提取为后续步骤，当前不提前移除其他物件。
4. 目视船的水线、比例、主次和背景残留；只读检查 PNG 元数据及哈希，确认拷贝一致和源图未改。
5. 更新本记录及 B 规划的最新决定入口；此前清单保留作历史盘点，不继续按全结构拆分数量排产。

## 影响文件树

```text
docs/actions/2026-10-08-b-merchant-and-fixed-background.md  执行事实、提示词和交接记录
docs/actions/2026-10-08-b-home-assets-batch2.md             更正上一批尚未执行的重试/修图状态
docs/设计/B窗口_分层素材规划_v01.md                       增补已确认的合并背景方向
scripts/素材/主页原型_v03_商船无漂流瓶_v01.png             已交付：有商船、海面无瓶、抽屉瓶保留的整图示意
scripts/素材/主页原型_v03_商船朝向码头_v02.png             已交付：同一商船船头朝向绿光码头
```

## 自验证方法

- 目视小商船、水线与整体构图，确认漂流瓶和专属痕迹消除。
- 目视海面没有漂流瓶或专属水纹，抽屉里的瓶及标签保留，桌面和窗框透视保持。
- Pillow 只读检查尺寸、模式、透明度；本轮为不透明整图，不是透明切片。
- SHA-256 对比生成缓存与目标文件；源图预期哈希 `541EFC5052131534A35673FBBC6ADAE645A073245BD2C3B8CD7DDD249C096625`。
- 不涉及代码接入，不运行编辑器或 Maker 验收；图片生成不等于功能实现。

## 自验证结果

- 已完成内置 image_gen 三次调用：补商船/去瓶、按用户追加要求恢复抽屉瓶、清理旧瓶水纹。行动记录首次补丁格式错误未落盘，修正后才开始图像生成。
- 最终已目视：右侧海面出现有篷顶、木箱与桶的小商船；两个海上漂流瓶消除；抽屉瓶、未开瓶标签和右侧信封保留；室内主要布局保留。
- 水纹清理仅部分改善，左侧仍有少量弧形浪笔；没有残留瓶体。暂不继续反复生成，以免进一步影响原图笔触，后续背景清理时可处理该小区域。
- 最终缓存文件：`C:\Users\YINGYI\.codex\generated_images\01a119d9-8765-7312-bdb9-e6179a44dfce\exec-114dae43-05f2-48aa-ac7f-c112ff274bf4.png`，已原样复制到 `scripts/素材/主页原型_v03_商船无漂流瓶_v01.png`。
- 使用 Pillow `Image.open`、`load`、`size/mode/format` 只读检查成功：PNG，942 × 1670，RGB，不透明，2,560,983 字节。相较原图尺寸存在轻微变化，未另行缩放；不视为像素级无损编辑。
- `Get-FileHash -Algorithm SHA256` 通过：目标文件与缓存均为 `645C629629CAC7E3C50970A480E87517B8754834BCDF5B6F60351840613581CF`；v03 源图仍为预期 `541EFC5052131534A35673FBBC6ADAE645A073245BD2C3B8CD7DDD249C096625`。
- 图片没有覆盖原稿。此图是修订示意，仍保留原稿山村、日轮和旧 UI 文字；不表示这些历史差异已被用户全部批准。
- 未执行固定背景提取、透明商船切片、编辑器导入、Maker/手机验收或生产代码修改。

## 工具与完整提示词

工具：内置 image_gen；引用已用 view_image 检查的本地源图；`transparent_background=false`。无 CLI/API 回退。

### 首次提交：商船增补与漂流瓶移除（提交后用户收窄去瓶范围）

```text
Use case: precise-object-edit.
Asset type: revised full portrait homepage concept illustration for a seaside apothecary game.
Input image 1 is the EDIT TARGET, not merely a style reference. Make the following localized changes: remove the two floating message bottles from the sea and the upright corked message bottle inside the open drawer, including their object-specific reflections, ripple rings and the small associated 未开瓶 label. Reconstruct the continuous sea surface and wood behind them. Then show a clearly recognizable small visiting merchant boat on the sea outside this same window.
Replace the distant generic tall-masted sailboat at the right-side harbor with a modest wooden trading boat positioned somewhat closer, on the middle-distance water in the right half of the window. Keep it entirely inside the window opening with ample empty water below and beside it. Approximate boat center at 70% of the entire image width and 37% of the entire image height; total boat silhouette around 19–22% of image width, not an enormous ship. Show a low dark-brown wooden hull, a small muted olive/linen canvas canopy, a few readable cargo crates, a barrel and tied parcels. A short mast with furled sail is acceptable. No large raised sail, flags, text sign, modern ship, pirate styling, new dock, or extra boat.
Match the scene's elevated viewpoint and existing water plane; see a little of the deck from above. Boat sits IN the water, with a soft restrained reflection and a few short ripples at the hull. Use the same fine dark drawn contours, painted muted materials and softer middle-distance contrast as the source. Cargo and canopy make the merchant role legible, without excessive tiny ornaments or bright highlights.
Preserve the original full portrait composition and camera precisely, aiming for the same 941 × 1672 canvas. Preserve all indoor architecture, open window frame, workbench and open drawer, herbs, botanical picture, pouch, vase, lantern, books, papers, the envelope, original Chinese labels except the removed bottle label, and every other object in their original positions and scale. Preserve the existing sky, shoreline, buildings, sea color, lighting, texture and drawing style outside the local boat edit. Do not redesign the whole image, simplify its art style, zoom, crop, invent controls, add a watermark or change text. Full-bleed opaque image.
```

### 固定背景提取

未执行。用户要求抽屉瓶暂留，当前先交付整图修订，后续再提取固定背景。

### 最新要求局部修正：恢复抽屉瓶及标签

首张结果：`C:\Users\YINGYI\.codex\generated_images\01a119d9-8765-7312-bdb9-e6179a44dfce\exec-17641093-7a99-4f7c-9192-3a7fbb441030.png`。已目视商船、空海面和被移除的抽屉瓶；该中间稿不作为最终交付。

图 1 为首张结果，图 2 为 v03 原图。调用内置 image_gen，真实不透明整图，恢复范围限于抽屉瓶及标签。

```text
Use case: precise-object-edit.
Image 1 is the EDIT TARGET: the revised portrait homepage with the new canvas-canopy merchant boat, no floating sea bottles, and an empty left side of the open drawer.
Image 2 is the ORIGINAL SOURCE solely for restoring the drawer bottle and its tag.
Make one small local restoration inside the open drawer of Image 1. Restore the original upright/slightly leaning corked glass message bottle containing a rolled paper, its twine and wax/tie detail, and the small cream paper label reading exactly "未开瓶", using Image 2 as the direct design, position, scale, angle and lighting reference. The bottle belongs at the LEFT INSIDE of the drawer, next to the existing envelope on the right, exactly where it appears in Image 2. Reproduce its dark translucent glass, rolled paper, cork, fine outlines and contact shading against the drawer, with its bottom naturally occluded by the front drawer lip. Restore the small associated label to the right of the bottle. This is the tabletop message bottle only.
Keep the complete remainder of Image 1 unchanged: preserve the new merchant boat and its reflection, empty ocean without either floating bottle, mountains, village, sky, window framing, hanging herbs, picture, money pouch, vase, lantern, desk, drawer shape, envelope, every other existing Chinese label, original portrait framing, texture, colors and drawing style. Do NOT copy the two floating sea bottles back from Image 2. Do NOT replace the new merchant boat with the old sailing boat. Do not zoom, crop, redraw the room, add new UI or decorations, or alter the composition.
Output a full opaque portrait image, same composition and dimensions as Image 1.
```

### 海面水纹局部清理

第二张 `exec-dcf87eeb-6006-4ac3-9666-36427278e879.png` 已恢复抽屉瓶及标签，商船保留；左侧海面仍有旧瓶水纹椭圆残留，因此执行一次局部修正。

```text
Use case: precise-object-edit.
Input image is the EDIT TARGET. Perform ONE tiny localized cleanup, preserving everything else.
On the left-middle sea, approximately x=240–445 and y=697–744 in this 943×1672 portrait, there is an isolated oval/concentric ripple ring left over from a removed floating bottle. Remove this empty oval ripple ring and smoothly reconstruct the ordinary blue-gray horizontal sea brushstrokes underneath. Keep neighboring golden reflections as irregular broken horizontal wave highlights, but no closed elliptical rings or empty object-shaped wakes at this location. Do not place any object on this water.
Preserve the entire remainder of the illustration: especially the merchant canopy boat in the right-side sea, its own contact ripples/reflection, the upright corked glass bottle and the exact "未开瓶" tag INSIDE the open drawer, the envelope, all Chinese text, architecture, window, desk, props, sky, mountains, village, color, lighting and texture. Sea remains without floating bottles. Do not remove the drawer bottle again. Do not recrop, zoom, restyle or change any layout. Output the same full opaque portrait image.
```

## 交接对象与汇报内容

### 追加修订：商船船头朝向绿光码头

- 用户决定：现在的商船头朝向绿光的码头。
- 输入参考：已交付 `scripts/素材/主页原型_v03_商船无漂流瓶_v01.png`，本轮已再次目视；继承海上无瓶、抽屉瓶保留的要求。
- 措施：仅重画船体在水面内的朝向和相应近身水影，采用船头左上朝远处码头、船尾右下朝观察者的三分之四背面视角；不把整张船图在平面内斜转。
- 验证：目视船头与绿光码头方向一致、船体水线/桅杆合理、抽屉瓶保留；核对 PNG 尺寸和复制哈希，旧版不覆盖。
- 核验结果：已目视船头朝左上绿光码头、较宽船尾在右下，船体呈斜向远处的三分之四视角；篷顶、货物和水影随之调整，桅杆竖直。抽屉瓶、未开瓶标签与信封保留，海面无漂流瓶。商船中心相对 v01 稍向下移动，室内主要构图保留；并非像素级局部替换。
- 已保存 `scripts/素材/主页原型_v03_商船朝向码头_v02.png`，来自生成缓存 `exec-d8781d54-7877-41ad-9d57-c94a386b8082.png`。Pillow 只读加载通过：942 × 1670、RGB PNG、2,609,388 字节。
- `Get-FileHash` 验证目标与缓存 SHA-256 均为 `BD55E9C09ED05261BACADF7C216315964147EB578963C295327D7AB0353241BE`；v01 仍为 `645C629629CAC7E3C50970A480E87517B8754834BCDF5B6F60351840613581CF`，未覆盖。
- 未执行背景提取、透明船切片或游戏接入。船型与转向为本轮美术修订，不代表商船到访逻辑已实现。
- 工具：内置 image_gen，`transparent_background=false`；完整提示词如下。

```text
Use case: precise-object-edit.
Input image 1 is the EDIT TARGET: the current seaside apothecary homepage with one covered merchant boat in the right-side sea, no floating sea bottles, and a corked message bottle inside the open drawer.
Primary request: turn this SAME merchant boat so its BOW points toward the existing GREEN harbor beacon and its wooden dock, which are up-left and farther away from the boat. The orientation change must be clearly visible.
Change only the merchant boat and its immediate contact reflection/ripples. Reorient the hull in the horizontal water plane and redraw its perspective; do not merely rotate the flat picture. Change the nearly side-on boat to a rear three-quarter view: the pointed bow is the farther, upper-left end directed toward the green-lit dock; the broad stern is nearer, lower-right, facing partly toward us. Approximate projected hull direction: stern near (690,580), bow near (555,515), pointing onwards toward the green beacon near (494,480), in the full 942×1670 source image. Use these only as composition guidance. The boat remains on the same right-middle patch of water, at approximately the same scale and distance; do not move it all the way to the dock.
Preserve its identity: the same small brown wooden trading hull, muted olive canvas canopy, crates, barrels, short mast and furled sail. Reproject the deck, canopy, cargo and hull consistently with the new heading. Mast and canopy uprights remain upright, boat level and buoyant on the water. The silhouette is naturally somewhat foreshortened as it points away. Match the original fine dark linework, muted painted materials, warm/cool lighting, soft distance contrast and restrained reflection. No new boats, people, large sails, arrows or text.
Keep absolutely everything else as close to the source as possible: green lamp and dock in the exact original location, mountains, village, sky, entire sea away from the boat, window, house, herbs, frame, vase, pouch, lantern, wooden desk, drawer and its BOTTLE with the "未开瓶" tag, envelope, all original Chinese text and UI. Keep sea without floating bottles. Preserve full portrait framing and proportions; no crop, zoom or restyling. Full opaque PNG.
```

- 交接对象：A 统筹与审查，由用户转发。
- 用户已选：木屋、窗框、桌子、固定结构阴影与海景合并；只去掉海上漂流瓶，暂留抽屉瓶及标签；商船船头朝向绿光码头。最新交接参考为 v02 朝向码头版本。
- B 推荐：商船到访状态保留独立层，按整图中核对过的位置和尺度叠加。
- 本轮来源与成果：见参考版本及输出路径；完成情况以自验证结果为准。
- 待决定：船型、比例和背景小样的审美反馈；原型与最终场景既有要求的差异仍需 A 收敛。
- 如果采用，C 按 A 后续规范锁定背景底层；商船、漂流瓶、数值文字和交互物件按状态叠加。本轮去瓶是空海面底图处理，不取消打捞功能。
