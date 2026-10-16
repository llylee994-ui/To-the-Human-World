# 阅读界面修正计划

用户已指定：接单按钮美化并固定到底部中央；委托信息与正文分隔；后续可滚轮阅读全文；记录书点击已收集分支打开大信纸。

- [x] 先写回归，检查接单 footer、独立摘要、结果滚动接收、记录书打开真实 attempt。
- [x] Panels / ReaderOrder：摘要纸笺 + 固定按钮，保留剪词局部刷新和滚动位置。
- [x] ResultView：修正正文命中，保留星级/操作固定；JournalBook / BrewView：以 transactionId 打开同款只读纸页，关闭返回目录。
- [x] Lua 回归与 LSP 检查，确认业务和剧情目录没有改动。
- [x] 活跃本地预览刷新并核对原生滚轮、分页入口、按钮几何；停止操作优先，不自动复活已停止会话。

诊断依据：UI.HandleWheel 从 hoveredWidgets[0] 向父级查找 OnWheel；resultScroll 的 box-none 加上全部文字 pointerEvents=none，使鼠标落到 activePanel，无法经过滚动区。

## 验证记录

- 阅读布局 48、炼药 110（含 schema 4 锅旁记录书入口）、记录书 69 项通过。
- 纸面一致性 23、剪词排版/动效 8080、阅读集成 14、渲染方法 71、词条 64、场景缩放 383 项通过。
- 本地 session 1ae6bc5b-d8b1-4eac-888c-6545796f0a4b / reload 9：ReadingNative PASS；独立内存 fixture，真实 Yoga、UI.HandlePointerMove + UI.HandleWheel，滚至后续末行、历史大纸、返回目录与玩家快照不变。
- 已读取 1450×815 引擎截图。初次摘要报酬没有宽度；补充独立 208×32 区域后复验可见「报酬 · 100 金币」。证据：docs/验证/evidence/reading-panels-r1/native-round2.json 与 reading_native_*.png。
- 电脑控制连续两次 failed to activate captured window，随后捕获返回聊天画面，停止该通道；原生事件验证不等同于操作系统物理鼠标/手机验收。
- LSP 原有 LetterDrawerTest 的 title/senderName 两处 Error 仍在；本轮新增/修改实现未新增 Error。
- CLI check 仍有既有 Cube/Day/DaySpecularHDR.dds 与 themis_x64.dll 告警，不能将其报告为整体通过。未提交、未推送、未远端构建。
