# 刺绣箭头图片接入

用户已确认图片并要求接入。只改两侧收起按钮与相关前端验证，不使用子代理。

- 使用确认过的原始透明 PNG，完整复制到 `assets/image/ui-controls/embroidered-arrow-left-v01.png`；不重画、不压平透明通道。源图由内置 imagegen 生成，Maker 生成曾返回 INSUFFICIENT_BALANCE，没有可用远端素材映射。
- `EmbroideredArrow` 保留 UI.Button 输入，用 ImageCache/BrewArt 绘制图片；右侧在绘制时水平镜像同一资源。108×72 基准像素，按下轻移 2px 并压暗。
- 托盘右下与记录书左下各向内侧伸出 20px 的按钮盒，图片自身透明留边后可见布贴伸出约 14px。内容层继续裁切；外层允许箭头越界。
- 引擎对 absolute 父节点先做命中拒绝，因此父节点命中仅增加该按钮矩形，确保越界部分可点；不放大整条侧栏热区。退场距离额外留 32px，覆盖伸出的布贴。
- 回归：托盘64、记录书67、炼药188项通过；新增越界点击采用真实 UI.FindWidgetAt 与显式矩形适配器，不能视作原生 Yoga 或手机验收。
- 本地预览状态 stopped / process_alive=false，按 AGENTS 不重启；本轮没有原生视觉验收。用户随后明确选择“更新手机测试版并给新二维码”，按 Maker 构建与二维码流程交付。
- 最终 Lua LSP Error=0，diff --check 通过，核心/系统/运行内容/PlayModel/入口均无改动。

图片 SHA256：FEC48AED6CF8B78AAFB1B7EE4C151CE3AE11C6907BFBFB1A21B4F3255B43BD4E。
