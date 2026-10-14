# 2026-10-14 信纸演出与全局纸面修正

用户要求：修正重复寄信人信息、剪词整行接缝与抖动；可剪词改为旋转发光光圈；统一所有纸面文字边距；取消下方整组“剪下”按钮，只在信纸剪词。延续更新手机测试包与二维码的交付请求，不使用子代理。

实现：HarborStyle统一纸面安全边距，短HUD/海边条保留紧凑高度，顶部账本加宽；reader筛掉与寄信人相同的来信人首行且保留介绍正文；案件板和故事记录去掉重复标题。剪词在原阅读节点更新，反馈固定托盘，不插入消息行。纸面用单次图像填充及NVG_HOLE局部镂空，替代分块scissor整纸重绘。双圈暖金色弧线旋转，直接纸面点击，保存成功才开始剪纸/飞入托盘演出，已剪状态及来源纸条保留。

影响：scripts/ui/landscape/{AppView,HarborStyle,Panels,SeasideView,LetterLayout,LetterMotion,LetterPaper,LetterPresentation}.lua、相关测试、assets/image/letter-scissors.png。剪刀复用既有素材原文件；手写字体沿用已交付全局主题。

验证：开发工作区Lua诊断0 Error。现有main交付工作区基于10ae84d，仅复制明确的前端/剪刀/测试文件，未复制并行的内容、schema4、经济/存档开发或文案草稿。对实际交付内容story-numeric-v02-r1运行PaperConsistency 21、LetterPresentation 8022、LetterReader 14、LetterRender 23、ReaderBounds 45、HomeEntry 303项检查均通过。业务测试覆盖写盘失败、来源唯一性、滚动位置、关闭/重开、持久剪痕。原生PaperNativeProbe使用内存存档，engine touch pointer实际触发剪词，确认标题坐标不变；8张原生截图已读取：阅读前/后、抽屉、炼药、海边、案件板、商店、词条栏。证据保存在开发目录docs/验证/evidence/paper-consistency-r2，不视为手机截图。

原生预览仍报告既有DaySpecularHDR.dds和themis_x64.dll错误；未出现此次Lua运行异常。原生探针验证完成后关闭开发标记。演出尚待手机实机确认。

交付：复用C:/Users/liliy/.codex/worktrees/shop-art-preview/To the Human World的main，先Maker官方提交构建，再同步同一提交到GitHub main，最后生成测试二维码。提交/构建/二维码回执以工具实际返回为准；本记录写入时尚未远端提交。
