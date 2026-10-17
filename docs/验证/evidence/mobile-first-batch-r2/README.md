# 第一批修复后后台复验

2026-10-17。当前中间下方药性抽屉r2和回信最新截图，替代r1中的旧药性窗口画面。

## 结果

- 商店旧测试已改为从实际原料卡内读取素材组件，验证原图路径和裁切信息；55条断言通过，后续交易、库存、金币不足、保存失败、待处理订单与配方保留用例均执行完毕。
- 新版手札真实Yoga布局通过：只覆盖中间下方，避开药锅，不引起药槽/原料/操作区重排。实际UI触摸手势路由能够滚动数值内容；框内空白保持展开，框外点击关闭。数值模式仍需在正文区域向上拖动阅读下方权重行。
- 回信使用大阅读区、固定底部操作，关闭按钮避让模拟平台胶囊；两角花饰已移除。
- 商店首次/连续购买、售罄和金币不足时，商品区、详情区、商品图、页码、购买按钮的实际矩形不变。
- 61个真实词条原生字体分页7页，全部完整可达；普通和炼药托盘贴左。
- 运行夹具使用独立内存存档，原玩家快照前后不变。开发探针已恢复默认关闭。

## 证据身份与边界

完整通过的本地预览session：`1b6ef37b-ba57-4f39-9e00-6ba28a7a4437`，reload0，`FirstBatchNative PASS`；摘要保存在[native-check.log](native-check.log)。

截图中的phone是1206×540逻辑视口适配器，左安全区40、底安全区12及模拟胶囊；desktop是实际1450×815窗口。来自实际引擎截图，使用UI内存事件路由，无操作系统鼠标键盘输入。**这不代表真实手机验收，远端手机包和二维码尚未更新。**

首次绝对路径截图写入失败已通过相对运行时保存目录解决；短时预览曾在最后步骤前到期。以上完整PASS来自随后600秒运行，不将前两次中断计为通过。

CLI仍报告既有`Cube/Day/DaySpecularHDR.dds`和`themis_x64.dll`缺失，整体check结果不能称为无错误；本轮未修改这些引擎环境。

## 最新截图

- [药性手札](first_batch_r2_02-phone-notes.png)、[数值模式上部](first_batch_r2_03-phone-notes-numbers.png)、[电脑手札](first_batch_r2_09-desktop-notes.png)
- [手机比例回信](first_batch_r2_04-phone-reply.png)、[电脑回信](first_batch_r2_10-desktop-reply.png)
- [购买前](first_batch_r2_05-phone-shop-before.png)、[购买后](first_batch_r2_06-phone-shop-after.png)、[售罄](first_batch_r2_07-phone-shop-soldout.png)、[金币不足](first_batch_r2_08-phone-shop-no-money.png)
- [词条分页](first_batch_r2_11-phone-tray-page-2.png)，目录含完整7页。

最终代码的FirstBatch966、ShopView55、WordSlip300、WordTray64、BrewWorkbench188、UiActionSounds412条断言全部通过。命令输出在同目录`test-*.log`；关键源码SHA256见[source-hashes.json](source-hashes.json)。
