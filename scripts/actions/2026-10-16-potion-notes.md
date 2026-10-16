# 全剧情药性手札与花瓣按钮

用户确认：全剧情适配药性文字、数值可展开；改善条件药效详情界面及按钮，使用花瓣样式。

- [x] 纯展示投影读取 effects 定义与 potionPreview.intensityByEffect；按权重排序主导和伴随，不改计算阈值、不生成剧情或评级预测。
- [x] 默认纸笺显示委托条件/状态、主导药性及配置作用描述、全部伴随倾向；权重仅在数值详情展开。
- [x] 可滚动纸笺、固定花瓣关闭/展开按钮；适应中心区域可用高度，状态切换不写玩家数据。
- [x] 纯函数与真实 UI/业务回归，覆盖所有药效/所有订单定义及空值、稳定排序、展开/关闭。
- [x] 活跃预览刷新、内存 fixture 原生事件与截图验收；恢复正常开关。

## 交付与验证

- 新增 PotionNotes（通用只读投影）、PotionNotesView（纸笺布局）及 PetalButton（原生 UI 控件，以矢量绘制花瓣底色，不新增位图素材）。接入 BrewRecipe。
- 155 项炼药回归通过；覆盖所有当前药效与委托定义、主导/伴随排序、默认无数值、展开/关闭/重开、浏览不写状态；记录书 69 项通过。
- 用户明确授权重新启动已关闭的本地预览。session 2cf84817-8e59-49ea-be13-928de2c102ee / reload 1 的 ReadingNative 通过，包含药性默认/明细的真实 Yoga 几何及 UI 指针按钮点击；原始玩家进度不变。
- 读取引擎 1450×815 截图：docs/验证/evidence/potion-notes-r1/reading_native_notes.png 与 reading_native_notes_numbers.png。数值明细改为切换正文，避免展开后藏在折叠区域下方。
- LSP 无新增 Error；仍有既有 LetterDrawerTest title/senderName 两项。业务、剧情、PlayModel 和 main 无改动。未提交、未推送、未远端构建。
