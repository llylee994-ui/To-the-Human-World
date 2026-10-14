# 2026-10-14 手机构图、账签与纸面层级

用户手机反馈：屋顶被裁、金币日期纸条过大，以及故事侧栏与控件比例不舒服。全程单代理。

根因：Home原先SceneFit按宽放大并底对齐，在约20:9的手机上裁掉屋顶。短纸条继承全尺寸纸面上下32px的padding，44px名义高度实际被撑大。故事目录与所选详情同时显示，木牌整张五板纹理在每个按钮内裁切，侧栏用内部marginTop避胶囊产生大块顶部留白。

修改：Home专用RoomFit等比完整显示；海边保留原SceneFit。宽屏剩余空间用现有木纹绘制安静边框，淘汰首轮镜像延边（重复花瓶/植物）。短纸条默认上下6px、左右16px，账签13pt/32px高并按实际字宽调整。物件标签12pt、三秒初次提示，开纸面时隐藏提示和浮动HUD。木牌只取源图第一块板；大纸面普通按钮最长420px，详情回目录136px。故事目录与详情互斥，试做数量另起小字，返回/关闭保留正确导航。右侧纸面整体落在胶囊下方并留12px外边距，标题16pt、详情19/15pt层级。

范围：AppView、HarborStyle、HomeView、LayoutGeometry、SceneBackdrop、HudLayout、Panels和前端测试；不改内容、存档、经济、炉灶转场。

验证：先复现SceneProjection与PaperConsistency失败，再修正。交付main story-numeric-v02-r1实际运行HomeEntry303、PaperConsistency25、LetterPresentation8022、LetterReader14、LetterRender23、SceneProjection78、HomeHud50项通过。开发工作区的HomeZoom383、SeasideFlow89、ShopView51、TravelTicket47、ReaderBounds45也通过；Lua LSP 0 Error。原生窗口用1450x650检查，胶囊/安全区由开发探针模拟；故事历史为隔离夹具，不写玩家存档。

原生首轮截图已经读取，发现镜像延边重复摆设并修正。首轮探针在返回主页当帧检查命中时失败：Layout尚未推进，故将最终输入断言移到下一阶段，等待实际Yoga渲染；第二轮结果以日志为准。公共引擎资源下载较慢，不能把正在加载当成新UI通过。原生一直有既存DaySpecularHDR.dds与themis_x64.dll提示。

第二轮原生已通过（reload12，1450x650）：完整房间边界、八个物件命中、实际故事返回按钮touch pointer均通过。6张最终截图已保存并读取，确认木纹边框没有复制摆设、账签缩小、短木牌与目录/详情独立、模拟胶囊下方关闭按钮。截图和两轮日志保存在docs/验证/evidence/harbor-chrome-r3；这仍非手机实机证据。原生开发探针已经关闭。

交付继续复用已有main工作区，只复制明确前端文件，保留开发工作区并行内容。GitHub此前AppView与炉灶转场合并冲突尚未处理，不覆盖。手机更新以Maker官方构建和测试二维码回执为准。
