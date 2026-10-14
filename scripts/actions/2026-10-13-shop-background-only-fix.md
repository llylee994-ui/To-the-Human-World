# 商店只显示背景的问题

用户手机复现：进入商店只显示背景，没有分类、商品和详情。Maker 运行日志 watcher 没有新手机日志，read-only get_debug_feedbacks 返回 total=0，不能把空日志解释为无错误。

根因在 ShopView 分类按钮：backgroundGradient={} 在 Lua 中为真，真实 Button.Init 自动派生悬停渐变时将 nil 颜色传给 Style.Lighten，触发 Style.lua:268 attempt to index a nil value (local 'color')，中断商店构建。

先新增 ShopConstructorTest，保留隔离文件/布局宿主，但对商店所有按钮执行真实 urhox-libs/UI/Widgets/Button.Init 与 Style 代码。修复前明确失败于上述 nil color；删除空 backgroundGradient，仅保留空 variantBackgroundGradient 映射禁用主题渐变后，测试通过，并覆盖三个分类切换和详情/购买/关闭节点。

验证：ShopConstructorTest 10、ShopViewTest 51、FurnitureShopViewTest 30、TravelTicketTest 47、MobileSafeAreaTest 15 项通过。改动保留原有配色和所有素材。此测试覆盖真实初始化，不声称手机/NanoVG 实机渲染通过；仍由用户重新进入手机预览核对。

交付：Lua LSP severity=1 查询返回 errors=0。Maker 提交 e70d0a3，远端构建成功，preview_refresh_status=200。构建后 watcher lastError=null，仍无新设备日志。修复版测试二维码：https://tapcode-sce.spark.xd.com/qrcode/m_h4x3_1791901894704.png 。交付信息在构建后补记于共享目录，不为文档再次构建。
