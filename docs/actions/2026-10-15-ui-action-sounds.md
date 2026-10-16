# 普通按钮与重要操作音效

## Status and situation

Completed（接入、静态/隔离回归及原生运行检查完成；实际听感与手机实机仍待用户确认）。在 `feat/scene-bgm` 的 `e90be33` 基础上补充用户指定的 `ui_click_01` 与 `ui_confirm`；开始时工作区干净。2026-10-16 用户明确授权将本次改动本地提交至 `feat/scene-bgm`，不推送、不合并 `main`。

- 当前工程无 AGENTS.md；沿用用户提供的协作规则、已读取的 `scripts/fyyAGENT.md` 和本机 SDK 音频接口。
- 最新请求明确要求验证，覆盖设置、提示、跨天、购买成功/失败及重复点击；优先使用隔离存储和真实 UI 回调，避免修改玩家存档。实际听感不能用模拟音频或网页试听代替。
- 原料、家具购买直接提交交易；船票先显示确认窗口，再经 TravelTicket.Purchase 提交。跨天入口经 AppView.Open("day")，最终确认在 Panels.Day。
- 复用 ObjectSounds 的独立音效声源池与 SoundSettings，音频原样导入，不归一化、不额外放大。八个专属音效和所有 BGM 文件及音乐控制逻辑保持不变。
- 普通点击按明确的 UI 状态切换接入，不在 Harbor.Button 或通用 onClick 全局添加声音，避免与专属声和最终确认声叠加。不照搬素材包建议的随机音色或定时去抖。

## Implementation measures

### 2026-10-16 本地提交范围

- 本轮只整理并提交已完成的按钮点击与确认音效：五个运行模块、两个新增专项验证文件、既有物件音效验证适配、四个资源/来源文件和本行动记录，按明确文件清单暂存。
- 沿用下文已有验证结果；本轮执行提交范围与差异检查，不重复运行游戏或自动交互。用户授权本地提交不等于主观听感或手机实机验收。
- 交付仅限当前分支的本地提交；保持 `main` 引用不变，不执行网络推送或合并。

### 接入措施

1. 导入两个 WAV 至 `assets/audio/sfx/ui/`，保存来源授权、清单及文件哈希；保留外部原始试听包。
2. ObjectSounds 增加两条资源映射，仍单次播放、基准增益 1.0，共享现有用户音效音量。
3. 设置、提示、普通面板入口以及商店分类/翻页等实际状态切换播放点击；专属物件入口继续只播放专属音效。取消/关闭确认窗口使用普通点击，不播放确认声。
4. 原料/家具购买只在成功结果后播放确认。船票开窗播放点击，最终成功启程只播放确认。跨天确认只在业务接受后播放确认，并保护已经提交或离开的旧回调。
5. 专项验证与现有物件/BGM 回归；Lua 诊断、资源哈希和差异检查。原生运行能力与实际听感单独记录，不将适配器结果称为设备验收。

## Affected file tree

- `assets/audio/sfx/ui/`（新增）：两个 WAV、来源授权和导入清单。
- `scripts/ui/landscape/ObjectSounds.lua`（修改）：复用播放器注册 UI 资源。
- `scripts/ui/landscape/AppView.lua`（修改）：设置、提示及普通面板状态切换。
- `scripts/ui/landscape/ShopView.lua`（修改）：分类/翻页、成功购买、船票确认入口。
- `scripts/ui/landscape/TravelTicketView.lua`（修改）：取消、返回与最终成功确认。
- `scripts/ui/landscape/Panels.lua`（修改）：跨天确认的一次性接受与成功声。
- `scripts/ui/landscape/tests/UiActionSoundsTest.lua`、`run_ui_action_sounds.py`（新增）：隔离存储、实际回调及音频调用验证。
- `scripts/ui/landscape/tests/ObjectSoundsTest.lua`（修改）：允许共享播放器新注册的两个资源，保留原八项边界验证。
- `docs/actions/2026-10-15-ui-action-sounds.md`（新增）：本行动记录。

## Self-verification method

- 比对两个源文件和导入副本 SHA256、WAV 格式及清单。核对 BGM、原八份 WAV、SceneMusic、MusicSettings、SoundSettings 均无改动。
- 专项检查设置重入、提示有效切换、跨天开窗/取消/接受/失败/重复、交易成功/不足/写入失败/过期报价、船票确认与取消；统计每次有效操作的声种、次数与 BGM 播放/停止调用。
- 现有物件与音乐回归、EmmyLua Error 检查、Git 差异检查。采用真实业务模块，音频或窗口适配部分明确标注。
- 普通预览启动和日志仅作为加载证据；如进行原生交互，使用隔离存档并单独记录。实际听感待用户确认。

## Self-verification results

- 两份导入 WAV 的 SHA256 与源文件、导入清单完全相同；源试听目录未修改。八份物件 WAV、两首 BGM、SceneMusic、MusicSettings、SoundSettings 均无差异。
- `run_ui_action_sounds.py`：386 项通过，使用真实 AppView 控件回调、schema-4 交易及隔离存储，音频/时钟/UI 布局为显式适配器。覆盖开窗/取消/成功/写盘失败/余额不足/售罄/家具报价幂等重放/票价版本更新/重复点击/音效音量和静音；不是原生点击或实际听感。
- 发现并处理家具购买的幂等返回：`PurchaseHomeItem` 可以返回 `ok=true, alreadyPurchased=true`；该结果不播放确认音，防止重复报价误报新成交。
- 专项首轮将船票购买后的商店→结局场景切换误判为 BGM 中断。检查预期已修正以保留原有场景音乐规则；生产音乐逻辑未修改。
- 既有 `run_object_sounds.py`：584 项通过；`run_scene_music.py`：144 项通过。测试中的保存失败、余额不足、缺失资源等日志为主动注入场景。
- 首轮 EmmyLua：7 个文件、0 Error、247 Warning。补充新局部变量类型标注后，最终为 0 Error、145 Warning；警告包含既有动态 UI 类型和测试替身推断。证据 `.tmp/ui-action-sounds-lsp/diagnostics.json`。
- 为原生验证暂时将 `scripts/main.lua` 替换为 `.tmp/ui_action_native_main.lua`，原文件逐字节保存在 `.tmp/ui-action-original-main.lua`。验证入口使用真实引擎/UI/声源，玩法与偏好存储均为内存夹具。检查后恢复原入口并逐字节核对，不保留探针为正式入口。
- 商店既有回归 `run_shop_view.py`：51 项通过；船票 `run_travel_ticket.py`：47 项通过。
- 两个 WAV 均为 44100 Hz、单声道 PCM16；点击 0.14 秒、确认 0.43 秒。导入字节保持原样。
- 首次原生检查（原会话 reload 1）在 LoadPreloadResources 阶段报告一个文件下载不完整/损坏，未进入检查入口；既有环境错误 Cube/Day/DaySpecularHDR.dds 和 themis_x64.dll 也仍存在。已核对预览副本 main.lua 与隔离入口 SHA256 一致，正式 main.lua 已恢复且与 HEAD 无差异；未将该失败归因于生产音效代码。已用官方刷新流程重试一次。
- 原生重试 reload 2 已通过设置/提示/跨天/原料与家具交易/船票的 21 个操作场景，原生源确认 SoundType=Effect、44100 Hz、gain=1，BGM 在同场景操作期间保持同一播放声源且位置持续前进。检查器在切换余额不足夹具时把已 Stop 的旧 Music 源也计为重叠，导致中止；已将检查器统计口径改为正在播放的 Music 源，生产逻辑未修改。证据 `.tmp/ui-action-native-result.json`。
- 最终原生检查（session `144ff4fa-0b04-4c14-84f2-9876273cd722`、reload 3）26 个场景全部通过：设置重入、提示连切、跨天打开/取消/写入失败/重复确认、原料成功/写入失败/售罄连续购买、家具重复报价、船票打开/取消/失败/确认、余额不足连续点击和禁用回调。通过真实引擎 UI 命中与指针分发触发首个点击，额外调用同一旧回调压测重复；不等同于操作系统鼠标或手机触控验收。
- 原生检查逐次核对音效源实际 playing、声种、频率和增益；同场景内 BGM 保持同一播放源、gain=1。26 组独立播放位置记录全部向前，最小前进约 0.356 秒；进入商店和离开商店进入结局仍遵循原有换曲规则。证据 `.tmp/ui-action-native-final-result.json`。测试玩法和偏好均在内存，未写玩家存档、未修改玩家音乐/音效偏好。
- 静态差异检查通过。正式 main.lua 已逐字节恢复且相对 HEAD 无差异，DevChecks 未改；没有正式探针入口。普通游戏已恢复（同会话 reload 4、PID 26784、窗口标题“寄往人间”），日志确认“启动完成”并加载 ObjectSounds / SoundSettings，未运行 UiActionNative；回执 `.tmp/ui-action-player-refresh.json`、日志 `.tmp/ui-action-player-log.json`。既有 Cube/Day/DaySpecularHDR.dds 与 themis_x64.dll 环境错误仍在，不宣称日志全无错误。之后不再执行自动交互。
- 听感未由助手验收：未用网页试听作游戏内证据；点击/确认的音色轻重、与 BGM 的主观混合效果及手机实机由用户确认。

## 实际操作与触发位置

| 操作 | 单次声音 | 实际接入位置 |
|---|---|---|
| 主页/商店设置入口 | ui_click_01 | AppView.OpenSettings：通过原有拦截且弹窗此前未打开，Open 后播放；重复打开静音。 |
| 提示 | ui_click_01 | AppView 的 toggleHomeHints 回调：可交互的主页中 HintsVisible 实际改变后。每次真正切换都计为一次操作。 |
| 结束当天、商店、结果/试做/案件等普通面板入口 | ui_click_01 | AppView.renderPanel：消费明确用户打开标记，只在该面板实际建立时播放。刷新、恢复和拦截不携带标记。 |
| 取消结束当天、普通面板关闭 | ui_click_01 | AppView.Close：面板确实离开时播放；正式跨天使用 Close(true) 避免叠加。专属物件面板不在普通面板名单。 |
| 确认结束当天 | ui_confirm | Panels.Day：NextDay 返回成功后、关闭面板前。accepted 与当前面板保护旧回调；失败/禁用/取消不播放。 |
| 原料与家具购买 | ui_confirm | ShopView 的 buy_* 回调：Buy / BuyFurniture 返回成功，且不是 alreadyPurchased 的幂等回放；不在业务层重复播声。 |
| 船票购买确认窗口 | ui_click_01 | ShopView 的票务报价核对成功、ticketConfirm 从 false 变 true 时。 |
| 船票取消/返回 | ui_click_01 | TravelTicketView.cancel：确认窗口仍打开时执行一次关闭。 |
| 船票最终购买 | ui_confirm | TravelTicketView：Purchase 成功且 departed / ending 返回有效后；accepted 防止同一确认重复播放。 |
| 商店分类、商品选择、翻页 | ui_click_01 | ShopView 各回调实际改变所选分类/商品/页码后；同目标重复回调不额外播声。 |

资源分别为 `audio/sfx/ui/ui_click_01.wav`、`audio/sfx/ui/ui_confirm.wav`。共享 ObjectSounds 的 SoundSource 池和 SoundSettings；没有给通用按钮构造器增加默认音效，也没有修改音乐资源/音量/循环/场景判定。合法的连续原料购买每一笔成功各响一次；售罄、余额不足、写盘失败和已购买报价不播放确认。开窗点击与后续最终确认是两个独立操作，每次各使用一种声音。
