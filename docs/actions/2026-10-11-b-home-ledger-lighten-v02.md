# 主页双瓶标签轻量化 — v02

## 状态与背景

- 状态：Superseded。用户 2026-10-12 的桌面双瓶“原图选区／蒙版提取”请求替代此横放瓶轻量化工作，旧成果保留、不继续生成。新工作见 `2026-10-12-b-home-bottles-pixel-mask.md`；本记录不代表用户已确认旧版外观。
- 用户本轮要求：减少整圈高光、乳白雾面和玻璃框存在感；固定前缀缩小简化，数字应最易辨认。保持现有横放构图，用同一主页前后对照，不能靠缩小整张素材或加装饰实现。
- 输入：`scripts/素材/双瓶标签_v01/日期瓶_DAY_透明_v01.png`（1776×598）、`金钱瓶_金币_透明_v01.png`（1810×621）。已实际打开两素材及原主页。
- 主页沿用 `双瓶标签_v01/过程稿/参考_最新主页_r2.png`，SHA256 A3A87B70EE2D7CECFD2279188D8A906F4D7A86F4916D8C651D82B8633252EF14。
- 当前 HEAD 6c7cccf；工作区历史修改及其他窗口变更不触碰。只做图像与检查文件，不修改游戏代码、主页原图、旧素材或系统字体。
- 继续按右口玻璃罐横放、日期在上、金币在下；数字不画进正式PNG。数字预览先保持上一轮 Mali SemiBold 52px，仅作受控比较，不替用户决定最终字体。

## 实施措施

1. 使用内置 image_gen 分别编辑两张现有 PNG，要求保持轮廓、横放角度及右口方向；重新绘制玻璃反射分布，去掉整圈乳白框，减小固定前缀。
2. 新输出保存在 `scripts/素材/双瓶标签_v02/`，旧版完整保留。真实 Alpha PNG 紧裁；不靠整体缩小和新增装饰。
3. 按旧版相同400px显示宽、相同位置叠入原主页。锁定日期/余额数字的字体、字号、位置、内容、颜色和阴影，前后只替换瓶子图。
4. 导出前后全主页与同区域局部并排证据；检查实际Alpha、白雾和轮廓强度、前缀与数字层次、手机静态效果。

## 影响文件树

```text
docs/actions/
  2026-10-11-b-home-ledger-lighten-v02.md  本轮执行和验证记录
  ledger-v02/                            非游戏代码，机械裁切/真实字体合成与检查脚本
scripts/素材/双瓶标签_v02/
  日期瓶_DAY_透明_v02.png                 减弱玻璃、缩小简化DAY后的独立素材
  金钱瓶_金币_透明_v02.png                减弱玻璃、缩小金币后的独立素材
  预览_*.png                            同一主页上的改前改后、局部/手机/透明证据
  素材清单_v02.md                        实际尺寸、位置、检查结果、剩余限制
  检查结果_v02.json                      可复核数据
  过程稿/                               本轮生图原始输出
```

## 自验方法

- 打开新PNG/浅深底/原主页合成；检查真实Alpha、无烘焙背景、完整瓶口及轮廓。
- 比较新旧素材同位置玻璃区域的平均Alpha及视觉观感；数值只辅助，不把Alpha降低自动当作美术通过。
- 同主页前后比较：瓶子摆放不变、画布不缩小、原主页与数字层不重绘。记录生图实际尺寸变化，避免静默拉伸。
- 两图均400px显示宽；相同数字、字形排版不变。前缀高度应明显低于数字字形高度。
- 原图SHA256、瓶子区域外像素差异、手机缩图和六个数字样本的安全区检查。

## 自验结果

部分生成与预览已留存，未完成该版本的最终清单和全部验收。2026-10-12 用户转为桌面双瓶原像素提取，本任务已被替代，不继续补做或将其标为用户通过。

## 提示词与素材生产方式

内置 image_gen 编辑；机械裁切与真实字体排版沿用 PowerShell/System.Drawing，不使用生成模型绘制动态数字。完整提示词在调用时追加。

### 日期罐实际编辑提示词

```text
Use case: precise-object-edit. Edit the PROVIDED transparent PNG; do not create a different bottle.
CRITICAL invariants: retain exactly this jar's horizontal silhouette, same long-body proportions, same pose and same full size in canvas; short mouth and cork on RIGHT, base on LEFT. Do NOT shrink the whole jar. No rotation. No new decoration.
User correction: make the GLASS itself much less visually prominent. REMOVE the thick continuous all-around white/blue-gray frosted band and all milky haze. Replace the heavy frame by very thin subdued partly broken blue-gray contours with only 2 or 3 faint soft reflection accents. No uninterrupted luminous border. No doubled/tripled thick glass edging. Clear untreated transparent glass, NOT frosted glass, NOT a milk-white translucent slab. Large interior and areas previously foggy now genuinely almost invisible with real near-zero Alpha. Glass should disappear softly over the background while the small cork and tiny prefix remain legible. Avoid strong highlights, glare, white bands, heavy outlines, shadows, background texture or cloudy filled panels. Preserve subtle warm hand-painted seaside craft quality, not flat vector lines.
This PNG is the EMPTY overlay under program-rendered digits. Do NOT draw any digits, x or dummy text. Number area stays clear.
Output same original canvas size if possible, one tightly framed true RGBA transparent image, full silhouette and antialiased contour. Do not flatten against black/white/checkerboard. No home imagery.
DATE version: original canvas 1776x598. REPLACE the current oversized fragmented "DAY" pebble word with a much smaller, calmer "DAY" on the left, around the SAME word center. New letter height about 105px on this canvas (roughly 38% of old), total word width about 270px, not more. Simplify into THREE small gently rounded sea-glass letterforms, one clean connected slender shape per glyph with very subtle physical depth. Complete uppercase D A Y exactly; A has crossbar, D a hole, Y a fork. Muted warm gray-beige, less bright/contrasty than the old cream pebbles. Not printed on paper/plaque. No surrounding loose pebble fragments. This prefix must read as a small secondary label; the blank area on the right will receive larger 160px-high runtime digits. No extra details.
```

### 金钱罐实际编辑提示词

```text
Use case: precise-object-edit. Edit the PROVIDED transparent PNG; do not create a different bottle.
CRITICAL invariants: retain exactly this jar's horizontal silhouette, same long-body proportions, same pose and same full size in canvas; short mouth and cork on RIGHT, base on LEFT. Do NOT shrink the whole jar. No rotation. No new decoration.
User correction: make the GLASS itself much less visually prominent. REMOVE the thick continuous all-around white/blue-gray frosted band and all milky haze. Replace the heavy frame by very thin subdued partly broken blue-gray contours with only 2 or 3 faint soft reflection accents. No uninterrupted luminous border. No doubled/tripled thick glass edging. Clear untreated transparent glass, NOT frosted glass, NOT a milk-white translucent slab. Large interior and areas previously foggy now genuinely almost invisible with real near-zero Alpha. Glass should disappear softly over the background while the small cork and tiny prefix remain legible. Avoid strong highlights, glare, white bands, heavy outlines, shadows, background texture or cloudy filled panels. Preserve subtle warm hand-painted seaside craft quality, not flat vector lines.
This PNG is the EMPTY overlay under program-rendered digits. Do NOT draw any digits, x or dummy text. Number area stays clear.
Output same original canvas size if possible, one tightly framed true RGBA transparent image, full silhouette and antialiased contour. Do not flatten against black/white/checkerboard. No home imagery.
MONEY version: original canvas 1810x621. Reduce the existing gold coin on lower left to about 55% of its old diameter, around the same center. Muted old brass rather than shiny gold. Simplify its embossed detail to a soft minimal wave, not heavy raised rings or complex texture. Keep existing small shell but reduce it proportionately and lower its contrast; do NOT add any objects. No ￥/¥/$, letters or numbers. The little coin is a secondary identifier, considerably less prominent than the blank number region. Preserve the right and central number space unobstructed.
```

首轮生成实际尺寸：日期2161×728、金钱2140×735（工具改变了像素分辨率，未人工拉伸）。已实际将原始输出按旧版同一400px显示宽、同一位置和同一数字排版叠回主页；结果玻璃雾面明显降低。首次空白区抽样平均Alpha日期0.108/255、金钱0.958/255，定稿裁切后继续复核。最终不能把生图查看器的低Alpha像素颜色直接当成真实合成底色。


## 边界及待决定

用户确认玻璃轻巧感与数字信息主次；未授权游戏接入、最终字体选择、物理/动画或新装饰。本轮不做真机点击、安全区或裁切验收。
