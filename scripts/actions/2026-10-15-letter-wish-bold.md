# 来信心愿句加粗

用户要求来信心愿句加粗，并提交推送 Maker 与 GitHub 两端。

## 方案与实现

- 按当前正式文案提取 11 封订单信的完整心愿句，冻结为 UI 专用 LetterEmphasis 表。N02 只标记心愿句，保留正文承诺句的既有样式。
- 不改正文配置、剪词标记、来源编号和存档；在阅读页对文本分段增加字重，保留所有原字段。未知或不匹配文本保持普通正文。
- LetterLayout 按实际字重测量和换行，不合并不同字重的片段；LetterPaper 按片段使用对应字面绘制。剪后布局仍复用，洞口及点击使用原坐标。
- 正文仍用原 Harbor Hand Regular；心愿句使用独立 story-strong / Harbor Hand Medium 字面。字体来自项目原字体同一上游的较粗 Medium（旧称 Bold）字重，按已有 Regular 的 6945 个码点取子集并改内部名称；OFL 许可证和源文件哈希随资源保留。
- 先添加字重分段/测量检查并观察失败，再实现；以 11 封真实解析结果验证全文、心愿范围、剪词来源及原视图不变，同时检查实际绘制调用选择的字体。

## 验证

- PaperConsistency 23、LetterPresentation 8080、LetterReader 14、LetterRender 71 项通过。覆盖全部 11 封真实来信及实际绘制方法；适配器验证不等同手机截图。
- 阅读边界 45、抽屉 98 项通过；四份生产 Lua 的 LSP Error 为零，git diff --check 通过。
- Medium 与 Regular 均覆盖 6945 个码点；相同字号的心愿句像素墨量比为 1.22，已查看字体对照图，字重确有区别。
- 本地预览按规范从存活会话刷新到 reload 23 并读取日志/check；既有 DaySpecularHDR.dds / themis_x64.dll 缺失仍使官方 check 为 FAIL，不声称该项通过或已完成手机目测。
