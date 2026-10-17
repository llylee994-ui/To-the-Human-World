# 手机反馈第二批验收

2026-10-17。本批对应方案任务4、5。未使用子代理，未提交/推送/远端构建，未操作系统鼠标键盘。用户明确允许重新启动本地预览进行后台验收。正式玩家存档在引擎探针前后逐字段一致。

## 结论与边界

代码回归通过；原生引擎完成11封信路线的拼贴收尾、指针/手势路由和九组结局中心轴检查。截图由游戏中的 `graphics:TakeScreenShot` 取得，手机比例图只裁掉适配器视口之外的桌面画布。

1206×540是桌面引擎中的横屏宿主适配器，包含左右48及底部12的不对称安全区和平台胶囊预留；不是物理手机。电脑使用引擎实际1450×815视口，另有1920×1080纯布局回归。手机测试包未更新，真实设备触感、系统安全区上报及前后台切换仍待真机复验。

CLI `preview check` 仍受已有启动资源错误 `Cube/Day/DaySpecularHDR.dds` 与 `themis_x64.dll` 影响，不报告为整体引擎日志干净。游戏探针自己的PASS、几何与图片证据独立记录，未修改引擎资源或运行环境。

## 结局中心轴

原控件在已经全屏展开的根节点内，又按安全区的中心绘制。不对称安全区会增加 `(left-right)/2` 偏移。现在标题、副标题、返回按钮统一使用完整视口的中心；底部可点击目标独立避开手势区。

| 宿主适配 | 屏幕中心X | 旅人／学徒／愿望标题、副标题、返回按钮X中心误差 |
| --- | ---: | ---: |
| 1206×540，左48、右0、底12 | 603 | 0 |
| 1206×540，左0、右48、底12 | 603 | 0 |
| 1450×815，零安全区 | 725 | 0 |

九组记录均含视口、安全区、父容器、结局根节点及三个控件的实际Yoga矩形，见 [ending-centers.json](ending-centers.json)。电脑零安全区的中心公式保持原值；未使用手机偏移量平移电脑版。

九组中心轴对照直接挂载对应结局渲染器；学徒对照保留测试宿主的标题底图，只验收坐标，不作为学徒室内过场的美术验收。拼贴寄出及返回则通过真实界面路线执行。最终输出见 [native-final.log](native-final.log)。

## 拼贴验证

- 原托盘贴左并沿用分页、美术、词卡自适应、花草和独立空白纸条。纸面扩大，主按钮位于顶部，固定底栏和四个微调按钮不存在。
- 原生引擎命中真实52×52手柄；经 `UI.HandlePointerDown/Move/Up` 和 `UI.HandleGestureEvent` 放大1.8倍、旋转90度。实时预览不写盘，有效松手只提交一次；PointerUp与PanEnd不会重复保存。
- 原生路线验证托盘点击不取出、直接拖入才取出，锁定、撤销、预览、寄出、冻结回看及返回首页。纯Lua检查另覆盖纸外取消、重复来源拒绝、花草/空白纸条重复、第二指针、失焦、取消、安全区变化、整圈旋转和纸边工具框避让。
- 点击或拖动选中显示跟随工具框，点击纸面或桌面空白隐藏；没有独占底部的操作栏。工具框自定义内边距在按钮皮肤初始化后应用，避免短按钮挤字。原生图片发现大素材的工具框可能挡住“我想……”，已将题字区域设为避让区并补回归；装饰托盘的重复取用提示同步缩短，避免页脚换行拥挤。
- 新版纸面基准随行保存；旧留念仍按4:3。预览转换不保存，封瓶按当前可见版式原子冻结，写入失败、结果未知与重复确认均验证。旧数据和单次手势撤销保持兼容。

## 自动检查

| 检查 | 结果 | 输出 |
| --- | --- | --- |
| SecondBatchTest | 97项断言通过 | [second-batch.log](second-batch.log) |
| WishCollageTest | 9/9 | [wish.log](wish.log) |
| DepartureViewTest | 5/5 | [departure.log](departure.log) |
| ApprenticeViewTest | 6/6 | [apprentice.log](apprentice.log) |
| ReleaseEndingTest | 7/7 | [endings.log](endings.log) |
| ReleaseEndingSaveTest | 24/24 | [ending-saves.log](ending-saves.log) |
| ReleaseUITest | 11/11 | [release-ui.log](release-ui.log) |
| ReleaseClosingIntegrationTest | 通过 | [closing.log](closing.log) |
| FirstBatchTest | 966项断言通过 | [first-batch.log](first-batch.log) |
| WordSlipTest / WordTrayTest | 300 / 64项断言通过 | [word-slip.log](word-slip.log)、[word-tray.log](word-tray.log) |
| UiActionSoundsTest | 412项断言通过 | [ui-sounds.log](ui-sounds.log) |
| Lua LSP | 本批18个文件Error=0 | [lsp.json](lsp.json) |

结局旧测试把学徒收尾余额固定成650，当前实际路线是626；已将该断言改为比较收尾前后完整经济账本一致，经营和价格数据没有修改。新增结果未知的封瓶测试从重新载入的独立存储夹具注入故障，避免准备阶段的写入标记干扰故障位置。

截图取自完成渲染后的画布，不用刚更新控件树那一帧的旧缓冲区作为旋转/锁定证据。探针默认关闭，验收后刷新为正常玩家入口。

## 主要图片

- [大纸面与跟随工具框](second_batch_04-word-tray.png)
- [花草托盘](second_batch_05-decor-tray.png)
- [空白纸条托盘](second_batch_06-blank-paper-tray.png)
- [寄出预览](second_batch_07-preview.png)
- [愿望冻结回看](second_batch_10-frozen-collage.png)
- [原生手柄放大、旋转90度及锁定](second_batch_11-native-rotated-locked.png)
- [左安全区：旅人](second_batch_center-left-departure.png)、[学徒](second_batch_center-left-apprentice.png)、[愿望](second_batch_center-left-wish.png)
- [右安全区：旅人](second_batch_center-right-departure.png)、[学徒](second_batch_center-right-apprentice.png)、[愿望](second_batch_center-right-wish.png)
- [电脑版：旅人](second_batch_center-desktop-departure.png)、[学徒](second_batch_center-desktop-apprentice.png)、[愿望](second_batch_center-desktop-wish.png)
