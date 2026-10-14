# B-HOME-LEDGER-20261011 r1：主页空白账签

## 状态与现场

- 状态：Completed（素材、实际合成及静态检查完成；审美待用户确认，未接入运行时或真机）。B 负责创意与素材；再由用户转交 C。
- 用户要求：独立浅奶油灰手工账纸＋一枚小黄铜夹，近正面、横向、空白；真实透明、紧裁，保留薄投影。用于日期和金币；日期下方留提示空间。
- 参考：`C:/WINDOWS/TEMP/codex-clipboard-82d96881-3cfe-43ed-b167-c8f53df3f41b.png`，已实际打开，1920×1080 最新主页。只作风格与叠加底图，不覆盖或重画。
- 现场 HEAD：`6c7cccf`，有他人的前端、排版、文档与素材改动，全部保留。
- 最新决定：账签放主页左上角，避开捞网；日期点击后由程序弹出跨天确认，金币只显示。本轮不做日历、不做弹窗、不改运行代码。
- 已读取项目 AGENTS、project-control-report、action-document、imagegen 及其提示词参考。按 imagegen 使用内置生成，不走外部 API。

## 实施措施

1. 内置图像工具生成独立空白透明账签，参考主页手绘材质，不生成主页或文字。
2. 检查真实 Alpha、外轮廓、夹子、柔影与空白承载区；必要时仅裁去外部全透明余量，保留像素与 Alpha。
3. 在最新主页副本上按左上角位置合成预览，单独叠加示意日期、金币与提示；独立素材保持无字。
4. 以浅、深背景及手机横屏缩略预览检查边缘、文字空间和捞网遮挡；静态尺寸检查不冒充手机运行验收。

## 影响文件树

- `scripts/素材/账签_空白_透明_v01.png`：实际新增，2192×713 RGBA，独立可排版空白素材；没有覆盖旧文件。
- `scripts/素材/预览_账签_主页左上角_v01.png`：实际新增，1920×1080 静态叠加效果；示意文字只在预览里。
- `scripts/素材/预览_账签_手机横屏与透明检查_v01.png`：实际新增，1720×1020，含两个手机比例预览及浅深底检查证据。
- `docs/actions/2026-10-11-b-home-ledger-r1.md`：本行动记录，包含实际提示词、导出与验收。
- `docs/actions/ledger-r1/Export-Ledger.ps1`：实际新增，仅机械裁切、合成预览和像素检查，不生成替代美术，不进入游戏。已有成品时拒绝覆盖；中断后的同像素素材可校验后复用。
- 无修改／删除现有素材、主页原图或游戏代码；不提交、推送、构建，不操控正在使用的窗口。

## 自检方法

- 读取源图尺寸与 SHA-256，结束时复核未改变。
- 读取 PNG 像素格式、Alpha 最小最大值、透明／半透明／不透明像素数和非零 Alpha 包围盒；不以扩展名代替通道检查。
- 实际打开透明素材、浅深底检查图与最终合成；检查纸面无文字、夹子完整、无烘焙底色、柔影不截断。
- 记录左上角、等比摆放尺寸、日期与金币的留白区；检查账签底边不触及捞网。
- 手机横屏以静态缩略图验证文字占位及画面遮挡；真机触控／安全区／运行时字数适配由 C 后续验证。

## 自检结果

### 实际生成与导出

- 内置 image_gen 一次生成，透明参数为 true，无 API／CLI fallback。
- 原始输出：`C:/Users/YINGYI/.codex/generated_images/01a12584-8e9b-79e0-af65-6908469a0073/exec-8f3f0c5a-b025-41f1-a76b-6153e19413c0.png`，2206×713。
- 只裁去右侧 14 像素全透明余量，裁切 `(0,0,2192,713)`；独立素材没有缩放、拉伸、改色、二次描绘或 Alpha 阈值抹除。人物/房间等参考内容没有进入素材。
- 程序化操作仅用于保留原 Alpha 的裁切导出、给实际 PNG 叠加预览和质检；纸片、夹子与阴影均来自内置生成结果。

| 本轮文件 | SHA-256 |
|---|---|
| 账签_空白_透明_v01.png | `5114A99C80D2675203DE4A5DC446839CFF8875AABD9007F73EDF7D20CD8646CB` |
| 预览_账签_主页左上角_v01.png | `51C3DE8B218405595B593CBDF45DFCA7E19B9FFD3E228325B726D0E82630A820` |
| 预览_账签_手机横屏与透明检查_v01.png | `7A8BA2F384CD896489C315E8AFFA4B649EE36D5CBBA1277A9C90E5843737FE20` |

### 透明与视觉

执行：`& 'D:/taptap/To-the-Human-World/docs/actions/ledger-r1/Export-Ledger.ps1'`，最终退出码 0。

| 检查 | 实际结果 |
|---|---|
| 文件格式与尺寸 | Format32bppArgb PNG，2192×713 |
| Alpha 范围 | 0—255，真实透明 |
| 完全透明像素 | 411451 |
| 半透明像素 | 1151294，含柔影和多数 Alpha=254 的纸面像素，不等于整张纸通透 |
| Alpha≥250 像素 | 942942 |
| 完全不透明像素 | 151 |
| Alpha≥8 范围 | `[66,33,2163,676)`；主体和可见柔影距四边分别约 66/33/29/37 像素 |
| 外围极弱残值 | 画布外边缘有 30 个 Alpha=1 像素，另行逐边检查确认；保留生成 Alpha，不误称所有外边框均为 0。未观察到可见纸片、夹子或柔影截断 |
| 浅底、深底实际查看 | 无矩形底色、烘焙棋盘格或明显白黑杂边；自然纸边及薄阴影保留 |
| 主体检查 | 单枚黄铜夹完整，纸面空白，前视横向，无数字、货币符号、文字、蜡封或卷轴 |

### 最新主页合成

- 源图 SHA-256：`B8C69C911D305074816DCCDC5A99000F59901936461022E7BDB047A434766252`。合成前后复核一致，原图未修改。
- 在 1920×1080 预览上账签左上角 `(36,32)`，等比摆放 `520×169`，不旋转；这是可手动调整的参考，不是冻结排版。
- 账签底边 y=201；捞网顶部目视约 y=385，垂直净距约 184 像素。帆船在其下方、右侧工作桌在其右下方；实际查看未遮住船、捞网及桌面功能物件。
- 像素对照：63012 像素发生变化，变化包围盒 `[47,37,551,194)`；账签放置范围之外变化像素为 **0**。预览没有重新生成或改绘主页。
- 预览示意文本为“第 18 天”“点击收工”“金币 1,280”，不表示真实存档状态；使用 42px 主字与 30px 提示。
- 可参考的文字区域（1920×1080 预览坐标）：日期约 `(80,92)`，提示约 `(86,145)`，金币约 `(306,108)`。日期主行实测宽约 158px，金币主行约 205px，均落在纸面内。

### 手机静态检查与边界

- 实际打开完整预览、浅深底与手机比例检查图，检查 800×450 的 16:9 缩略图及 844×390 的 19.5:9 等比完整适配图。
- 800×450：账签约 217×70px，主字约 17.5px、提示 12.5px；日期与金币可辨，无文字溢出或捞网遮挡。
- 844×390 等比适配：主页显示约 693×390，账签约 188×61px，主字约 15.2px、提示约 10.8px；主信息可辨，提示为次级。更小字号、五位以上余额与系统字体需 C 实测处理，不能直接将所有 UI 永久按背景缩小。
- 未运行游戏、未验收 Tap 胶囊／刘海／触控；日期热区应独立保持手机可点击尺寸，不直接取字面范围。金币区无点击功能。

### 过程问题与处理

- 导出脚本第一次遇到 PowerShell 的 System.Drawing 类型转发编译失败，改为引用实际 Bitmap/Rectangle 程序集后解决。
- 第二次在加载主页时与只读 HOME 变量撞名，执行中止；改为任务专用 homeBitmap。已写出的本任务空白素材逐像素一致校验后复用，没有覆盖其他文件。最终所有检查正常完成。

## 交接与下一步

- 任务版本：B-HOME-LEDGER-20261011 r1；素材 v01。
- 交付用户确认账签整体尺寸与风格；C 之后接真实日期、金币、日期点击确认，不在本轮改前端。
- 必须修改项：本次静态检查未发现必须返工的可见问题；上述 Alpha=1 边缘残值如实保留记录。
- 待决定事项：用户审美采用确认；无新增玩法或范围决定。
- 完整实际生成提示词见下方；内置 imagegen 影响了纸张／金属的制作方法，action-document 用于保留可追溯的实际检查。

## 内置生成提示词

Use case: stylized-concept.
Asset type: one standalone transparent game HUD stationery asset for the hand-painted seaside apothecary game To the Human World.
Input image 1 is STYLE REFERENCE ONLY: the user's latest 1920x1080 home illustration. Do not reproduce, edit, crop, or include the room in the output.
Primary request: a single small HORIZONTAL blank handmade ledger slip with ONE tiny aged brass spring clip attached at the middle of its top edge, isolated on true alpha transparency. Refined warm painterly illustration matching the reference's delicate paper and antique brass materials, not a flat vector icon or modern glossy 3D asset.
View and proportions: almost straight-on front view, paper about 3.1 times wider than tall. Level horizontal orientation, minimal perspective, no foreshortened tabletop view. The entire paper, clip, and feathered shadow must fit, tightly framed with only a little transparent breathing room.
Paper: light cream with a restrained soft grey undertone, not yellow parchment. Subtle fine handmade fibers, a couple of extremely shallow natural creases, gently irregular intact edges. No damage, tears or dramatic curled corners. Keep almost all of the writing surface flat, quiet and clean.
Layout: ample clean LEFT area for a future date and a smaller line under it, ample clean RIGHT area for a future coin balance. These are only blank space reservations: do not draw labels, numbers, glyphs, symbols, grid lines, writing, coins or UI buttons. A barely perceptible center fold can suggest the division without becoming a dark line.
Clip: one compact understated old brass clip, narrow relative to the paper, softly burnished with a muted golden highlight, believable thin metal thickness, complete silhouette. No second clip, nail, seal, string or ornamental hardware.
Lighting: restrained warm light from the upper left to match the reference. A light soft short contact shadow behind the paper, fading smoothly to fully transparent; no heavy halo or large ambient dark patch.
Output: one high-resolution RGBA PNG sprite, genuinely transparent outside the paper/clip/shadow; no room, no tabletop, no solid white or black background, no baked checkerboard. NO TEXT OF ANY KIND. No decorative illustrations, wax seal, scroll ends, burnt edges or strong stains. Only the paper and its small top clip.
