# 音乐设置按钮与弹窗

## Status and situation

Completed（功能实现、专项回归与最终桌面弹窗显示核对完成；手机实机未验收）。用户要求先在 `feat/scene-bgm` 本地提交现有有声修复，再开发设置按钮和弹窗；按钮参考“提示”“结束当天”，弹窗可开关音乐和调整音量。前置提交已完成：`0215ea0`，提交前音乐专项 93 项断言通过，工作区干净。用户明确选择“记住上次设置”。开发完成后，用户确认可以并授权提交推送到 GitHub 的 `feat/scene-bgm`；仍不合并 main、不做 Maker 远程构建。

用户在第一版实际窗口中反馈信息过少，要求至少有音符 UI。其截图同时暴露“背景音乐”和音量百分比未显示：行内多行 Label 未提供宽度。本轮补充矢量音符、明确“音乐设置”标题及行内标签宽度，重新核对真实画面。

## Implementation measures

1. 复用 Harbor.Button 木牌与 Harbor.Paper 纸面。顶部按钮区及商店增加设置入口；独立遮罩弹窗保留底下页面、商品选择和曲目，不触发业务导航。
2. 音乐开关与 0–100% 滑杆即时改变单个 BGM 声源增益；开关不抹掉用户音量，不重播当前曲目。默认开启、100%，沿用已确认混音。
3. 用独立本地偏好文件记住开关和音量，复用已核实的引擎 File 存储适配器及 SaveJson。开关、拖动结束和关闭时保存；不改玩法存档或 schema。缺失/损坏设置回退默认，保存失败明确提示当次有效但未保存。
4. 在真实 UI 控件与业务导航基础上验证设置、曲目延续、独立持久化和故障边界；检查可用静态诊断。编辑完成后查询官方预览状态，仅刷新仍运行的窗口，收集日志并交用户试听。

## Affected file tree

- `scripts/core/MusicSettings.lua`：独立音乐偏好及存储，公开读取/设置/保存接口。
- `scripts/ui/landscape/MusicSettingsView.lua`：纸面弹窗、开关、滑杆、百分比与保存反馈。
- `scripts/ui/landscape/SceneMusic.lua`：声源增益更新，不改变场景选曲规则。
- `scripts/ui/landscape/AppView.lua`：装配设置、HUD 入口、遮罩生命周期与安全区。
- `scripts/ui/landscape/ShopView.lua`：商店设置入口。
- `scripts/ui/landscape/tests/SceneMusicTest.lua`：现有真实导航回归增加设置交互、声音状态和存储证据。
- `scripts/debug/fixtures/HeadlessUI.lua`：补齐开关与滑杆适配入口，复用引擎控件实际值/回调方法，不提供渲染验收。
- `docs/actions/2026-10-15-music-settings.md`：本记录。

## Self-verification method

- `python -X utf8 -B scripts/ui/landscape/tests/run_scene_music.py`：真实控件回调、单声源不中断、主页/海边/商店曲目、0/100 音量、关闭后恢复及新实例读回；文件故障适配器不触及玩家存档。
- 商店专项及可用 Lua 静态诊断，`git diff --check`。
- 官方 `preview status`，若存活则 `preview refresh` 后读取该会话 `logs/check`；单独记录既有运行器缺失报错。桌面实际显示、拖动手感、设备听感及手机验收分别报告，不用适配器通过替代。

## Self-verification results

- 开发结束时前置本地提交 `0215ea0` 已完成，只含原有 BGM 无声修复及其记录；设置功能当时尚未提交。随后用户授权 GitHub 提交推送，交付范围见下节。
- `python -X utf8 -B scripts/ui/landscape/tests/run_scene_music.py` 最终 144 项断言通过，包含保存失败、截断写入、坏文件、读错误、0/100 音量、关闭音乐时切换场景、同曲不重播、实际控件值回调与 File 适配器重读。故障日志为测试主动注入。第一次因 HeadlessUI 缺少 Toggle 入口失败，补充实际控件方法适配后通过；不是原生控件缺失。
- `python -X utf8 -B scripts/ui/landscape/tests/run_shop_view.py` 51 项通过；`python -X utf8 -B scripts/ui/landscape/tests/run_home_hud.py` 52 项通过。未运行全量业务/手机验收。
- 本机已安装 EmmyLua 服务检查本轮 7 个 Lua 文件：最终 0 Error、64 Warning，未将警告计为全清零。受限环境首次未返回诊断；在获准本机上下文中成功取得诊断。证据 `.tmp/music-settings-lsp/diagnostics.json`，运行脚本 `.tmp/check_music_settings_lsp.py`。`git diff --check` 通过。
- 按实时 status 确认会话存活后，执行两批代码各一次刷新。最终 session `cb381210-f529-401d-8417-704f97ffcd3c`、reload 2、PID 29516；2026-10-15 19:27:03（Asia/Singapore）日志显示启动完成。新模块已加载，设置弹窗实际点击后未出现 MusicSettings/SceneMusic 错误。
- Windows 定位当前进程、恢复最小化窗口，关闭空来信抽屉并点击设置；没有领取、购买、结束当天或操作玩家进度。实际截图 `.tmp/music-settings-checks/final-settings.png` 已人工查看：矢量音符、“音乐设置”、“背景音乐”、“音乐音量”、62% 均清晰显示，滑杆与关闭按钮完整可见，无多余滚动条。窗口保留在设置页，当前音乐关闭、音量 62%，未替用户更改该偏好。此项为桌面显示证据，不代表手机或完整听感验收。
- 最终 `preview check` 仍因此前存在的 `Cube/Day/DaySpecularHDR.dds` 与 `themis_x64.dll` 缺失报 FAIL；不能将游戏启动或专项通过称为运行器整体通过。
- 偏好使用引擎相对路径本地 File 保存；未新增云同步，未修改玩法 schema 或存档。官方文件存储说明指出 Web 内存文件系统刷新可能丢失，跨 Web 刷新的持久化未在本轮交付范围。

## GitHub delivery

- 用户明确授权将音乐设置提交并推送到 GitHub `feat/scene-bgm`，禁止合并 main。本次推送同时包含前序本地提交 `0215ea0`，确保原生有声修复一起交付。
- 当前 `origin` 已核实指向 `https://github.com/llylee994-ui/To-the-Human-World.git`。提交前远端功能分支为 `ba9b81db4a3e789f118944df2f20f868313cc07d`，main 为 `7f1f6d44b6d9d56166ced231afedac17d217eb3f`。
- 本轮 7 个 Lua 文件逐份 SHA256 与上轮最终诊断记录一致，沿用上述音乐 144、商店 51、HUD 52 项回归以及 0 Error/64 Warning 结果；只更新本记录，不重复启动游戏或重跑未变化的代码检查。
- 仅纳入本记录与上列 7 个 Lua 文件；不纳入本地配置、偏好文件、运行缓存、截图或诊断产物。推送使用明确的 `HEAD:refs/heads/feat/scene-bgm`，完成后单独核对远端功能分支与 main，不以本地提交成功代替推送核实。
