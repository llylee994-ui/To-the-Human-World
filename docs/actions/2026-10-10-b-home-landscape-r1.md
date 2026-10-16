# B 横屏主页总体图 r1 行动记录

## 状态

进行中。任务编号：`B-HOME-LANDSCAPE-20261010`，版本：`r1`；接收窗口：B 创意窗口。

## 任务与边界

生成一张供审美与构图确认的横屏主页总体候选图。旧竖版图和工程保持不动。本轮不修改游戏代码、正式布局数据或自用排版编辑器；不把总体图当作透明分层素材交付。

## 已确认设计条件

- 16:9 横屏试稿，构图按玩家坐在海边魔药铺工作桌前的视角重新组织。
- 暖木、暖室内光与窗外雾蓝海面、薄雾、近傍晚冷光形成稳定对比。
- 瓶装信件沿窗前桌面后沿从左向窗中部自然错落摆放；中央信纸留白并成为主要操作区；炼药锅和材料在右侧且不遮挡信纸。
- 日历、剪刀、词条托盘、配方书、钱袋、捞网仅作次级物件，避免装饰堆砌。

## 参考与生成措施

主参考：`scripts/素材/主页效果_桌上四瓶与空白信件_v01.png`，用于空间、器物和功能关系。补充参考：用户本轮附图 `C:/WINDOWS/TEMP/codex-clipboard-29096b82-107b-4e4d-a47c-df05041760e3.png`，用于竖图中的室内、窗景和物件关系；二者为同一版视觉方向。

将用图像生成制作一张新的横屏概念候选，而非拉宽或裁切竖图。提示词要求瓶排和信纸轮廓清楚、接触阴影局部化，为后续分层验证预留条件。

## 预期受影响文件

- `docs/actions/2026-10-10-b-home-landscape-r1.md`：本记录。
- `scripts/素材/主页效果_横屏工作台_v01.png`：若同名不存在，保存本轮候选；若已存在则递增版本。

## 验证计划

1. 目视核对横屏构图、主操作区留白、瓶排、右侧炼药区和窗景的相对关系。
2. 核对输出文件的实际尺寸、格式和存在性，并确认未覆盖同名旧文件。
3. 核对本轮未修改生产代码、布局数据或编辑器文件。

## 实际生成提示词

`One 16:9 landscape homepage concept illustration for a calm hand-painted fantasy game. Recompose the supplied seaside apothecary worktable references as a wide view, never stretch or crop the portrait reference. Seated player viewpoint; warm wooden room and restrained amber light, wide open window upper middle, fog-blue calm sea, thin mist, distant harbor village and late afternoon sky before night. Keep the tabletop as the priority. Central lower-middle: wide muted sage-cream desk mat and one large completely blank cream letter sheet with generous clear area around it for future text. On the rear table edge before the window, four individually readable corked message bottles with rolled letters, beginning left of center and loosely progressing toward center; subtle varied sizes, tints, heights and rotations, separated silhouettes, not a product row. Right side: compact dark metal cauldron plus very small herb/jar grouping in matching perspective, with local contact shadows only, never covering the letter. Secondary and unobtrusive: a small calendar rear left, a fishing net on left wall, shallow word-card tray lower left, scissors lower-right of mat, closed recipe book far lower right, small money pouch near cauldron. No labels, numbers, handwriting, logos, UI, watermark, or human figures. Sparse directional wood grain, soft painterly texture, narrow metal highlights, low decorative density. Preserve clear bottle and letter outlines for later material extraction. Full opaque illustration, crop-safe edges.`

## 结果

- 已生成并保存：`scripts/素材/主页效果_横屏工作台_v01.png`。
- 实际格式：PNG、RGB、1672×941；SHA-256：`7340421BF660B0C0A9FFD2A97A99651B0E9FD6B343723EF9AF83972A71A46064`。
- 目视核对：中部桌垫与空白信纸构成最大桌面操作区；四只瓶装信件位于窗前后沿并清晰分开；右侧炼药锅、钱袋和材料未压住信纸；词条托盘、日历、捞网、剪刀和配方书均退为次级物件。
- 生成图保留了较完整的窗景，横屏中窗景占比高于原竖版；这是供用户确认的构图取向，尚非正式美术定稿。
- 未修改生产代码、正式布局数据或排版编辑器。仓库中存在本轮开始前的其他未提交改动，未触碰它们。

## 后续分层建议（未执行）

如果整图获确认，优先从这张图验证两组：四瓶装信件（逐瓶或小组拆分）与中央空白信纸（含极轻的局部接触阴影）。背景、窗框、桌面、桌垫和右侧炼药区先作为固定底图，以免独立拼接造成透视和阴影冲突。

## r2 修订任务

用户要求以 `C:/WINDOWS/TEMP/codex-clipboard-2c3f6948-3b58-40cf-9079-b2a8da1cdb79.jpg` 的欧洲三桅商船结构为船只参考，输出不覆盖 v01 的两张完整横屏图：一张有船、一张无船。两图共同修订如下：

- 中央信纸需有折痕和低对比、不可辨读的手写笔迹；桌面后沿其中一只漂流瓶为空且打开瓶塞，说明信刚被取出。
- 左侧花瓶不得遮住捞网下半部；左侧桌面补入档案袋。
- 托盘中的词条纸需有彼此不同、不可辨读的手写笔迹。
- 桌前沿露出一部分抽屉与拉手。

拟输出：`scripts/素材/主页效果_横屏工作台_有船_v01.png` 与 `scripts/素材/主页效果_横屏工作台_无船_v01.png`。生成后将补充实际尺寸和检查结果。

### r2 输出与核对

- 已输出有船版：`scripts/素材/主页效果_横屏工作台_有船_v01.png`，PNG、RGB、1672×941，SHA-256 `2884A28D38F5DED658F30F45FAD35B0047A855FDD89D2D6E66742EEA55309B75`。
- 已输出无船版：`scripts/素材/主页效果_横屏工作台_无船_v01.png`，PNG、RGB、1672×941，SHA-256 `4CA449542E72CBB5D56C4D8F4B83A7C5F7C8F1930AD12E92B2BD556217BD73E4`。
- 有船版窗外为远景小型木质三桅帆船，具多张帆、桅杆、索具和圆润船身；无船版没有船、帆或船体。
- 两版均目视核对：中央信纸有横向折痕和低对比、不可辨读笔迹；瓶排中有开口空瓶与桌面瓶塞；左侧档案袋独立于词条托盘；托盘卡片为不同笔迹；左侧花瓶未压住捞网下半部；桌前沿可见抽屉面与黄铜拉手。

## r3 修订任务

用户要求两图都露出椅子、镜头略向后拉、加深信纸上不可辨读的笔迹；去掉左侧花瓶，改为放置厚实、书立式的档案袋，材质和笔触须与室内统一。两版除窗外是否存在欧洲三桅商船外不可有其他设计差异。

实施方式：先制作无船母版，再以母版为唯一画面参考仅添加远景商船，降低两次独立生成带来的构图差异。拟输出 `主页效果_横屏工作台_无船_v02.png` 和 `主页效果_横屏工作台_有船_v02.png`。

### r3 输出与核对

- 已输出无船母版：`scripts/素材/主页效果_横屏工作台_无船_v02.png`，PNG、RGB、1672×941。
- 已由该母版仅添加窗外远景三桅商船，输出有船版：`scripts/素材/主页效果_横屏工作台_有船_v02.png`，PNG、RGB、1672×941。
- 目视核对两图：均露出左下前景的木椅背与搭布；中央信纸的折痕保留，笔迹比 r2 明显但仍不可辨读；左侧花瓶位置由一册厚实、书立式的绑绳档案册取代；捞网下半完整露出。
- 两图的室内、桌面、瓶排、档案册、信纸、椅子和窗景保持同一母版构图；有船版仅在窗外左侧海面增加一艘远景欧洲三桅商船。

## r4 已确认修订

用户确认执行：信纸笔迹改为一封真实书写节奏的连续多行正文，保持不可辨读；移除厚档案册右侧的浅黄色档案袋，改为低矮、统一材质的小装饰，且不遮住捞网；镜头继续向后拉，完整露出桌子抽屉面及左右边缘。仍以无船母版生成后仅加入船，保证两版除船外一致。拟输出 `主页效果_横屏工作台_无船_v03.png` 和 `主页效果_横屏工作台_有船_v03.png`。

### r4 输出与核对

- 已输出无船版：`scripts/素材/主页效果_横屏工作台_无船_v03.png`，PNG、RGB、1672×941，SHA-256 `6447632C872502D4B069AAB388BBBCDAF732146FA465A7FECA890B406E98BAD2`。
- 已以该无船图添加远景商船后输出有船版：`scripts/素材/主页效果_横屏工作台_有船_v03.png`，PNG、RGB、1672×941，SHA-256 `F4D903CFDB5A0F3A5F37947CFC99B249BA56604E9E991C2A63C0499DAE6824C6`。
- 用户指出绿光塔在重生成中漂移消失；已恢复为港口栈桥尽头的小范围冷绿灯点及短水面倒影，两版均保留。
- 目视核对：两图均完整露出桌子抽屉正面、黄铜拉手和两侧桌前结构；左下椅背可见；信纸为连续多行但不可辨读的手写笔迹；浅黄色档案袋已删除，替换为低矮的黄铜镇纸、旧纸和封蜡盒；捞网下半未被遮挡。
- 两图基于同一无船母版；有船版唯一新增内容是窗外左侧海面的远景欧洲三桅商船。
