# 木柜台商店实施计划

**Goal:** 交付木柜台商店与商店/炼药共用的四种透明原料贴图。

**Architecture:** ShopView 独立创建浮层，以同一个 ctx/session 获取只读投影，通过 PlayModel.Buy 购买；IngredientArt 维护前端图片映射。AppView 保留现有导航、消息和胶囊避让，Panels 只在炼药原料行添加图片。

**Tech Stack:** UrhoX Lua 5.4、urhox-libs/UI、Maker 图片工具、既有隔离 Lua 测试。

## Global Constraints

用户已批准木柜台近景。动态信息用 UI 控件；不改变四种原料的价格、属性、限购或购买接口。不修改 main/PlayModel/core/systems/data，不改玩家槽，不提交/构建。直接在当前 Maker 工作区限定路径实施，保留他人修改。停止预览不启动。

## Task 1: 资源生成与共用映射

- [x] 用 Maker batch_generate_images 生成一张空柜台背景、四张独立透明商品。
- [x] 核对实际本地路径、RGBA alpha、尺寸；逐图查看完整轮廓和画风，保存生成回执及来源。
- [x] 新建 scripts/ui/landscape/IngredientArt.lua，提供 Background 与 Get(ingredientId) -> 图片资源相对路径；Panel(ingredientId,props) 创建 contain 图片控件。
- [x] 查询 preview status；仅存活时刷新取证。

## Task 2: 商店浮层

- [x] 在现有 File/UI 测试宿主中加入 ShopViewTest，用真实 GameSession 检查选择不写入、选定夜露后购买正确来源、售罄与余额门禁、保存失败、导航和草稿保留。
- [x] 新建 scripts/ui/landscape/ShopView.lua，Render(ctx,overlay) 创建背景、header/关闭、消息、两列商品和详情。ctx.shopSelectedId 保存显示选择，不进入存档。
- [x] AppView renderPanel 在 shop 分支调用 ShopView.Render，复用 panelHeader/panelNotice/panelNoticeArea、closePanel 与 buy_<ingredientId> IDs。
- [x] 商品选择触发 model.dirty；购买只调用 ctx.model.Buy(id)，状态始终重读 GetShopView。空列表与查询失败显示文字。
- [x] 小屏使用紧凑商品格、独立详情滚动；检查 800×360、16:9、20:9、4:3。

## Task 3: 炼药复用与交付

- [x] Panels.Brew 原料行添加 IngredientArt.Panel，保留 add_/minus_ 按钮与投料行为。
- [x] 运行商店专项、主页接入、海边流程、HUD 检查；Lua LSP 检查新增/修改文件。
- [x] 查看离线排版证据并注明层次；若预览存活，按官方流程刷新后取当前 logs/check；未运行原生时明确记录限制。
- [x] 由独立代码审查子代理复核购买、输入阻挡、安全区和共用资源；处理重要问题。
- [x] 写 scripts/actions/2026-10-13-counter-shop.md，列实际完成、测试、生成资源、待验项和人工步骤。
