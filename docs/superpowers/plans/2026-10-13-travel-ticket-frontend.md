# 船票前端实施计划

**Goal:** 按 666 金币、第 1～10 天初值接入船票商品与购买确认。

**Architecture:** TravelTicket 只读投影与程序侧命令适配；TravelTicketView 负责确认与真实结果展示；ShopView 合并原料和票的显示列表。AppView 保留选择/取消状态和既有消息、安全区处理。

**Tech Stack:** UrhoX Lua 5.4、urhox-libs/UI、既有 File/widget 隔离测试与 Maker 票图。

## 约束

仅前端代码/文档。价格 666，firstDay=1，lastDay=10，含首尾。不能把票当原料买或在 UI 减钱。缺真实启程接口时最后确认禁用且明确提示尚未开放。停止预览不启动；不提交或远端构建。

## 任务

- [x] 添加 TravelTicketTest：真实日数/资金/门禁、取消不写入、票不调用原料购买、显式适配器参数/错误和结果展示。
- [x] 新增 TravelTicket.lua：配置、当前票投影、带期日/价格/版本的专用事务适配。
- [x] 新增 TravelTicketView.lua：确认层、取消、可购条件重新读取、程序返回的结局文本显示。
- [x] ShopView 固定第五商品，展示剩余日和期限，选票转确认；AppView 管理 ticketConfirm 和真实 ending 面板，关闭/切场景取消未提交确认。
- [x] 扩展离线证据导出器覆盖船票详情与确认，保留旧商店证据。
- [x] 运行专项/回归/LSP，独立审查，写程序侧接口交接及实际完成边界。
