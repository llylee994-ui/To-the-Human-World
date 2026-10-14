# B 窗口桌上漂流瓶排与中央信件

## 状态与背景

- 任务编号：B-20261009-desktop-bottles-letter；状态：In progress。
- 用户最新方向：取消点击/拉开抽屉查看内容的方案，漂流瓶与信件直接出现桌面，抽屉保持附件现状。本轮仅视觉与素材，不实现逻辑或动画；此处记录用户决定，后续正式规范由 A 统筹。
- 唯一构图依据为本轮附件 `codex-clipboard-6b45a497-b088-4592-bf13-d80753396ab4.png`，1080 × 1920 RGB，SHA-256 `8C191A1B9F1C19853223DF5215DFD7493A882D872B57CC6D7573A2648D15FD9D`。已目视，不使用此前941宽背景替代。
- 保留日历、花瓶、捞网、炼药区、托盘、剪刀、右侧书本、桌垫、海景、抽屉等既有位置和表现。
- B 首版建议（非用户已冻结数量）：4个高矮/瓶型/间距不同的卷信瓶，放在日历右后方、窗前木桌，止于窗户中部附近；中央信件采用单张展开纸，宽裕正文区域留白，不加信文、地址、寄信人。
- 严格按用户顺序：先完整效果图并检查，再以其造型/位置提取两组素材，最后用最终透明文件回放到原底图验证；不得用先生成素材拼图冒充第一步，也不得把二次生成整图冒充实际回放证据。
- 项目 AGENTS 沿用已读未变化版本；docs/scripts 无子级 AGENTS。已读取 project-control-report、imagegen、action-document。图片统一放 scripts/素材，不覆盖旧版，不改其他窗口制作的现有器物。

## 实施措施

1. 原样归档最新附件，内置 image_gen 生成4瓶 + 单张空白信纸的完整主页效果图。
2. 先目视完整图，检查瓶脚位于桌面而非海上、日历未被挡、瓶组在中部前结束；信纸在桌垫中心、有桌面透视与软阴影，正文留白且未碰剪刀/托盘。
3. 完整图通过上述检查后，分别以内置 image_gen 提取瓶排和信件。保留四瓶的相对位置/形态、玻璃真实半透明、卷纸、信纸角度与必要投影，外围透明且不含矩形桌面/海景。
4. 按完成图坐标注册两组 PNG；输出紧致透明素材并记录左上角位置/原尺寸，或使用与底图相同画布在 (0,0) 叠加（按实际结果确定）。导出只处理画布、缩放/平移与边缘容纳，主体由图像工具生成。
5. 使用未改原底图与最终两张 PNG 真实 alpha 合成复原预览，并比较完成图与回放图的坐标、遮挡和局部边缘。AI 提取可能重绘的区别如实说明，不承诺自动逐像素一致。
6. 保存原底图、先行完成图、两张透明素材、实际回放图、局部检查、放置说明；更新 B 清单入口及 A 交接记录。

## 影响文件树

```text
docs/actions/2026-10-09-b-desktop-bottles-letter.md          范围、完整提示词、验证和交接
docs/设计/B窗口_分层素材规划_v01.md                       本轮候选入口及抽屉方向更新
scripts/素材/参考_桌上瓶信_原始主页_v01.png                原始底图原样归档
scripts/素材/主页效果_桌上四瓶与空白信件_v01.png            计划：先生成的完整效果图
scripts/素材/H08_桌上漂流瓶排_四瓶_透明_v01.png             计划：两组之一
scripts/素材/H20_中央展开信件_空白_透明_v01.png             计划：两组之一
scripts/素材/预览_桌上瓶信_原位复原_v01.png                计划：真实透明素材叠回原底图
scripts/素材/预览_桌上瓶信_局部核验_v01.png                计划：完整图/回放/透明边缘核验
scripts/素材/桌上瓶信_放置说明_v01.json                    计划：编辑器坐标、尺寸与源文件
scripts/素材/过程稿/                                     按需：未经画布注册的内置输出
.tmp/b-desktop-bottles-letter/                             按需：导出/预览辅助，不接入游戏
```

## 自验证方法

- 原底图、完整图与回放图均应为1080 × 1920；保留源哈希，核对既有物件位置不变。完整图允许 AI 细微重绘误差但不允许挪动物件；实际回放在新增物件 alpha 外必须与原图一致。
- 在完整图阶段实数瓶子数量、核对桌面后缘与瓶脚落点；确定瓶组/信纸的包围盒和注册锚点，之后再发提取请求。
- 两张最终素材为 RGBA、大片 alpha=0，玻璃与投影确有部分 alpha；在深浅色与原位预览上目视无桌面/海景方块、无强背景色晕，完整轮廓/正文留白。
- 真正读取最终 PNG 按放置说明绘制预览，检查大小、角度、位置、遮挡及复原差异。正文不烘焙信文，日历等原有文字不改变。
- Python/Pillow/NumPy 仅只读统计；生成与素材编辑使用内置 image_gen。本地渲染用于导出定位/真实预览。无 API/CLI 回退，无 Maker 构建或游戏状态测试。

## 自验证结果

Pending。

- 首稿 `exec-9574e103-836c-481e-8297-6fdb7d16b522.png`：已目视，4瓶均在桌上且含卷信，纸张为空白；但瓶身比预期高、瓶组终点偏右，纸张也略挤近前托盘。先对完整效果稿缩小瓶组至75%、信纸约88%，再做提取。此时尚未进行两组提取，遵守先整体后分层的顺序。
- 比例修正版 `exec-6bd5be27-2bfb-495e-bd17-027117350e15.png` 为941 × 1672，已目视瓶排缩到窗中附近、信纸正文完整留白。但生成器误删原日历文字，其他区域也有轻微重绘，因此先将完整图归一至原1080 × 1920，只保留两处新增区域、其余使用原底图，完成整体检查后才开始提取。

## 工具与完整提示词

### 先行完整效果图

内置 image_gen；`transparent_background=false`；编辑目标为本轮最新附件。

```text
Use case: precise-object-edit / compositing.
Edit the provided latest home-screen illustration, retaining its exact 1080 x 1920 portrait framing and camera. Add ONLY (A) a row of FOUR collected message bottles on the back of the desk and (B) one unfolded blank letter in the middle of the writing mat. This is the complete home-screen composition first, not a sprite sheet.

A — FOUR MESSAGE BOTTLES ON THE DESK:
Place exactly FOUR small corked sea-glass bottles standing on the rear wooden DESKTOP, just in front of the window wall, starting to the RIGHT of the existing calendar and ending near the horizontal middle of the window. Approximate full-canvas group bounds x275–565, y680–840; every bottle foot sits on the desk around y810–830 (the desk's rear edge here is around y770), with a small believable contact shadow. Do not put them in the sea, on the vertical wall, floating in air or on top of the calendar.
They read as a loose single row, but have different heights, widths, shoulder shapes and corks, irregular gaps and a little front/back depth. Suggested silhouettes: slim tall gently green bottle, shorter rounded pale blue bottle, clear slightly squarer medium bottle, one modest aqua rounded shoulder bottle. Vary the spacings and heights organically. All four remain distinct and largely unobscured. Each visibly contains a rolled cream LETTER/SCROLL rather than herbs, potion liquid or flowers. The glass is lightly tinted and translucent, with quiet restrained reflections, not glossy white stripes everywhere. Keep the group compact and secondary: no oversized bottle, no fifth bottle, no uniform duplicated display and no crate or shelf.
Do not obscure or move the existing day calendar and vase on the left. Leave a generous gap before the purse and potion area on the right, which start around x760. Do not fill the middle of the writing mat with bottles.

B — THE CENTRAL LETTER:
Add ONE generously sized unfolded sheet of warm ivory writing paper lying flat on the CENTER of the mat, roughly within x255–750, y955–1245. It is the main focal object of the desk work area, with a wide unmarked text field. A very faint natural fold crease and slight corner curl are allowed; no extra stack is needed for this first version.
Fit the paper to the actual desk plane: seen obliquely from above, the far edge slightly receding/narrower, its long edges aligned loosely with the mat perspective and a slight casual rotation. Paper texture should be quiet and low contrast, brighter than the mat but not white-hot; thin soft contact shadows beneath the edges make it physically grounded. Keep enough space beside the existing right-hand scissors that they feel ready to cut a passage; do not overlap or move the scissors. Do not cover the front tray.
The entire large text area MUST BE BLANK. No ink text, sender, address, handwriting, placeholder lines, stamps, wax seals, printed decoration, symbols or UI boxes. The future game supplies text.

PRESERVE ALL EXISTING THINGS:
Do not move, resize, rotate, remove or redesign the calendar, flower vase, fishing net, wall botanical frame, shelves and herb illustrations, purse, herb jars, cauldron/fire/steam, bowl, scissors, right-side books, front word-slip tray, writing mat, chair, drawers, handles, window and scenery. The drawer remains shut and unchanged; no new drawer UI. Do not add a ship, sea bottles, people or additional props.
Match the source's warm-left evening light, soft painted edges, subtle matte textures, natural contact shadows and warm wood/cool sea palette. Keep the seascape and table perspective exactly as given.
Full opaque PNG illustration, exactly 1080 x 1920, no crop or camera change.
```

## 交接对象与汇报内容

### 完整图比例修正提示词

```text
Revise Image 1 (the newly composed scene). Image 2 is the original base, and all its existing furniture and objects must retain their original relative positions.

The new bottles in Image 1 are too tall and spread too far right. Make ONLY these two placement refinements:
1. Scale the FOUR message bottles and their contact shadows down to 75% of their current size as one group, keeping the group's LEFT end just to the right of the day calendar. Reposition the smaller group so ALL FOUR BOTTOMS still rest firmly on the rear desktop, slightly behind the calendar's front feet. They should occupy only the span from the calendar's right side to around the middle of the window, ending well before the purse. On the 1080x1920 original, aim for group x275–570, bases y815–833. Preserve each existing bottle's shape/color/cork/rolled letter, the differing heights and irregular gaps. Do not add/remove bottles. They must be small collected message bottles, subordinate to the reading area and the large herb jar at right.
2. Make the single unfolded blank central letter about 12% narrower and 12% shorter than Image 1, retaining its current slightly oblique paper perspective. Center it on the mat with a visible sliver of mat between its lower-left edge and the front tray, and a comfortable gap to the scissors on its right. A target area on the 1080x1920 original is roughly x290–750,y950–1225. Keep the broad writing surface completely blank and its crease faint.

Preserve EVERYTHING ELSE from Image 2: original calendar, vase, net, pot/fire/steam, jars, purse, bowl, scissors, books, word tray, wall shelves, sea, window, mat, drawer and chair. Do not shift any existing object to make room. Keep original warm light, painted style and original composition/aspect ratio. No text on the new paper or bottles, no ship, no new props.
Return the complete opaque portrait home illustration, preferably the original base's exact 1080 x 1920 canvas.
```

- 交接对象：A 统筹与审查，由用户转发。
- 任务编号与参考版本：B-20261009-desktop-bottles-letter；本轮1080 × 1920附件，不同于此前BG04/BG05尺寸。
- 用户已确认：抽屉交互方向取消、抽屉视觉保持；桌面后排瓶与中央空白信件；先完整效果、后提取两组，保留底图与位置尺寸。数量/具体瓶型未定。
- B 推荐：4瓶 + 单张展开信纸，减少重复陈列和纸堆，给中央正文与右侧操作区留空间。此次数量是首版示意，不是库存容量规则。
- 成果与来源：以本记录实际完成结果与最终文件为准。
- 待决定：用户对瓶数、纸张形式及总体视觉的采用；不额外请求已授权生成/提取的确认。
- 如果采用，C：按最终放置说明导入两组；正文由游戏文字层提供。无需本轮实现抽屉替代逻辑、动画或交互。
