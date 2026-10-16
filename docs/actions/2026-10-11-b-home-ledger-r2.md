# B-HOME-LEDGER-20261011 r2 — 双漂流瓶信息标签

## 状态与背景

- 状态：Completed（候选素材制作与静态证据交付）；外观及字体待用户确认，真机/前端接入未验收。r2 替代 r1 的纸账签方向，旧文件保留，不修改游戏代码。
- 当前基线：HEAD 6c7cccf；工作区已有大量其他窗口及历史素材修改，本轮不触碰、不提交。
- 用户指定参考：`C:/WINDOWS/TEMP/codex-clipboard-18ab0545-37c4-4733-908d-e3c6e76f9237.png`，1920×1080；已实际打开。
- 最新已确认：两只独立的轻透淡青灰玻璃罐横放，罐口朝右；弱反光。日期罐为石子 DAY，金钱罐以金币替代原计划的 ￥；正式素材无数字、无占位符。少量贝壳装饰。日期罐上、金钱罐下，避开捞网、商船等入口。
- 本轮只交美术候选和真实字体静态预览。日期点击确认、运行时文字、布局接入均由 C 后续处理；不制作弹窗、动画、物理效果。
- 依据：用户本轮 r2；项目 AGENTS.md；横版前端方案及接口文档已读。遵循 project-control-report / action-document / imagegen。

## 实施措施

1. 内置 image_gen 分别生成日期瓶和同系列金钱瓶，使用主页作风格参考；检查字形、玻璃和轮廓。
2. 保存到 `scripts/素材/双瓶标签_v01/`；仅裁去透明外围，不拉伸或改写生成 Alpha。
3. 从 Google Fonts 官方仓库获取 Mali-SemiBold.ttf、Itim-Regular.ttf 及对应 OFL 许可；真实字体排版，不由生图模仿。
4. 用同一位置、同一瓶子尺寸、同一字号/颜色/阴影，输出 A/B 主页预览；另外检查 1、7、12、108、1280、9999 的字形边界。
5. 检查真实 Alpha、浅深底、手机横屏静态缩图、背景无关区域不变；写明实际尺寸与摆放参考。

## 影响文件树

```text
docs/actions/
  2026-10-11-b-home-ledger-r2.md       本轮过程及验证证据
  ledger-r2/                         机械导出/真实字体排版和检查辅助脚本（非游戏代码）
scripts/素材/双瓶标签_v01/
  日期瓶_DAY_透明_v01.png              独立日期瓶底图
  金钱瓶_金币_透明_v01.png             独立金钱瓶底图（按用户追加改为金币前缀）
  预览_双瓶标签_Mali_v01.png           真实 Mali SemiBold 数字，完整主页
  预览_双瓶标签_Itim_v01.png           真实 Itim Regular 数字，完整主页
  预览_*检查_v01.png                  静态字号、透明和手机检查证据
  素材清单_v01.md                     尺寸、Alpha、层级、位置、用途和限制
  fonts/                             官方字体和许可，仅供预览/交接
  过程稿/                            生图原始输出，非最终紧裁文件
```

## 自验方法

- PNG 像素格式与 Alpha 0/中间值/255 计数、可见包围盒和边距；检查空白信息区的半透明值。
- 人工打开原始素材及浅/深背景合成，排查烘焙底色、错字、强反光和杂边。
- 读取字体内置名称/字重；私有字体加载，测量两个字体全部六个测试数值的实际轮廓边界。
- 同尺寸全主页 A/B 差异只能发生于数字绘制区；与原图比较，瓶子区域之外应完全不变。
- 手机静态预览按 800×450 和 844×390 检查（保持原图比例，宽屏留侧边，不伪造裁切适配）；不等同真机交互验收。

## 自验结果

实际运行 `docs/actions/ledger-r2/Export-Bottles.ps1 -Draft` 与无 Draft 正式导出。

1. 字体实际下载成功，私有字体名称 Mali SemiBold / Itim；直接读取 TTF OS/2 字重 600 / 400。此前下载审批连接中断已恢复，fontTools 缺失已用只读 TTF 检查代替，无系统配置改动。
2. 初版56px在未紧裁画布中 Mali 9999 发生超宽；字号改52px，两字体×两素材×六数值共24项通过。全主页A/B只在数字区有3272个差异像素，数字区外0。
3. 原始生图存在极淡Alpha1–7游离噪点撑大包围盒；未紧裁导出保存在过程稿，正式按Alpha≥8包围盒+12px紧裁，不缩放、不改写保留RGBA。日期1776×598、金钱1810×621。四角Alpha均0，外框残留Alpha最大1（约0.4%），如实保留说明。
4. 实际打开：两张全主页、浅/深底、24项数字适配、手机800×450/844×390预览及数字手机比例缩图。未见烘焙背景、矩形底色或明显白黑杂边；灰蓝柔边玻璃仍需要用户审美确认，不宣称已定稿。
5. 日期(24,32,400,135)，金钱(24,200,400,137)。下罐与捞网顶部约48px间隔，未遮捞网、商船、药炉与桌面入口。两版与原图比较，罐子范围外变化0。源图SHA256保持不变。
6. 手机只作静态缩图检查，未运行游戏或真机。两字体示例可辨，844×390完整等比显示下字形约12–13px高，过小屏幕/继续缩小需重验；安全区/平台胶囊/裁切填充与点击由C后续验证。
7. 所有本窗口生成文件保存到新素材子目录，弃用过程稿保留，旧项目资源未覆盖。未提交、未推送、未修改任何游戏代码。

完整可复核数据与交接见 `scripts/素材/双瓶标签_v01/检查结果_v01.json` 和 `素材清单_v01.md`。

实际新增文件：两张独立PNG；Mali/Itim各一张1920×1080预览；透明/数字适配/数字手机缩略/手机各一张证据图；清单与JSON；fonts中两字体及两许可；过程稿中7张生图输出、原主页副本、历史未紧裁候选和检查图；本行动文档与机械导出脚本。没有删除文件。旧未紧裁两图仅移入过程稿，仍可恢复。

## 提示词与工具

内置 image_gen，非 CLI/API。实际提示词在生成时追加。

### 制作纠正与已弃用过程稿

用户在生成期间明确纠正：需要“一个竖漂流瓶横放”，不是大横扁瓶。前两张瓶颈朝上的扁瓶不采用、不作为正式文件；转为传统细长漂流瓶侧躺，瓶塞朝侧面，信息仍正向阅读。此为用户最新决定。

日期旧稿：exec-53681bde-32c4-4ead-89db-e28f931057bf.png（1705×922）；金钱旧稿：exec-fbe0605b-a917-4653-ad54-0c3177ce0069.png。仅保存在过程稿中并标为弃用。

首次日期提示词：
```text
Use case: stylized-concept.
Asset type: one independent transparent game HUD bottle, DATE VERSION.
Input image 1 is STYLE REFERENCE ONLY: the warm finely hand-painted seaside apothecary home. Do NOT reproduce any home background.
Create a small graceful, lightweight, pale blue-gray clear glass message-bottle label, frontal view, isolated on genuine RGBA transparency. Broad gently rounded flattened flask body, horizontal aspect about 1.85:1 INCLUDING its very short narrow upright neck and petite cork. Thin imperfect handmade glass, fine softly warm rim, very restrained highlights. Delicate, not bulky, not glossy CGI. The broad glass interior must be almost completely see-through with real low alpha (roughly 5–15% opacity), not filled with opaque pale paint. No liquid. No paper.
Inside the left third of the body, at about 62% of total height, place exactly "DAY": three complete uppercase glyphs D A Y made themselves of smooth rounded warm ivory sea-glass / small beach stones, gently dimensional, coherent letter strokes and small joints, readable small, not printed text, not letters engraved on a plaque. D has a clear hole, A a clear crossbar and hole, Y exactly two arms and a stem. The glyphs form one horizontal line. Their height is about 22% of the total bottle height. Keep right 50% of body entirely clean continuous transparent blank space for runtime numbers. Prefix and eventual numbers will share one baseline; DO NOT generate any numbers.
Whole bottle visible, tiny soft contact shade only, no large drop shadow, tightly framed with small transparent margins, output sufficient crisp pixels around 1400px wide.
Do not add shells/coins for this date version. No x, no placeholder, no numerals, no other text, no symbols, no watermark, no ribbon, no rope, no plaque, no white/black background, no baked checkerboard, no scene or room reflected inside glass. Preserve true semitransparent glass, opaque pebble letters and cork, and clean antialiased edges.
```

首次金钱提示词：
```text
Use case: stylized-concept.
Create ONE MONEY bottle game HUD asset on genuine RGBA transparency. Input image 1 is the matching DATE bottle STYLE AND CONSTRUCTION reference. Input image 2 is HOME PAINTERLY STYLE reference only. Never reproduce either background.
Make the companion bottle to image 1: same pale blue-gray very thin handblown glass, cork, gentle warm lighting and finely painted rendering; similar front-facing small broad flask, only slightly rounder/taller in body than the date bottle, aspect around 1.8:1 including short upright neck. Light and graceful. Reduce rim glints slightly. Keep interior truly see-through, low alpha about 5–15%, no opaque mist fill or scene reflections.
Replace DAY with exactly the currency glyph "￥": one rounded warm ivory pebble/sea-glass glyph on LEFT side, with TWO distinct horizontal bars crossing its upright stem beneath the fork. The glyph itself is built from several rounded smooth little beach stones, NOT printed or engraved on a plaque. Clear correct Y fork + vertical stem + two bars. Slight thickness, no dark outline. Its cap height and visual thickness match the date pebble letters. Place its glyph in left third at the SAME relative height as DAY, about 62% total height. Leave the right 50% clear continuous empty transparent space for four-digit runtime numbers.
At the very bottom of bottle, BELOW the information line, just TWO tiny worn warm brass coins and ONE small ivory seashell arranged loosely and subtly, not heaped, not behind numbers, no sandbed.
Whole bottle, cork, fine edges and tiny soft base shade complete, tight canvas with small transparent margins. No DAY text, no numbers, no x or placeholders, no additional symbols, no paper, no ribbon, no ropes, no strong highlights, no heavy thick glass, no big shadow, no white/black/checkerboard background, no watermark. True transparent exterior and semitransparent interior, opaque stone glyph and cork. Output crisp around 1400px wide.
```

字体下载初次受阻：沙箱 Invoke-WebRequest Authentication failed；curl schannel SEC_E_NO_CREDENTIALS。首次受控下载审批服务连接中断，命令未执行。再次正常申请受控下载成功，四个字体及许可文件均已保存，没有跳过证书验证或修改系统设置。

用户进一步明确：两只瓶口均朝右。首张横放向左稿 `exec-9ebb72ca-5c0c-4f42-a1ed-d1bc406fdd66.png`（2172×724）弃用；除方向需调整，其数字留白区存在透明度突变，也须修复。字形不得镜像。

最新外形追加：用户要求“瓶子样式类似于玻璃罐子”。执行为直身、短颈、较宽口的玻璃小罐侧躺，罐口朝右；不沿用长酒瓶颈。DAY、￥保持正向可读。字体文件已取得；fontTools 元信息读取因本机未安装该模块失败，转用字体文件内置表与私有字体加载核验，不安装依赖。

最新表面追加：用户要求“玻璃罐子不要那么有光亮”。两只右口玻璃罐首稿反光偏强，需降低玻璃亮边与金色闪点后才正式交付；保持字形、位置、朝向和真实透明度。原始透明图在查看器中的近零 Alpha 彩色/黑色显示不能单独视为杂边；日期罐已实际在深棕底合成验证，中央 Alpha 0–10，没有不透明黑洞。


## 字体来源

### 首轮横放向左（弃用）

```text
Use case: stylized-concept. One independent date HUD game asset, true transparent PNG.
Reference image: warm finely painted seaside apothecary scene, STYLE ONLY, no background copied.
CRITICAL SHAPE: A NORMAL TRADITIONAL SLENDER UPRIGHT MESSAGE-IN-A-BOTTLE TURNED ON ITS SIDE BY 90 DEGREES. It is lying HORIZONTALLY, long axis left-to-right, cork and slender bottle neck point directly LEFT at 9 o'clock, rounded bottle base faces RIGHT. A long, graceful ordinary wine/message bottle lying down. NO neck on top, NO squat oval hip flask, NO broad horizontal flask. Bottle total length about 3.2 times its body diameter. Long narrow left neck flows through rounded shoulders into a simple cylindrical body on right. Nearly orthographic front/side view, no extreme foreshortening. Keep entire silhouette.
Delicate pale cyan-gray thin handblown glass, small cork at far left, restrained warm reflections, finely hand-painted not plastic CGI. Most glass interior must have REAL very low alpha, 5–12% opacity, so a wood background will remain clearly visible when composited. No opaque pale interior, no liquid, no paper, no scene reflections. Thin rims, sparse highlights, no strong glare.
In LEFT portion of the MAIN CYLINDRICAL BODY (not the narrow neck), put exactly "DAY", oriented normally upright for reading left-to-right despite the bottle lying sideways. D A Y glyphs made from small rounded ivory beach stones/sea-glass, the glyphs themselves have slight thickness, not text printed on paper/stone panel. Correct complete D loop, A crossbar and Y fork. Slender softly rounded strokes, no chunky black outlines. Leave the remaining RIGHT HALF of the main bottle body as uninterrupted clear blank space for four runtime digits beside DAY. No digits now. Text baseline is horizontal, glyph height about one third of bottle body diameter.
No other text, x, numerals, labels, rope, ribbons, charms, shells, coins, heavy shadows, white background, black background, checkerboard, watermark. Only one complete lying bottle with DAY and empty transparent number area. Small necessary transparent margin, crisp sufficient resolution.
```


### 右口日期罐

```text
Use case: stylized-concept. One independent transparent game DATE glass-jar label.
Reference image is ONLY for warm finely hand-painted seaside-house style.
CRITICAL silhouette requested by user: A SMALL ORDINARY STRAIGHT-SIDED GLASS STORAGE JAR LYING ON ITS SIDE, with its WIDE MOUTH and small cork ON THE RIGHT, closed rounded base ON THE LEFT. Horizontal long axis. Not upright. A jar that would be tall-ish if stood on its base, now turned 90 degrees clockwise. Cylindrical straight body with gently rounded corners, very SHORT neck and wide opening similar to a small herb-storage jar, NOT a long wine-bottle neck and NOT an oval hip flask with its neck above. Front/side view with minimal perspective. Total horizontal length about 2.8 times diameter. Cork a modest short natural plug on the right.
Lightweight thin pale cyan-gray handmade glass, delicate soft outlines, few tiny warm highlights. Same cozy finely hand-painted quality as reference. No heavy glass walls, harsh glares or oversized cork.
The ENTIRE glass body interior is smooth, evenly see-through with REAL semi-transparent alpha around 5–15% opacity, including behind the letters and the blank number area. This is a PNG overlay for a wooden home. No opaque pale fill, no cut-out-shaped hole, no dark smudge, no abrupt alpha transition, no scenic reflection. Let background show uniformly through glass.
Inside the LEFT part of body place exact uppercase word "DAY", normal upright readable horizontal line. D A Y are formed themselves from rounded ivory little sea-glass / beach pebbles with slight thickness, cohesive clean strokes, no plaque or paper under them. The word occupies roughly first 35% of usable body, with its letters about 36% of jar diameter tall. A crossbar and D enclosed hole clear. Leave adjacent RIGHT HALF of body clean continuous empty space for runtime digits, before the short neck.
No numbers, x, additional words, other symbols, shells/coins in this date jar, liquids, paper, tags, ropes, ribbons, large shadow, background surface, white/black/checkerboard background or watermark. One complete small lying glass jar, whole cork and soft edges, tightly framed with small transparent margin. Output genuine RGBA transparency, preserving low-alpha glass and opaque stone letters/cork.
```


### 右口金钱罐（￥前缀弃用）

```text
Use case: stylized-concept. Create ONE transparent MONEY glass-jar label.
Image 1 is the DATE jar: match its rendering, thin clear glass, warm ivory pebble lettering, cork, and proportions closely. Image 2 is home style reference only.
The money jar is also an ordinary straight cylindrical small storage jar LYING HORIZONTALLY ON ITS SIDE, BASE AT LEFT, WIDE SHORT-NECKED MOUTH AND CORK AT RIGHT. Never put mouth on top or at left. Same family as date jar but body only slightly rounder, about 5–10% greater height at same total length. Nearly front/side view, minimal perspective. Keep full outline complete.
Replace "DAY" with exactly the single upright normally readable currency glyph "￥" at left of main body. Make the glyph itself from smooth round ivory sea-glass/pebble pieces with slight thickness, like DAY. Correct anatomy: two diagonals form Y fork, one vertical stem beneath, TWO CLEAR DISTINCT horizontal bars crossing the stem below fork. No plaque, engraved panel, paper, or printed font. Glyph cap height like DAY; not bigger.
Right half of main body before neck is continuous clear empty space for runtime digits; do NOT draw digits or placeholders.
Only at the lower interior edge BELOW the text baseline, a small subtle cluster of TWO tiny muted brass coins and ONE tiny ivory shell; no sandbed, not under the number field, no heaps.
Very translucent pale cyan-gray glass, REAL alpha transparency, soft warm rim glints kept sparse, no bright thick inner frame. Main interior nearly invisible, gently continuous transparency even behind glyph. No opaque paint, white or black fill, checkerboard, dirty smear or abruptly erased patch. No home imagery, no scene reflections, no background.
No DAY, no numerals, no x, no other letters/symbols, no watermark, no liquid, no rope or charm, no large shadow. Delicate hand-painted isolated sprite, true RGBA, complete tight crop small margin.
```


### 日期罐减光

```text
Use case: precise-object-edit. Edit the single transparent glass jar asset shown. KEEP the existing horizontal side-lying jar silhouette, short wide neck and cork on RIGHT, base on LEFT, same proportions, nearly orthographic view and thin pale cyan-gray transparent glass.
The user's main correction is MUCH LESS SHINY. Remove about 85–90% of glossy specular highlights and ALL gold blazing reflection streaks on the glass. No shiny gold glass edging. Use soft diffuse ambient light, subdued softly painted blue-gray contours, just a few faint broad soft reflections, gently aged clear glass. Glass must still be TRANSPARENT and lightweight, not milky frosted/opaque. Most body interior has genuine near-zero alpha, gently continuous rather than a visibly erased cutout. No glossy 3D render, no glistening white bars, no deep glass thickness or heavy dark outline.
Keep opaque cork and main information-prefix detail, crisp but painterly. Keep right-hand portion of main body clear uninterrupted for runtime numbers. NEVER generate digits, x, a plaque, paper, scenery, surface, shadow block, checkerboard, watermark or any background. True RGBA transparency, tight complete outline and small margin.
DATE VERSION: Keep exactly "DAY" in upright normally readable ivory pebble/sea-glass letterforms on left of body, no mirror, complete correct D A Y. Keep original letter scale and positions. Only reduce glass glare, preserve all other essential structure.
```


### 金钱罐减光并换金币前缀

```text
Use case: precise-object-edit. Edit the single transparent glass jar asset shown. KEEP the existing horizontal side-lying jar silhouette, short wide neck and cork on RIGHT, base on LEFT, same proportions, nearly orthographic view and thin pale cyan-gray transparent glass.
The user's main correction is MUCH LESS SHINY. Remove about 85–90% of glossy specular highlights and ALL gold blazing reflection streaks on the glass. No shiny gold glass edging. Use soft diffuse ambient light, subdued softly painted blue-gray contours, just a few faint broad soft reflections, gently aged clear glass. Glass must still be TRANSPARENT and lightweight, not milky frosted/opaque. Most body interior has genuine near-zero alpha, gently continuous rather than a visibly erased cutout. No glossy 3D render, no glistening white bars, no deep glass thickness or heavy dark outline.
Keep opaque cork and main information-prefix detail, crisp but painterly. Keep right-hand portion of main body clear uninterrupted for runtime numbers. NEVER generate digits, x, a plaque, paper, scenery, surface, shadow block, checkerboard, watermark or any background. True RGBA transparency, tight complete outline and small margin.
MONEY VERSION: The user now REPLACES THE ENTIRE PEBBLE ￥ GLYPH WITH ONE COIN. Completely remove all pebble currency strokes. In their place at left of body, one small warm muted old brass GOLD COIN seen face-on, mildly rounded relief and a very simple embossed decorative wave, NO writing, NO ￥/¥/$ symbol, NO numerals. Coin must be small and restrained (diameter about 30% of jar height), enough to identify money, not filling the left half. Keep ONE tiny ivory shell and at most one tiny extra coin resting along bottom, subdued and below number line. Clear right body for balance. No other letters/symbols.
```


## 字体来源（链接）

- https://fonts.google.com/specimen/Mali
- https://fonts.google.com/specimen/Itim
- https://github.com/google/fonts/tree/main/ofl/mali
- https://github.com/google/fonts/tree/main/ofl/itim

## 待确认

用户确认外观及数字字体；手机端运行时点击、安全区与裁切由 C 接入后验证。
