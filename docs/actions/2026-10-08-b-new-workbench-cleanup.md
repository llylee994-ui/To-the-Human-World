# B 窗口新工作台附件：指定物件擦除与透明窗景

## 状态与背景

- 任务编号：B-20261008-new-workbench-cleanup；状态：Completed（v01/v02 保留，去捞网背景 v03 与独立透明捞网素材均已交付）。
- 最新追加：用户要求把捞网从背景中移除，并单独提取捞网素材；两项均以无日历提灯 v02 为输入。
- 最新用户要求：“把日历和灯也去掉”。覆盖下文首次 v01 对日历、提灯的保留约定；v02 其余保留范围不变。
- 用户提供新附件 `C:/WINDOWS/TEMP/codex-clipboard-9092146d-c845-4dd7-bbc4-4b5e31215607.png`，要求擦除窗外景色、风铃、铃兰花瓶、书本、剪刀、托盘、药炉、盘子、钱袋、装花玻璃瓶、墙上档案袋。
- 本轮以这张附件为唯一编辑底稿，不套用此前另一张原型“清空全部物件”的范围；先前背景文件保留。
- 处理约定：窗外景色去除后做真实透明窗洞；室内擦除处补回木纹等原材质。未列出的捞网、日历、提灯、书写垫、椅子及布、攀藤等保留。
- 附件已用 view_image 目视，SHA-256 为 `C7DBB8A2D58A62F5E71E66A8C35CB63A831EA886FD8050FFCB1D8E3F5090211B`。将原样保存参考副本，避免依赖临时目录。
- 使用内置 image_gen，`transparent_background=true`，无 CLI/API 回退；不改生产代码、正式布局或 A/C 文件。

## 实施措施

1. 保存附件参考副本到用户指定素材目录，保留输入原样。
2. 按清单局部清理，连同关联标签、火焰、蒸汽、挂绳与专属投影一起移除；补全室内遮挡面。
3. 窗外海天、码头、船、漂流瓶全部去除，窗框和前景攀藤保持，窗洞使用 alpha 透明。
4. 目视逐项检查移除与保留清单；只读核对透明度、尺寸和拷贝哈希，保存最终图。
5. 更新本记录与 B 素材规划中的输出入口。必要时仅针对残留或误删做局部修正。

## 影响文件树

```text
docs/actions/2026-10-08-b-new-workbench-cleanup.md             行动事实、提示词与核验
docs/设计/B窗口_分层素材规划_v01.md                          新附件清理输出入口
scripts/素材/参考_新工作台原图_v01.png                        已保存：用户附件原样副本
scripts/素材/BG03_工作台_局部清理_透明窗景_v01.png             已交付：指定物件清除、窗洞透明的场景层
scripts/素材/BG03_工作台_透明窗景_无日历提灯_v02.png           已交付：继续去除日历和左侧提灯
scripts/素材/BG03_工作台_透明窗景_无捞网_v03.png               已交付：移除捞网并补全遮挡面
scripts/素材/H06_捞网_透明_v01.png                            已交付：含完整网兜与长柄的透明捞网素材
```

## 自验证方法

- 逐项目视移除窗外景色、风铃及挂饰、铃兰与瓶、所有可见书、剪刀、木托盘、炉锅/火/蒸汽/勺、石碗及内容、钱袋与 30 标签、装花玻璃瓶、档案袋与卡信。
- 目视保留网、日历、提灯、垫、椅子布、攀藤和固定结构；擦除的室内区域补回合理材质，无透视断裂。
- Pillow 仅作只读检查：RGBA、窗洞中心 alpha=0、桌面/墙/保留物件接近不透明；不绘制、裁切或修改图片。
- Get-FileHash 校验缓存与输出一致、参考副本与附件一致、附件原始哈希不变。
- 图像包含 AI 补绘，不承诺逐像素无损。无编辑器、Maker 或手机接入验证。

## 自验证结果

- 内置 image_gen 一次完成。已目视：窗外海天、山岸、建筑、船与漂流瓶均移除；风铃、铃兰花瓶、书本、剪刀、托盘、炉锅及火/蒸汽/勺、石碗、钱袋与数字牌、装花玻璃瓶、墙面档案袋均已清除。
- 捞网及长柄、日历“第1天”、左侧提灯、书写垫、前景椅子与布、窗边攀藤、固定桌柜和窗框保留；室内擦除处已补回木纹，未见大块物件残影。细小植物和材质笔触有 AI 重绘变化，非无损像素编辑。
- 输出缓存：`C:\Users\YINGYI\.codex\generated_images\01a119d9-8765-7312-bdb9-e6179a44dfce\exec-3e56156f-5f08-49a2-82a8-a783c160c01f.png`，已原样复制到 `scripts/素材/BG03_工作台_局部清理_透明窗景_v01.png`。
- Pillow 只读加载与模式检查通过：输出 941 × 1671、RGBA PNG、2,291,395 字节；参考原图 941 × 1672、RGB PNG。输出高度比原图少 1 像素，未另作缩放。
- alpha 核验：范围 0—255，完全透明像素 297,397，alpha <16 像素 309,326，alpha ≥240 像素 1,255,515。窗洞中心 (450,150)、(450,400) 为 [0,0,0,0]；桌垫、桌面、右墙采样 alpha 为 253，确认窗洞真实透明而非黑色实底。
- 工具预览窗缘存在亮色显示，读取数据后确认高饱和红黄色边缘像素均 alpha <32（共 4,069 个）；alpha ≥32 的此类颜色像素为 0。未另做海景合成渲染，后续接入时仍应检查实际透明边缘观感。
- Get-FileHash 核验通过：生成缓存与交付 SHA-256 均为 `8F21A8EBE99F3970A3F3CF065FB94014671C80F4345B88639460B7AA67244BDF`；参考副本与原附件均为 `C7DBB8A2D58A62F5E71E66A8C35CB63A831EA886FD8050FFCB1D8E3F5090211B`，原附件未修改。
- 已保存附件参考副本以便后续修订；未覆盖此前 BG02。未执行编辑器、Maker 或手机接入验证。

## 工具与完整提示词

工具：内置 image_gen；输入为已目视附件的原样参考副本；透明输出。

```text
Use case: precise-object-edit.
Asset type: portrait illustrated room/workbench layer with a TRANSPARENT WINDOW OPENING, for placing a separate landscape behind it.
Input image 1 is the EDIT TARGET. Preserve this exact scene, camera, portrait framing, illustration style and remaining object positions. Remove ONLY the objects listed below.

1. ERASE ALL OUTDOOR SCENERY visible through the large upper window: sky, sea, distant mountains/islands, lighthouse, village, docks, merchant boat, floating message bottle, water reflections and outdoor rocks. The entire window aperture behind the foreground room and climbing vine must become REAL ALPHA TRANSPARENCY. Do not replace it with white, beige, black, blur, painted checkerboard or a new landscape. Preserve the existing wooden window posts, sill and their edges, and preserve the foreground climbing vine leaves and flowers crossing in front of the window with clean transparent gaps between them.
2. Remove the hanging brass wind bell at upper right, INCLUDING its suspension ring/chain, bell clapper and long leaf-shaped pendant.
3. Remove the lily-of-the-valley bouquet AND its small glass vase at the left side beside the calendar; remove that object's flowers, leaves, stems and glass, leaving the separate climbing vine intact.
4. Remove ALL books: the large green leather book at the lower center-right with its bookmark, the partly cropped blue/green books at the right edge, and the partly visible books on the upper-right shelf.
5. Remove the gold scissors at the lower center, and the wooden tray at lower left, including each object's contact shadows. Reconstruct the original wooden tabletop seamlessly beneath them.
6. Remove the entire potion cauldron and stove assembly at right, including the ladle/stirring spoon, potion, steam, fire and glow, and the stone dish/bowl/mortar at the far right with its contents and associated loose herb garnish.
7. Remove the brown money pouch, coins and attached paper tag "30".
8. Remove the glass bottles/jars filled with flowers/herbs at the right window/table edge: the large corked daisy jar, adjacent smaller corked herb jar, the narrow vase holding purple flower stems, and the small flower-filled glass bottle on the right wall shelf. Remove their lids, flowers, foliage and reflections too.
9. Remove the hanging wall archive/letter pockets at upper left, all envelopes/cards in them and their hooks/clips. Reconstruct continuous wooden wall underneath.

For every removed INDOOR object, fill its former area with the correct underlying painted wood, window frame, shelf, tabletop or wall. These indoor removal patches must remain OPAQUE. Only the WINDOW APERTURE is transparent. Do not leave object-shaped holes, ghost silhouettes, stray handles, steam or rectangular patches.
KEEP the unlisted objects: the fishing/salvage net and long handle leaning on the left, the standing calendar displaying "第1天", the brass lantern at lower left, the large pale writing mat, foreground wooden chair and draped botanical cloth, the living climbing vine and other unlisted greenery, the wooden shelves/room/table/drawer with handle. Preserve their designs, positions, proportions and lighting. Do not clear the entire room or remove the writing mat.
Match original fine hand-drawn outlines, softly painted warm wood, natural material grain and soft shadows. Keep the original perspective and framing, aiming for the same 942×1672 portrait. No crop, zoom, new decorations, new UI, watermark or restyling. Deliver a real RGBA PNG: opaque retained room and objects, alpha-zero empty window behind the retained vine.
```

## 交接对象与汇报内容

### v03 追加：去捞网背景与透明捞网素材

- 输入：已目视 `BG03_工作台_透明窗景_无日历提灯_v02.png`；哈希 `5693F0F03C88AEB1E0E403E69F676A06D57FBA66228EC654AC9BDE2AF985907C`。
- 措施：两次独立内置图像编辑，分别移除场景捞网及阴影、提取原捞网完整透明轮廓；仅对参考边缘少量被裁切的网绳补全，不重新设计角度。两者均 `transparent_background=true`。
- 验证：背景无网圈、网绳、长柄和专属阴影；窗洞 alpha 保持，墙柱补绘不透明。素材完整长柄、网兜和结绳可见，网眼有真实透明；边缘不裁切。两文件核对尺寸、alpha、哈希，旧 v02 保留。
- 核验结果：两次内置图像编辑均成功。已目视背景无网圈、网袋、结绳、长柄，遮挡墙柱和窗台补绘连续，窗洞透明；书写垫、椅子布和攀藤保留。素材单独显示完整木圈、网兜和长柄，倾斜方向沿用参考，无裁切边缘。素材属于 AI 提取与补全，网绳/包边/杆端局部细节并非原图逐像素裁切；未做复位叠加验收。
- 背景来源 `exec-05f07187-80e7-4b54-bad5-68ceab487822.png`，已保存 v03。Pillow 只读检查：941 × 1671、RGBA、2,080,906 字节；完全透明 286,726 像素，alpha ≥240 为 1,263,053；窗洞两处 alpha=0，原网所在木墙/长柄区 alpha=252—253。
- 背景缓存与交付 SHA-256 均为 `D175D761DBC5FF504E73BA146EBDC27B93085C31C033A2F5DCD5FC31C36806FB`。
- 捞网来源 `exec-5fff2a14-c1d8-4812-9041-8bf59d542773.png`，已保存 H06。Pillow 只读检查：1024 × 1536、RGBA，alpha 范围 0—254；完全透明 1,205,261 像素，alpha ≥240 为 135,461，四边最大 alpha=1。网圈内部检查区域 41,800 像素中 26,534 个 alpha <16，取样网眼 alpha=1—2，确认网眼可透出底图。
- 捞网文件 1,712,929 字节；缓存与交付 SHA-256 均为 `E02F6297303FB3FA204DA764C01BFB422C50DDEF025DA00890925705337EC576`。Get-FileHash 确认 v02 仍为 `5693F0F03C88AEB1E0E403E69F676A06D57FBA66228EC654AC9BDE2AF985907C`。未用脚本修改图片像素，未进行编辑器或游戏接入。

背景去捞网提示词：

```text
Use case: precise-object-edit.
Input image is the EDIT TARGET: the wooden workbench scene with transparent window, no calendar or lamp, and one long-handled landing net leaning on the left.
Remove the ENTIRE landing net from this room: oval wooden/bamboo hoop, every pale rope mesh strand and knot, hanging net bag, wrapped joint, long wooden handle down to its bottom tip, and all net-specific cast/contact shadows. The net occupies roughly the left 0–220 pixels from y=240 to y=685 in the 941×1671 image.
Reconstruct the wooden wall/post, window frame and sill behind it, continuing their existing grain, contour lines and lighting. Where the net overlaps the already transparent window aperture, restore true alpha transparency instead of wood. Keep opaque wooden surfaces opaque; no net-shaped transparent holes on the wall and no pale mesh traces.
Preserve everything else: full portrait framing, window opening's true transparency, climbing vine and flowers, shelves, warm wooden desk and drawer, writing mat and stitching, foreground chair and draped cloth, unlisted leaves and fixed structural shadows. Do not restore any calendar, lamp, book, tray, cauldron or other removed prop. No zoom, crop, new objects or restyling. Match the source fine drawn contours and softly painted texture. Output the same 941×1671 RGBA scene with only the net removed.
```

捞网透明提取提示词：

```text
Use case: background-extraction.
Input image is the EDIT TARGET and sole object reference. Extract ONLY the complete long-handled landing net leaning against the LEFT side of the room into a standalone transparent PNG asset.
Match the exact original net design and perspective: a warm honey-brown oval wooden/bamboo hoop, pale off-white hand-knotted rope mesh with irregular diamond openings, a softly sagging rope net bag below/left of the hoop, a wrapped joint, and the long slender wooden handle. Keep its original leaning orientation: hoop at upper left and handle extending diagonally downward to the right. Keep the same proportions of hoop, bag and handle, the same visible view of the oval opening, fine hand-painted outlines, soft material shading and restrained warm lighting. Do not straighten it vertically, change the viewing angle, shorten the handle or turn it into a different kind of net. Restore only tiny edge portions clipped by the source image border so the entire silhouette is visible.
Show ONE net only, including every rope strand, the whole hoop and entire handle tip. All gaps between mesh strands, the open hoop interior behind the mesh and all areas outside the net must be REAL alpha transparency. No wood wall texture inside the net holes, no opaque white fabric panel, no background color, black fill, checkerboard, tabletop, floor, room objects, greenery, shadow extending onto a surface, text, labels, extra net or watermark.
Use a tall portrait canvas fitted around this diagonal object with modest transparent padding on every side. Preserve the source angle rather than forcing the net to fill the canvas. Clean antialiased edges and a readable complete rope structure. Deliver genuine RGBA PNG; only the wooden hoop/handle and rope are visible.
```

### v02 追加：去掉日历和提灯

- 输入：BG03 局部清理透明窗景 v01，本轮已再次目视。
- 措施：仅擦除左侧日历本体、支架及阴影和提灯本体、光晕及阴影，补回不透明木质桌面；继续保留透明窗洞。
- 验证方法：目视两件物品无残留，捞网/书写垫/椅子/攀藤保留；读取 alpha、尺寸和 SHA-256，核对复制一致、v01 未覆盖。
- 验证结果：一次内置图像编辑完成。已目视日历本体/支架/文字和提灯本体/光晕清除，两处补回木纹；捞网长柄、书写垫、椅子布和攀藤保留，无新增物件。AI 仍有局部笔触重绘，不声称逐像素不变。
- 输出来源 `exec-b0630997-36bb-4214-b396-6701a48df992.png`，已保存 `scripts/素材/BG03_工作台_透明窗景_无日历提灯_v02.png`。Pillow 只读核验通过：941 × 1671、RGBA PNG、2,168,487 字节；完全透明像素 295,468，alpha ≥240 像素 1,259,551。
- 窗洞 (450,150)、(450,400) alpha=0；原日历区 (110,700)、原提灯区 (25,860)、桌垫及桌面采样 alpha=253，擦除处为补绘木面，透明窗洞保持。
- SHA-256 校验缓存与 v02 输出均为 `5693F0F03C88AEB1E0E403E69F676A06D57FBA66228EC654AC9BDE2AF985907C`；v01 仍为 `8F21A8EBE99F3970A3F3CF065FB94014671C80F4345B88639460B7AA67244BDF`，未覆盖。无编辑器或游戏接入验证。
- 工具：内置 image_gen，`transparent_background=true`；完整提示词：

```text
Use case: precise-object-edit.
The input is the EDIT TARGET: the cleaned wooden workbench scene with a genuinely transparent window opening.
Remove exactly TWO additional objects:
1. The small standing spiral-bound calendar on the left tabletop, including the "第1天" paper page, rings, dark triangular stand and calendar-specific cast/contact shadow.
2. The brass lantern partly clipped by the LEFT image edge, including its cap, glass, handle, base, light/glow and lantern-specific shadow.
Reconstruct the continuous warm wooden tabletop and any wooden wall surface they covered. Follow the existing plank direction, perspective, grain, painted texture and ambient light. No calendar, text, brass lamp fragment or object-shaped shadow may remain in these two areas. Repaired wood must be opaque, not a transparent hole.
Preserve ALL other content and composition: the fishing net and long wooden handle on the left, the large pale writing mat and its edge stitching, the wooden chair and draped cloth, foreground leaves, living climbing vine, window frame/sill, shelves, table and drawer handle. Do not move the mat or erase the net's lower handle. Keep the SAME real alpha-transparent window opening and transparent gaps around the vine; do not fill it with black, white, a checkerboard or scenery.
Keep the same 941×1671 portrait framing, warm hand-painted illustration style and proportions. No crop, zoom, restyling, new objects or text. Deliver RGBA PNG with transparent window and opaque retained room; change only the calendar/lantern areas.
```

- 交接对象：A 统筹与审查，由用户转发。
- 任务编号与参考版本：B-20261008-new-workbench-cleanup，附件 9092146d；不替换旧 BG02。
- 最新成果：[BG03 无捞网背景 v03](../../scripts/素材/BG03_工作台_透明窗景_无捞网_v03.png)与[H06 透明捞网](../../scripts/素材/H06_捞网_透明_v01.png)；v01、v02 及原始附件参考均保留。
- 用户已明确：移除上述列出的物件和窗外景色，木托盘也移除；追加去掉日历、提灯及捞网，捞网另交独立透明素材。
- B 处理建议：窗口保留真实透明，室内补绘为不透明材质，后续可从底层替换海景。
- 待决定：用户审看清理结果；图片编辑不等于正式美术规范冻结。
- 如果采用，C 将此图作为室内场景层，海景放其下；按真实透明通道显示，不把白底或棋盘格当透明。
