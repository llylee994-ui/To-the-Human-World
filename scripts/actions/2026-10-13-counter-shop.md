# 2026-10-13 木柜台商店与共用原料素材

## 状态与来源

用户已批准“木柜台近景：左侧四商品、右侧详情及购买，透明商品与炼药共用”。代码基线 1cd0cdb。本轮完成代码和素材接入，未提交、推送或远端构建。工作区已有剧情、数值与编辑器改动均保留。

## 实际完成

- Maker batch_generate_images 一次生成成功 5/5：1920×1080 船舱空木柜台背景，四件 1024×1024 RGBA 商品（海盐陶碗、夜露玻璃瓶、灰烬草束、干花瓣布袋）。已逐图查看、alpha 检查、合成叠放查看；原文件和 Maker 远端映射保留。完整回执在 assets/image/shop-counter-r1/generation-records.json。
- 新增 IngredientArt 前端映射，商店商品格/详情与炼药原料行共用原 PNG；没有向 data 注入美术字段。
- ShopView 全屏木柜台浮层、两列商品、选中详情、金币、已有数量、当日余量、配置说明和每次买一份。选择不写存档，购买走原 PlayModel.Buy；购入后保留所选原料并刷新真实数据。
- 售罄、余额不足、待处理锁定禁用购买并显示原因；写盘失败不改变正式库存，提示在商店内部可见。详情可滚动、购买/关闭固定可见；查询失败和空商品保持可关闭。
- AppView 只增加商店分派及显示选择字段，沿用模态阻挡/胶囊避让/消息生命周期；关闭回原 home/seaside/brew，保留草稿和待处理结果。Panels 的炼药原料行仅增加共用贴图，原 add_/minus_ 逻辑不变。

## 本轮实际验证

| 检查 | 结果 |
|---|---|
| run_shop_view.py | 48 断言通过：选择不保存、正确原料及价格、今日余量、余额门禁、写盘失败、待处理锁定、导航和草稿保留、炼药共用图、查询失败/空态。先在旧实现出现预期失败“shop needs selection separate from purchase”，接入后通过。独立审查者另行跑通 48 项。 |
| run_home_entry.py | 303 断言通过，现有读信/剪词/选料/发货及主页导航保持。 |
| run_seaside_flow.py | 89 断言通过，捕捞、收信、跳过、中断及恢复路径保持。 |
| run_home_hud.py | 50 检查通过，现有消息、安全区计算和 HUD 逻辑保持。 |
| run_home_zoom.py | 383 断言通过，门洞推进、中断、一次导航保持。 |
| run_ui_contracts.py shop | 现有真实购买、限购、保存、基准锁和对账检查通过；沿用现有测试内的两处旧导航选择器适配。 |
| Lua LSP | 新开 watch 服务真实完成工作区诊断：0 Error / 67 Warning / 11 Hint；本轮新增文件最终无诊断。原 MCP 缓存曾返回 AppView 的两条旧位置字段错误，新实例未复现。单次 check 因缺 emmylua_check 不可用，不把该失败算通过；watch 取得实际回执后手动结束。完整/错误报告归档在 evidence/shop-counter-r1。 |
| 离线排版重放 | 从实际 ShopView 导出 16 棵 Lua 控件树，以 CSS 重放 1280×720、1600×720、1024×768、800×360。查看大屏、小屏、夜露选中图；关闭和购买均在窗口内。图片全部带 OFFLINE 标记；不是原生 Yoga/NanoVG 或手机截图。 |
| 独立代码审查 | 未发现重要问题；确认资源、交易和关闭边界。审查明确原生/手机仍待验收。 |
| Git | 相关 diff --check 通过；main/PlayModel/core/systems/data 未修改。 |

## 原生与手机边界

每批资源/代码后已查询官方 preview status；均为 stopped / process_alive=false，session 649d3881-f4a7-41f3-a5b8-b608278f9494 / reload 5。遵守停止会话不启动规则，未刷新、未启动引擎、未操作玩家存档。旧回执中的 DDS/DLL 启动错误保持旧会话证据，不能说明当前代码有新运行错误或环境已修复。

手机触控、真实 Yoga 布局、真实平台胶囊、原生图像透明边缘及购买失败的原生提示尚未验收。离线 CSS 对齐只用于审查构图，不替代这些证据。

## 人工测试顺序

1. 药铺点商船：应打开木柜台，四商品可选；切换选择时金币/库存不变。
2. 选夜露再购买一份：只扣夜露实际单价，夜露库存 +1、今日余量 -1；所选商品不跳回海盐。
3. 检查金币不足与今日售完状态；不能通过禁用按钮购买。待处理结果存在时可看商品但不能买。
4. 从药铺、海边分别进入并关闭：回原场景，海边已收的漂流瓶/捕捞状态保留，关闭点击不穿透。
5. 选料期间开关商店，再回炼药：草稿保持；原料行显示相同的陶碗、蓝瓶、草束、花瓣袋。
6. 横屏小手机检查详情滑动、购买/关闭、胶囊避让；真实退出恢复另记结果。

## 交付文件

- scripts/ui/landscape/ShopView.lua、IngredientArt.lua；AppView.lua 和 Panels.lua 的窄范围接入。
- scripts/ui/landscape/tests/ShopViewTest.lua、run_shop_view.py。
- ShopEvidenceHost.lua、export_shop_evidence.py、capture_shop_offline.cjs：隔离证据工具。截图脚本第二参数可传当前安装的 playwright 模块目录，未硬编码开发机路径。
- assets/image/本轮五张生成 PNG；assets/image/shop-counter-r1/generation-records.json。
- docs/验证/evidence/shop-counter-r1/offline-preview.html、widget-trees.json、八张离线截图、检查/哈希回执及静态诊断。
- 已确认 spec 和实施计划：docs/superpowers/specs/2026-10-13-counter-shop-design.md、docs/superpowers/plans/2026-10-13-counter-shop.md。
