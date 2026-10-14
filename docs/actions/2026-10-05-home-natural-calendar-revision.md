# 主页原型：自然台历、正字计时与开阔海面

## 状态与背景

- 状态：Completed（美术原型修订完成，未接入引擎）；2026-10-05。
- 用户要求：日历更自然，日历下有“正”字代表时间；去掉漂流瓶与远处的山。
- 编辑目标：docs/设计/原型/home-storybook-v02.png。保留室内构图、金剪刀、商船、近岸码头和雾蓝恒定傍晚。
- “正”字本轮仅展示计时的美术表达，笔画与游戏时间的换算尚未定义；不修改游戏逻辑。

## 实施措施

1. 用内置 image_gen 定向编辑已有原型：自然纸质台历、下方手写正字，移除海上瓶及远山。
2. 保存独立 v03 PNG，保留 v02；原型说明增加最新图与修改记录。
3. 目视检查要求和构图；核对图片可读与文档差异。

## 影响文件树

- docs/actions/2026-10-05-home-natural-calendar-revision.md：本轮记录及提示词。
- docs/设计/原型/home-storybook-v03.png：已保存的修订概念图。
- docs/设计/主页原型与分层说明_v02.md：追加最新修订入口和计时边界。

## 自验证方法

- 查看输入与输出：日历纸质结构、正字、无海上瓶、无远山；室内和商船保留。
- 检查 PNG 文件尺寸及可读性；git diff --check。
- 仅美术原型，不做引擎运行测试。

## 自验证结果

- 内置 image_gen 单轮编辑完成，原始输出 exec-36fd9fde-c832-40be-b053-9938e05b0982.png；完整提示词附后。
- 已目视核对：纸质双环台历、卷角、日期 1 和下方手写正字清晰；海上瓶及专属水纹消失，左侧与中央远山消失；右侧近岸村落、灯塔、码头、商船和室内构图保留。
- 已复制到项目 v03 独立文件，保留 v02；Pillow verify 通过，941×1672，RGB。
- git diff --check 通过（既有 README 提示 LF→CRLF）；前端草案与案件故事稿的 SHA256 和上轮记录一致，既有用户修改未变。
- 本轮未更改 Lua、data 或用户既有故事/前端草案文件；未运行引擎、未提交推送。正字与时间的换算仍未定义，属于概念表现。

## 完整提示词（内置 image_gen 编辑）

```text
Use case: precise-object-edit.
Edit target: the supplied portrait illustrated seaside workshop homepage. Make ONLY these localized changes, retaining the exact camera, portrait proportions, layout, warm hand-painted storybook treatment, furniture and all other objects.
1. Replace the small standing calendar on the upper-left corner of the desktop with a more naturally illustrated, believable old-fashioned paper desk calendar: a simple warm brown cardboard easel, a visible modest stack of cream paper sheets, softly curled lower page corner, two small brass binding loops, a restrained date layout with a clear numeral "1" and small subtle calendar ruling. It should feel like an everyday handmade calendar resting in the scene, not a flat UI sign or a notebook with large lettering. Keep approximately its current location and footprint.
2. Directly BELOW the calendar's date area, in the lower part of its cream paper face, add a clearly legible single handwritten Chinese tally character "正" in dark brown pencil. The date and the tally are separated vertically with breathing room. The five strokes of 正 must be correct, natural and readable, a hand-recorded passage-of-time mark. No Western tally marks.
3. Completely remove the floating glass message bottle from the sea at left of center, including its bottle-specific concentric wake and reflection. Reconstruct uninterrupted quiet mist-blue painted water.
4. Remove the distant mountain silhouettes across the LEFT and CENTER horizon. Replace them with an open soft hazy sea horizon and the existing pastel dusk sky, with no peaks or islands on that far horizon. Keep the nearer RIGHT seaside village, lighthouse headland, stone docks and merchant boat in place, as they are distinct near-coast scene landmarks.
Invariants: preserve the foreground chair, desk, central blank writing mat, empty tray, straight pointed golden scissors, leather book, purse and its 30 tag, cauldron and stove, net, archive rack, plants, brass bell, nearby coast and merchant boat. No new objects. The sea stays soft, quiet, slightly misty, muted fog blue; warm room contrasts with cool sea; eternal soft early evening, never nighttime. Keep broad handmade brushwork, not photographic water. Do not redesign or zoom/crop the composition. Opaque full scene.
```
