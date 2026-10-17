# 花草自由摆放验收

用户确认纸外花草完整保留。编辑器放开装饰在信纸顶部、边缘与纸周桌面的摆放；预览与留念按信纸和全部素材整体缩放，坐标不重新排列、不裁切。

- [编辑器跨边摆放](04-word-tray.png)
- [装饰托盘](05-decor-tray.png)
- [整幅作品预览](07-preview.png)
- [冻结留念回看](10-frozen-collage.png)

本地后台session `aab29213-49b8-4213-9242-8386db0a10ee` reload13，完整WishNative PASS。新增实际UI命中测试证明纸外的麦穗中心可被选中；预览和冻结回看的旋转包围范围检查证明所有素材均完整入镜。原玩家快照不变。

新回归23条、SecondBatch97条、WishCollage9/9、ReleaseUI11/11通过；日志保存在本目录。关键运行时源码SHA256见source-hashes.json。额外ReleaseEndingSave24/24通过。

截图由graphics:TakeScreenShot取得，手机画面为1206×540桌面引擎适配器，不能作为真机手感验收。截图和日志属于本地验收产物，遵守现有忽略规则保留在本机。
