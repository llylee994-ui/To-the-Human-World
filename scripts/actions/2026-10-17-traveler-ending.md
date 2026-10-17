# 旅人结局展示

用户确认五屏旁白、船上回望背景、减少灯火、底部渐隐黑底暖白字、手动翻页、末屏渐暗与黄铜细线返回按钮。基线 b972242，工作区已有标题、炼药、词条和愿望布局改动，均保留。

## 实际修改

- 新建 DepartureSequence 和 DepartureView。购票保存成功后的 departure 结局与留念回放统一从冻结正文按空行分页。新结局五屏，末屏原样使用用户确认的面包段落；旧存档原文保持。
- 背景采用已确认的无字船上海面图，项目路径 `assets/image/departure-ending-r1/background.png`，1672×941，等比覆盖并缓慢放大。文字与按钮由 UI 绘制，旁白下方渐隐黑底，窄高度长文可滚动。
- 入场淡入 0.65 秒；翻页淡出 0.16 秒、淡入 0.24 秒，稳定后 0.25 秒才接收下一次点击。静置不翻页；拖动、非主触点、淡入中开始的按压不推进；失焦暂停，销毁回调无效。
- 最后一次点击后文字淡出 0.25 秒、场景与音乐渐暗 1.5 秒、落款淡入 0.6 秒，稍后显示“返回首页”。留念回放显示“返回留念”。落款“旅人／人间单程船票”。
- SceneMusic 增加独立演出音量系数，与用户音量相乘并遵守静音，不保存设置。退出演出恢复目的场景音乐。
- EndingView 按 departure 委托新界面；AppView 管理音乐覆盖与销毁。未修改购票事务、扣款或保存规则。
- 同步发行正文与文案文档，调整现有界面检查以实际完成翻页后返回。

## 检查结果

- DepartureViewTest：5/5，包括真实 PointerEvent 的多指、指针所有权、非首个触点释放标志、淡入按压，以及 Widget 取消滚动后仍可继续翻页的回归。
- EndingPresentationUITest：5/5；ReleaseUITest：11/11。
- SceneMusicTest：182 个断言通过，含真实 AppView 购票演出、返回首页、留念回放与返回列表的音乐恢复。音频使用隔离适配器，不代表扬声器验收。
- EndingPresentationTest：12/12；ending-saves：24/24；purchases：7/7。
- 最终 DepartureSequence、DepartureView、EndingView、AppView、SceneMusic 单文件 Lua LSP Error 列表为空；git diff --check 通过。存储和音频失败日志来自故障注入用例。
- 独立复核发现并修复三处问题：引擎 IsPrimaryAction 对副触点也返回 true；留念返回时未恢复目的场景音乐；ScrollView 滚动取消不冒泡导致指针锁未释放。新增回归检查均通过，滚动取消用例在修复前复现失败。
- 相关代码与资源批次后查询官方 preview status，均为 stopped / process_alive=false，未重启。实际游戏窗口排版、图片渲染、手机触控和音乐听感仍待验收。

## 资源与边界

无字背景来自本会话内置 imagegen 已展示且获确认的生成图，游戏只引用项目副本。未使用带字概念拼图作为游戏画面。未改学徒结局或愿望拼贴展示；没有操作真实玩家存档，没有提交、推送或远端构建。
