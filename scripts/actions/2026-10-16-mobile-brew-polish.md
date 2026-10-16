# 手机炼药实测修正

用户已指定：手机一次拖动可投料，左托盘到最左，药锅放大，记录书关闭不遮挡，后续信纸增加正文空间，长标题缩字号，删除翻页动画。不使用子代理；只改前端，不动剧情和数值。

根因：引擎 panMinDistance=5 屏幕像素；BrewInteraction 要超过 10 base px 才激活。初次 PanStart 到卡片时还未激活，ScrollView 接管并 CancelPointer，投料因此被取消。卡片按首段方向永久判滚动也会让自然曲线拖动失败。

- [x] 手势：先以 2～3 base px 的 touch PanStart 复现；卡片接管已识别手势，后续任意方向拖动均跟随同一手指；点按详情、空白滚动、取消、失败不写、重复释放仍保留。文件 BrewInteraction/BrewView 与 BrewWorkbenchTest。
- [x] 布局：BrewLayout 短屏压缩来信、配方、原料架高度，药锅高至少约 1/3 可用高度；左托盘仅在 workbench 模式贴 x=0，中心使用释放的安全区空间；书关闭键 top=58 避开 48 高 HUD。文件 BrewLayout/BrewView/WordTrayDrawer/JournalBook。
- [x] 信纸：ResultView 按自身关闭键与胶囊实际交叠决定顶部，不再无条件把整页移到胶囊下面；短屏缩紧内边距、头部和星级章、回响与底部按钮，正文保留滚动。用 1200×540、左右安全区和胶囊验证正文空间与按钮位置。
- [x] 记录书：保留全标题，只按实际页宽缩字号为一行，lineHeight=1.25；删除 flip 状态、计时和 NanoVG 折页绘制，切故事立即更新。更新 JournalBookTest 的旧翻页断言，保留只读和单书检查。
- [x] 运行炼药、记录书、相关布局回归和 LSP；真实引擎内存 fixture 在手机等比例视口注入 touch pan，截图检查药锅、关闭键命中、长标题、信纸正文及底部按钮；原玩家状态不变。正常开关复位，每批按状态刷新活跃预览。

本轮最终交付本地改动与验收结果；手机测试版本更新遵循用户已授权的本轮手机预览流程，构建后重新生成二维码。

## 验收

- 炼药 177、记录书 67、词条托盘 64、信纸边界 48、HUD 52 项通过；LSP Error=0，git diff --check 通过。业务、剧情、PlayModel、main 无差异。
- 本地预览 session 2cf84817-8e59-49ea-be13-928de2c102ee / reload 12：MobileBrewNative PASS。1200×540 视口、左安全区 48、右上系统胶囊占位；真实 UI 指针/手势路由验证首段 3 base px 接管、词卡和原料各一次投放、不重复释放、正文触摸滚动至最后一行、一次关书。原玩家状态未改变；这是桌面引擎与主机尺寸适配证据，不是手机实机结论。
- 已读取引擎截图：左托盘贴 x=0；短屏锅高 188；关闭键避开 HUD；信纸从 y=12 到 y=528，正文滚动高度超过 260；第二封信完整标题一行、高 30；原料文字重新对齐共享木牌画布。
- native-final.json 及 mobile_brew_workbench/result_top/result_bottom/long_title.png 在 docs/验证/evidence/mobile-brew-polish-r1/。
- 调试开关 mobileBrewProbe 恢复 false。引擎原有 DaySpecularHDR.dds / themis_x64.dll 报错仍存在，不声称整体 preview check 通过。
- 夹具排查期间修正了正文坐标应含 ScrollView 偏移、次日收信应先完成订单并跨天，以及 Label 构建时须传入最终行高，避免保留旧的固有高度。
