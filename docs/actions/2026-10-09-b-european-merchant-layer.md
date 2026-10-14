# B 窗口欧洲帆船式主页商船组合层

## 状态与背景

- 任务编号：B-20261009-european-merchant-layer；状态：Completed（欧洲船型缩小版、透明组合层与实际叠加预览已交付；视觉采用待用户确认，未接入游戏）。
- 用户认为上一版低篷商船不符合欧洲样式，提供两张船型参考，要求重新制作主页商船组合层。
- 制作中用户补充“现在的商船样式有点大，可以改小一点”。本轮将欧洲商船整组按初始排版大小再缩小 20%，船体、帆、索具、水纹同步，保持水线中心 (617,518)；最终以缩小版交付。
- 已确认：以用户参考中的高船艉、多桅、浅色布帆、完整索具替换旧船型。沿用上一轮交付约束：以 BG04 无船 v01 为底图，941 × 1672、真实透明、原水面位置、船体/索具/倒影/水纹成组，附实际叠加预览。
- 本轮原位置按船身与水线确定；新船型桅杆较高，不为迁就旧低篷船的上边界而压扁船型。
- 参考只作用户指定的视觉结构依据，不把海报文字或船型年代当成已核实史实。两个附件已目视；底图已目视。
- 不覆盖旧版、不改无船底图、不开发布局编辑器、不接入游戏，不直接派单给 C。

## 实施措施

1. 归档两个附件到素材目录，内置 image_gen 根据船型参考和 BG04 背景风格生成一版完整透明组合工作稿。
2. 以高船艉、三桅、米白帆、完整细索具、朝左上船头为识别重点，木色与水色适配底图；船体入水，避免把参考中的干船模型和露出龙骨照搬。
3. 与上轮相同，在导出阶段注册到 941 × 1672 透明画布。保持船身原位置，船型的自然高度允许增加，按底图窗沿遮挡下部水面。
4. 将最终 PNG 按 (0,0)、1:1 真实 alpha 叠加到未改底图，输出全幅预览与局部放大，核对接缝、索具和水线。
5. 持久化验证与交接，更新 B 素材规划入口。

## 影响文件树

```text
docs/actions/2026-10-09-b-european-merchant-layer.md          本轮事实、提示词与交接
docs/设计/B窗口_分层素材规划_v01.md                        最新船型入口
scripts/素材/参考_欧洲商船_01.jpg                          用户附件原样归档
scripts/素材/参考_欧洲商船_02.jpg                          用户附件原样归档
scripts/素材/过程稿/H18_欧洲商船_AI生成_v02.png             已输出：高分辨率透明工作稿
scripts/素材/H18_欧洲商船组合层_原位_941x1672_v02.png        已输出：按用户要求缩小后的使用资产
scripts/素材/预览_BG04_欧洲商船_原位叠加_v02.png             已输出：实际全幅合成
scripts/素材/预览_BG04_欧洲商船_接缝放大_v02.png             已输出：旧船位、底图、透明层、实际合成 2 倍对照
.tmp/b-merchant-layer/export-european-merchant.ps1            已执行：导出/验收辅助，不接入游戏
```

## 自验证方法

- 内置 image_gen 负责船型和透明图像生成；本地标准图像渲染仅用于画布注册、窗沿遮挡、实际合成预览。Python/Pillow 仅只读检查。
- 确认 941 × 1672 RGBA、大片 alpha=0、四边全透明、索具与帆顶未截断；透明区外的预览与底图像素完全一致。
- 船身中心约 x617，水线约 y518；按用户最新缩小要求，船体宽从约145像素减至约116像素，新三桅船保持纵向比例。放大图核对水纹边缘没有明显矩形接缝、木窗沿前没有水面覆盖。
- 检查源图哈希不变；记录生成稿与最终文件尺寸/哈希。无游戏行为变更，不执行构建或接入测试。

## 自验证结果

- 已交付缩小版：初始计划导出倍率 0.16，用户提出偏大后改成 0.128（整组缩小20%），保持原水线中心 (617,518)。最终导出偏移 (529.96,391.28)，全部相对关系等比保留。船体约 x560—675，船艏斜桁向左延伸，三桅自然高度未压扁。
- 最终图为 941 × 1672 RGBA，alpha 范围 0—255，1,561,065 个完全透明像素、11,401 个部分透明像素；四边 alpha=0。有效包围盒 [534,391,684,532]（右/下界不含）。完整桅杆、旗顶、船帆、艏斜桁及索具无画布裁断。
- 已用 `.tmp/b-merchant-layer/export-european-merchant.ps1` 将最终文件重读并按 (0,0)、1:1 直接 alpha 合成。Pillow/NumPy 只读检查：透明区外改变像素数 0；y≥540 的室内区域改变像素数 0；合成公式独立核验最大通道差 1（舍入）。无船底图 SHA-256 保持 `633637BD2998CBE61B99207037D1CE3DA76B16829980378F9322735C426442AF`。
- 已目视全幅和 2 倍对照：三桅、浅帆、高艉与原低篷船明显不同；船体及索具可辨，水面边缘未見明显矩形色块/粗亮边，窗沿遮挡正常，少量倒影留在海面上。原尺寸帆布比周围灰蓝水面更亮，符合本轮参考；正式审美采用仍由用户决定，不据此自动冻结规范。
- 首次尝试查看预览时导出命令仍在运行，文件尚未生成；等待该进程退出成功后，按用户新缩小要求重导并完成上述检查。该读取时序问题已解决，不是素材检查失败。
- 最终组合层 56,595 字节，SHA-256 `1540713D01E01BB8BABB5599B4A2C17BB3363ABEF40E33E5D5611C465AEA1A07`；全幅预览 3,686,202 字节，`E1559AEF9F6CCC7ECDEBE92EE296796FD17C25C85C95E5F4D0C05579FA296B21`；放大对照 462,942 字节，`032C530D2E06F4F1E1CAA9C2240C4D8C02092ED1ED494ECE2C628BC36F69730A`。
- 原低篷船 v01 和全部底图均保留。未进行游戏/编辑器运行验证，因为本轮没有接入修改。

- 首稿 `exec-73dc9b34-5fb3-4452-8f64-93478ebc41f6.png` 为 1209 × 1300 RGBA，真实透明，船型为三桅、高艉、米白帆、船头朝左。alpha≥16 内容 [33,5,1198,1294]，未发现桅杆实体截断。但海水金色反光过强、外缘偏硬，先以单项编辑修正水面再进行最终导出。
- 采用水面修正稿 `exec-b6217a0d-2098-4bed-a385-20c251b31edf.png`，1209 × 1300 RGBA；已归档至上方过程稿路径。反光减弱，保留暗倒影和软水纹，完成画布注册后作为 v02 输出；透明缝隙含 AI 生成，不作为历史船型结构考据成果。

## 工具与完整提示词

使用内置 image_gen，`transparent_background=true`，无 CLI/API 回退。输入顺序：附件 01、附件 02、BG04 无船 v01。

```text
Use case: compositing.
Asset type: transparent merchant sailing-ship composite for a painted mobile game home screen.

Inputs:
Image 1 and Image 2 are USER SHIP-DESIGN REFERENCES. Use only the central European-style wooden sailing ships, ignoring the phone interface, poster lettering, diagrams, globe and surrounding presentation.
Image 3 is the authoritative background for illustration style, camera angle, evening illumination, water color and intended placement.

Create ONE ship+rigging+reflection+nearby-water composite on REAL TRANSPARENT background.
Replace the previous low canopy cargo boat design with the reference silhouette: a rounded wooden merchant hull, elevated enclosed sterncastle with a few small windows, a projecting bowsprit, THREE slender masts with complete standing and running rigging, rope ladders and several clearly separated ivory canvas sails. Use Image 1's bow-left, high-stern-right arrangement and Image 2's warm oak and pale canvas. The bow points to the upper left toward the dock; show the near side and a little deck from a modestly elevated three-quarter viewpoint, as seen from the room in Image 3. NOT a flat side-elevation ship-model diagram.

Style: match Image 3's soft hand-painted illustration, fine restrained outlines, matte warm honey/medium-brown wood, cool muted blue-gray shadows, soft cream sails. Warm late-evening light from upper left. Preserve a convincing European tall-ship silhouette. Simplify microscopic ornament to remain readable at small on-screen size; avoid dense gold filigree and glossy 3D-model rendering. Sails gently filled by a light breeze with quiet folded shading, no dramatic storm. No arched wicker canopy, no low river barge, no battened junk sails. No pirate symbols, guns, battle effects, text, labels or additional vessels.

Waterline and integration:
The ship is AFLOAT. Hide the underwater hull/keel below the water, rather than depicting a dry ship model on a stand. Include a compact dark reflection, pale sail reflections broken into short strokes, and soft short contact ripples as one composite. A small irregular patch of the same blue-gray sea as the lower-right window in Image 3 is allowed. It must fade gradually to alpha zero over a generous soft irregular boundary following the waves. No rectangular sea patch, hard oval edge, large wake, waterfall, pedestal, bright gold water stripe or opaque backdrop.

Render the entire composite at generous detail, with comfortable transparent margins around ALL mast tips, ropes, bowsprit, stern and water effects. Nothing cut off. Keep the ship opaque, with antialiased ropes and natural partly transparent water edges. This working image will be exported onto the exact 941 x 1672 background-size transparent canvas with the hull near the original location (center x617, waterline y518, hull width about145 pixels). Therefore preserve the tall multi-mast proportions instead of squashing the ship to the old canopy-boat's height.
Do NOT render the room, landscape, sky or dock. Only one complete sailing merchant ship and its compact water effects, on true transparent PNG.
```

## 交接对象与汇报内容

### 水面匹配修正提示词

```text
Edit Image 1, the transparent sailing merchant ship asset. Image 2 is the destination background.
CHANGE ONLY THE WATER EFFECTS. Preserve the ship, all three masts, every sail and rigging line, bowsprit, hull, stern, heading and scale exactly as in Image 1.

The ship belongs in the LOWER RIGHT water of the window in Image 2, near x617,y518, where the water is subdued blue-gray rather than a stripe of reflected sun. Remove the bright gold sunset stripe and glowing golden highlights from the surrounding water in Image 1. Keep low-contrast muted blue-gray sea, a compact dark hull reflection, subtle broken pale sail reflections and small soft contact ripples. Do not change the warm light on the ship itself.

Also make the outside boundary of the small water patch fade gradually and smoothly all the way to alpha zero, across a BROAD SOFT FEATHER of about 60 source-image pixels, irregular along water strokes. It must not have a hard cutout, opaque oval edge or white halo. Preserve enough water at the hull's contact edge so the vessel looks afloat, with the keel concealed. Keep all areas between ropes and sails genuinely transparent.
Retain the same portrait asset dimensions and ship placement. Real RGBA transparent PNG; no background scene, text or props.
```

- 交接对象：A 统筹与审查，由用户转发。
- 任务编号与参考版本：B-20261009-european-merchant-layer，用户 2026-10-09 两张船型附件 + BG04 无船 v01。
- 用户已明确：旧船欧洲样式不符，按附件重新制作一版；延续组合层与原位约束。
- 用户后续明确：商船偏大，需要缩小；本次交付已按整组缩小20%完成。
- 本轮成果：[欧洲商船透明层](../../scripts/素材/H18_欧洲商船组合层_原位_941x1672_v02.png)、[实际原位叠加](../../scripts/素材/预览_BG04_欧洲商船_原位叠加_v02.png)、[接缝放大](../../scripts/素材/预览_BG04_欧洲商船_接缝放大_v02.png)。全部保存于用户指定素材目录。
- B 推荐：采用附件高艉/多桅/浅帆的大轮廓，缩减细小雕花，优先保证手机上辨认出帆船。
- 待决定：新船型的视觉采用；不把本次生成自动视为正式审美通过。
- 如果采用，C：底图上 (0,0)、941 × 1672、旋转 0、正常透明叠加；底图和组合层同步整体缩放，船层用于显隐，不单独漂移带海水的贴片。
