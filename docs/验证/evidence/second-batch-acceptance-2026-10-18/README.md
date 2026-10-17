# 第二批独立验收复核

2026-10-18。范围：整改方案任务4、5，以及最终拼贴按钮、分类纸签层级微调。审查当前工作区相对HEAD `8702c68` 的相关改动，未使用子代理、未操作桌面鼠标键盘。

## 结论

未发现阻止手机测试的新增问题。本地验收通过，后续按用户要求提交Maker构建和提供手机预览二维码。真实设备触感、安全区桥接和前后台切换仍须手机复验；后台引擎检查不能替代真机验收。

## 本次重新执行

- SecondBatchTest：97条断言通过。
- WishCollage：9/9；Departure：5/5；Apprentice：6/6。
- ReleaseEnding：7/7；ReleaseEndingSave：24/24；ReleaseUI：11/11。
- 第一批回归966、词条托盘64、音效动作412条断言通过。
- 14个相关Lua组件及业务模块LSP Error=0；git diff --check通过。
- 额外检查1800组工具框与旋转/缩放手柄边缘位置，没有相交。

## 当前版本原生证据

在已有活动预览中临时启用WishNativeProbe，刷新执行。session `aab29213-49b8-4213-9242-8386db0a10ee`，reload10，完整 `[WishNative] PASS`，见[native.log](native.log)。完成后已恢复wishProbe=false并刷新普通玩家入口。

- 实际引擎完成11封信路线、托盘直接拖入、52×52手柄命中、放大1.8倍、旋转90度、锁定、撤销、寄出、冻结回看及返回标题。
- 实时预览不保存，一次松手只增加一个revision；玩家原快照逐字段不变。
- 1206×540宿主适配器：分别左安全区48、右安全区48，底部12；电脑为实际1450×815。旅人、学徒、愿望九组真实Yoga中心轴检查通过，数据见[centers.json](centers.json)。另有1920×1080纯布局回归。
- 编辑、预览、冻结回看共用版式；旧留念保留原4:3，新编辑保存2:1；封瓶事务、失败与结果未知路径通过。
- 已阅读本次更新的托盘、装饰、旋转锁定和冻结信纸截图，确认最终细边框工具按钮、分类纸签和大纸面符合当前要求。

本目录截图由graphics:TakeScreenShot产生，仅phone文件裁掉宿主适配器以外的桌面画布。

## 图片

- [大纸面和浮动工具框](second_batch_04-word-tray.png)
- [最终装饰纸签](second_batch_05-decor-tray.png)
- [放大、旋转并锁定](second_batch_11-native-rotated-locked.png)
- [冻结信纸回看](second_batch_10-frozen-collage.png)
- 目录同时保存九组结局中心轴截图。

## 已知环境边界

本地CLI整体check依然报告既有Cube/Day/DaySpecularHDR.dds和themis_x64.dll缺失。游戏探针完整通过，不将其表述为整体引擎日志无错误；本次没有更改引擎环境。第三批逐日进度回溯尚未实施，不属于本批漏项。
