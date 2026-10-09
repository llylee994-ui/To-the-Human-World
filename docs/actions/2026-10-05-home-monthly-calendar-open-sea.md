# 主页原型：手绘月历与海天薄雾

## 状态与背景

- 状态：Completed（概念图修订完成，未接入引擎）；2026-10-05。
- 用户要求：日历改成自然的手绘月历，保留第几天标识；去掉漂流瓶和远山，呈现海天一色的朦胧感。
- 编辑目标：工作区最新原型 home-storybook-v03.png（执行前发现已有自然台历与正字版本，保留该文件）。本轮按当前请求改为月历与第几天标记；保留室内构图、金剪刀、椅子、商船与近处栈台；远处山岸及其建筑随背景一并移除，避免留下悬空物件。
- 范围为美术概念图；不改变打捞玩法、代码和存档。日期格为造型示意，不引入真实年月规则。

## 实施措施

1. 内置 image_gen 定向编辑月历、海面漂流瓶和远景。
2. 目视核对手绘月历与第1天文字、无漂流瓶和山岸、海天雾蓝衔接、原有室内构图。
3. 保存独立 v04 图片并更新设计入口，保留既有版本。

## 影响文件树

- docs/actions/2026-10-05-home-monthly-calendar-open-sea.md：过程、提示词及核验。
- docs/设计/原型/home-storybook-v04.png：新版总体原型，仍为未分层图片。
- docs/设计/主页原型与分层说明_v02.md：补充最新视觉修订入口。
- scripts/README.md：更新最新原型入口。

## 自验证方法

- 查看最终图片；检查 PNG 完整性、尺寸及保存路径。
- 检查文档引用与 git diff --check。不修改 Lua，不运行引擎测试。

## 自验证结果

- 内置 image_gen 单轮编辑完成，输出 exec-bb7426ee-fa91-4464-94a7-db05aa94495e.png；已保存为项目 v04，旧版本保留。
- 目视核对：月历具有七列日期格、1—31 日期、圈记和“第1天”；纸页自然卷角。漂流瓶、远山岸、远处村落及灯塔均消失；海天边界柔和朦胧，商船、近栈台与原室内主要物件保留。
- Pillow Image.verify 通过，PNG 为 941×1672、RGB；图片与行动记录路径存在，新增文档引用对应这些路径。
- git diff --check 通过，仅 README 存在原有 LF→CRLF 提示。两份用户草案/故事稿哈希与既有记录相同，没有覆盖用户修改。
- 未修改 Lua/data，未运行引擎和手机测试，未切分透明图层，未提交或推送。

## 完整提示词（内置 image_gen 编辑）

```text
Use case: precise-object-edit.
Edit target: the supplied portrait hand-painted seaside workshop game homepage. Preserve the exact framing, camera, indoor architecture, furniture and all object placements.
Make these specific changes:
1. Replace only the calendar page and subtly adapt its existing stand on the upper-left of the desk into a believable handmade MONTHLY DESK CALENDAR. Cream textured paper, two small brass loops, brown cardboard easel, gently curled page corner. On the page a delicate hand-drawn seven-column monthly grid with five rows and small handwritten dates 1 through 31 in sequential order, modest imperfect brown pencil lines. Circle the first date softly in muted terracotta. Beneath the grid, clearly write the exact Chinese text "第1天" as a natural handwritten label large enough to read. Remove the previous giant numeral 1 and the 正 character. No arbitrary real-world month, year, logo or English heading. Keep the calendar approximately its current footprint and perspective; make it feel like a physical everyday handmade calendar, not a UI placard.
2. There must be NO floating bottle anywhere in the sea, no bottle shadow and no bottle-specific circular wake.
3. Remove ALL distant mountains, headland, offshore rocks and the distant village/lighthouse perched on that headland in the upper-right window view. Replace that entire far background with open, quiet, hazy sea blending almost imperceptibly into the sky. Keep only the NEAR right-hand dock beside the merchant boat, the merchant boat itself and foreground dock below it. No floating buildings after removing the land.
4. Sea and sky should become a unified softly painted mist-blue expanse: a nearly lost horizon, pale blue-gray water blending into pale blue-gray lavender sky through a wide soft mist band, slight cream-peach warmth in the high clouds. Eternal late afternoon, never dark. Broad restrained watercolor/gouache washes, very few soft horizontal strokes, matte pigments and gentle handmade paper texture. Remove the hard horizontal horizon line. Calm, airy, dreamy and spacious, not a bright orange sunset, not photorealistic waves. Warm indoor amber wood against cool outdoor fog-blue stays clear.
Strict invariants: preserve the foreground chair, central blank writing mat, empty wooden tray, straight pointed gold scissors, leather book, drawer, coin pouch with "30", cauldron and stove, herbs and jars, net, archive rack, plants, brass bell, merchant boat and NEAR dock. No new decorative objects, no new UI or annotations, no changed layout, no crop. Output one opaque full portrait image.
```
