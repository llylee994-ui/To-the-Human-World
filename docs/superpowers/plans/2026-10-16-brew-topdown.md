# 俯视炼药与落料过渡 Implementation Plan

> 用户已确认最新概念稿及交互修订，直接在当前 Maker 工作区使用 executing-plans 执行，不使用子代理，不创建分支、提交或远端构建。

**Goal:** 接入斜俯视铜锅、完全俯视四格木托盘、无名称/热区拖放和落料动效，确保查看来信不遮挡信息。

**Architecture:** BrewLayout 统一来信信息/按钮、锅口与原料格坐标；BrewArt 管理透明 PNG 裁切；BrewInteraction 只管理临时落料动画；BrewView 组合现有模型与视图。

**Tech Stack:** UrhoX Lua 5.4，UI.Scale.DEFAULT、UI 内 NanoVG，透明 PNG，lupa 回归及原生内存夹具。

## Constraints

- 所有正式命令沿用 PlayModel，不改数据/玩法/库存/存档或引擎库；原料四种、设备容量照旧。
- 拖动显示物品本体；不显示额外物品名称或任何投放区域。词卡本体文字保留。
- 锅口命中范围稍大但避开纸槽、侧栏、来信；合法松手只提交一次，保存成功才播放落料；无效松手回位。
- 熬制按钮仍为独立操作，落料期间不可提前试做；失焦/切页/尺寸变化取消临时显示而不撤销已保存草稿。
- 来信按钮固定独立矩形，文字容器在按钮前留出间隔并裁剪；长文本省略，点击可读完整原信。
- 本轮新素材从已认可概念提取生成；原始参考保留，实际 PNG 放 assets/image/brew-topdown，图片文字由 UI 绘制。
- 每批编辑查询预览状态；存活刷新取 logs/check，停止不启动。

## Task 1：先补真实业务与布局失败测试

**Files:** scripts/ui/landscape/tests/BrewWorkbenchTest.lua。

- [x] 验证信息区与查看来信矩形在五种尺寸下分离，锅口扩展不覆盖药槽。
- [x] 验证成功保存先于落料、动画帧不写盘、重复释放不重复提交、失败无成功演出、落料期间不熬制及取消保留草稿。
- [x] 运行 run_brew_workbench.py 确认新增行为在旧代码失败。

## Task 2：素材与交互接入

**Files:** BrewArt.lua（新）、BrewBanner.lua（新）、BrewLayout.lua、BrewInteraction.lua、BrewView.lua，assets/image/brew-topdown/。

**Interfaces:** Interaction.flight/SampleFlight() 表示约 .38 秒落料或 .18 秒回位，Update 推进后触发小范围涟漪；Layout.wishText/wishButton 分离；Art.Pot/Tray/DrawIngredient 统一原图帧。

- [x] 复制已生成透明锅及四格空托盘，记录 alpha 帧、生成来源和用途。
- [x] 替换锅与托盘，四格图片和静态标签独立可交互；进入近景有短淡入过渡。
- [x] 删除跟随名称与热区描边/填色，投料采用运动/缩小/淡出，成功到达后涟漪。
- [x] 分离来信两行摘要与按钮，禁止绘制越界；重读当前来信功能保留。
- [x] 跑专项及托盘/相机回归、LSP、diff；检查/刷新存活预览。

## Task 3：原生证据和收尾

**Files:** tests/BrewNativeProbe.lua，docs/验证/evidence/brew-topdown-r3/，scripts/actions/2026-10-16-brew-topdown.md。

- [x] 用户明确选择不启动本地预览；原生探针补充边界及落料帧断言但关闭，执行状态为未运行。
- [x] 两张新 PNG 已实际阅读、alpha 检查通过；原生截图及手机验收未执行，开关关闭，预览保持 stopped。
- [x] 记录通过项、既有 check/LSP 限制与未验收手机；不提交或推送。

## 执行结果

专项 98、托盘 64、相机 383 项通过；HomeEntry 整单回调通过，旧热点几何断言仍失败。LSP 仅两条既有 ERROR，无新增。详见 scripts/actions/2026-10-16-brew-topdown.md。
