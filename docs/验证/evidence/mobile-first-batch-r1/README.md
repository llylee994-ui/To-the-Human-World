# 第一批本地验收（2026-10-17）

> 最新：中间下方抽屉r2已完成新一轮引擎截图和触摸路由复验，见[../mobile-first-batch-r2/README.md](../mobile-first-batch-r2/README.md)。下面“未重新截图”是此前历史状态。

> 后续修订：药性窗口已按用户确认改为中间下方抽屉，02/03/09截图为旧版，不能代表当前手札。最新说明见 `scripts/actions/2026-10-17-potion-notes-center-drawer-r2.md`；最新966/188断言通过，当前预览未运行，未重新截图。

已完成公共托盘分页、药性底部窗口、回信阅读区、商店稳定布局。手机二维码对应旧构建，本轮没有提交或远端构建。

## 证据范围

后台引擎截图与真实 Yoga/PointerEvent 路由，独立内存存档；未操作桌面鼠标键盘。手机画面使用1206×540、左安全区40、底安全区12和模拟胶囊的宿主适配器（约2.23:1），不是物理手机实测。电脑截图为实际1450×815窗口；1920×1080等尺寸另外由纯布局回归覆盖，不能把小窗口截取说成1920全屏。

原生检查 session `990ecd59-187c-4a7f-a243-1d56fbd5e1e3` / reload `5`，`FirstBatchNative PASS`。检查关闭后已恢复默认 `firstBatchProbe=false`，并刷新普通玩家预览。

- 窗口打开和关闭前后，药槽、原料栏、操作区矩形不变。
- 默认药性、数值模式、手机回信宽度和关闭按钮避让胶囊通过。
- 商店首次/连续购买、最后一份售罄、金币不足时，商品区、详情、商品图、页码、购买按钮真实矩形保持一致。
- 61个真实词条在原生字体下分成7页，逐页点击箭头，每张完整落在可用区域，全部可达。该画廊是显示夹具，不向玩家存档发放词条。
- 玩家原始快照前后相同。保存失败由真实事务及稳定布局属性的独立回归覆盖。

## 截图

- [炼药与左侧托盘](first_batch_01-phone-workbench.png)
- [药性窗口](first_batch_02-phone-notes.png)
- [药性数值](first_batch_03-phone-notes-numbers.png)
- [横屏回信](first_batch_04-phone-reply.png)
- [购买前](first_batch_05-phone-shop-before.png)、[购买后](first_batch_06-phone-shop-after.png)、[售罄](first_batch_07-phone-shop-soldout.png)、[金币不足](first_batch_08-phone-shop-no-money.png)
- [电脑药性窗口](first_batch_09-desktop-notes.png)、[电脑回信](first_batch_10-desktop-reply.png)
- [词条分页示例](first_batch_11-phone-tray-page-2.png)（目录内另有1—7页）

## 检查

FirstBatch 953、WordSlip 300、WordTray 64、BrewWorkbench 188、UiActionSounds 412条断言通过；WishCollage 9项、ReleaseUI 11项通过。各命令完整输出在同目录 `test-*.log`。改动文件 Lua LSP Error 检查与 `git diff --check` 另行完成。

本地预览依旧会报告既有的 `Cube/Day/DaySpecularHDR.dds` 和 `themis_x64.dll` 缺失，使CLI总检查显示FAIL；游戏可以启动，以上原生夹具也已运行通过。不据此声称整个引擎检查无错误。
