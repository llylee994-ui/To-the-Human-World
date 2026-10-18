# 新手引导三轮复验与本地启动 · 2026-10-18

本轮结论：上一轮三项 P2 的修复已通过后台复验，未发现新的基本流程阻断；本地预览已按用户要求重新启动并加载游戏。未操作桌面、玩家存档或手机，不据此宣称遮罩观感和手机触控已验收。

## 本轮复验与修正

- 手动阅读：正常捕捞后停在海边阅读入口；恢复 sea.read 时可进入来信抽屉，信件在点击前保持未读。独立探针输出 panel=letters、step=sea.read；点击入口后才进入 reader。
- 投词/投料：accepted flight 存在时保持 brew.word / brew.ingredient；飞行结束后才推进，DraftChanged 不再成为提前推进旁路。
- 暂停：设置、失焦、最小化和竖屏均隐藏并暂停引导；设置内帮助便签可重读，收起后仍保持暂停，关闭设置后才恢复。
- 回溯及返回回溯前、真实 EventBus、断点续玩、结果重新调配和跳过、销毁监听清理继续通过。
- 本轮仅另行清理了 Onboarding.lua 中提示高度读取 props.visible 导致的新增 EmmyLua undefined-field：改为复用与显示按钮相同的 showKnow 布尔值，不改变显示逻辑。

## 新鲜验证

| 项目 | 结果 |
|---|---|
| run_onboarding.py | 所有引导专项通过，exit 0 |
| run_release.py --suite saves | 26/26，exit 0 |
| run_release.py --suite ui | 通过，exit 0 |
| run_rewind.py | 14/14，exit 0 |
| run_preload.py | catalog/loader/entry/navigation 全部通过，exit 0 |
| 前两轮独立探针、standards2 | 回溯、总线、恢复、手动阅读、飞行门禁、暂停与帮助重读通过 |
| Maker Lua LSP | 本次 10 个相关 Lua 文件无 Error；全工程仍有 20 条既有类型诊断 |
| git diff --check | 通过（仅 CRLF 提示） |

## 本地预览证据

- 使用已安装 Maker 0.0.36 的 preview start 启动；随后相关修改批次执行 status，确认 live 后 refresh。
- session_id：c89d602e-4763-47fd-9e08-e11f576f28bc；最终 reload_id：1。
- Runtime 进程存活，当前轮日志已加载 ui/landscape/Onboarding.lua，2026-10-18 18:27:37（Asia/Shanghai）记录“寄往人间 启动完成（第 1 天）”。
- 启动期间等待了引擎公共包下载；没有改服务环境、下载配置或缓存。
- preview check 仍因已有 Cube/Day/DaySpecularHDR.dds、themis_x64.dll 两条引擎环境错误返回 FAIL；不能写成官方检查全绿。当前轮另有 ScrollView Zero height 警告，未据此断言实际可见便签布局失败；仍需原生画面/手机触控确认。
- 过程证据：本地 .tmp/onboarding-preview-start.json、onboarding-preview-refresh.json、onboarding-preview-check.json；不作为远端 watcher 日志。

用户已确认沿用 TapTap 二维码，提交并远端构建最新版。当前后台验收结果作为本轮提交依据；构建及二维码以实际工具返回为准，手机画面和触控仍待扫码实测。
