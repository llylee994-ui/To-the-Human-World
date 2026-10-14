# 商店商品与共用界面样式更新

用户最终确认家具清单：桌布 60、椅子 100、挂灯 140、书架 180 金币。每件购入一次，保存拥有状态，暂不布置小屋，也不改变炼药数值。

商店分为原料、家具、船票三个分类，卡片和详情展示大图，固定购买操作区，保留列表和详情滚动。原料透明图片按主体范围展示，炼药共用。全局 UI 使用项目内 Harbor Hand 文楷子集、木纹按钮、柔边纸面，保留 MiSans 注册与安全区计算。

家具交易由 GameState 协调整份存档，Economy 计划扣费和购买流水，OrderAudit 重放核验；金币不足、已拥有、待确认订单、写盘失败均不能重复扣费。兼容无家具字段的既有 v2/v3 存档。

验证：FurnitureShopTest 通过；FurnitureShopView 30、ShopView 51、TravelTicket 47、MobileSafeArea 15、HomeEntry 303、HomePresentation 33、HomeHud 50、SeasideFlow 89、SaveV3Migration 70 项检查通过。Lua LSP 零 Error。离线控件树/CSS 重放覆盖七个界面、四个尺寸，共 28 组，购买和关闭按钮在视口内并避开模拟胶囊。

离线证据位于 docs/验证/evidence/shop-art-r2，明确标识为模拟布局，不能代替手机或引擎验收。本地预览状态为 stopped，没有重启。船票离开结局接口仍未实现；本轮保留既有前端确认与接口缺失限制。

提交仅包括本轮代码、字体和当前使用的素材。共享目录被其它会话切换到剧情分支，Maker 首次提交在 commit/push 前被分支校验阻止；随后使用应用管理的 shop-art-preview 独立 main 工作区，content.lua 仅带家具挂载一行，保留并排除其它会话的剧情首发改动。独立工作区使用实际待提交内容再次通过上述十套测试。素材来源和 Maker 映射在 assets/image/shop-art-r2/generation-records.json，字体许可与来源在 assets/fonts。

交付结果：独立 main 同步 Maker 远端的既有项目/元数据更新后，Maker 提交 54241cf 并远端构建成功，preview_refresh_status=200。运行日志 watcher 无错误，当前没有新设备运行日志，因此不标记真实手机验收通过。手机测试二维码：https://tapcode-sce.spark.xd.com/qrcode/m_h4x3_1791899214768.png 。此处交付记录在构建之后补充，未为文档更新重复构建。
