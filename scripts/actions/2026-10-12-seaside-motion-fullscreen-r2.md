# 海边起伏与横屏背景验收

2026-10-12。用户确认背景铺满横屏、功能保留浮层，并明确授权重新启动本地预览。本轮没有使用子代理。

GitHub main 快进 d1b2d06 → 27aaa97（4 个提交）。恢复本地 HUD/捕捞改动时保留远端独立转头实验，所有开发开关默认 false。重叠文件备份在 .tmp/seaside-motion-pull-20261012；恢复 stash 84730c984351dcdef8811c507cbf9be4fd113dac 保留。未提交、推送或远端构建。

船起伏由 ±3 改为 ±18 设计像素，摇摆由 ±0.7° 改为 ±2.2°。待捕捞瓶起伏由 ±3 改为 ±15 像素，增加 ±4° 摇摆与更明显的水波；捕捞轨迹仍由控制器负责，收瓶后停止漂浮。

主页、海边宽屏统一按宽度等比缩放并对齐底部，背景与物件投影一致，裁去顶部部分天空/屋顶；较窄区域保留完整构图并以背景填余边。渲染与命中都受实际区域裁剪约束，物件提示限制在可见区域。外层安全区背景跟随主页/海边，炼药使用纸色底。阅读、商店、记录等继续浮层，主体不拉伸。

回归：SceneProjection 73、HomeHud 50、MessagePresenter/HudLayout 32、SalvageController 2934、SeasideFlow 89、HomeEntry 303、HomeZoom 383、HomeYaw 597，合计 4461 个专项断言通过；不重复计入各 runner 的启动自检。Lua LSP 检查 22 文件，0 Error、72 Warning、13 Hint。相关源码 diff --check 通过，合并冲突已清除。

原生证据位于 docs/验证/evidence/seaside-motion-fullscreen-r2。已读取最终正常比例主页、海边 PNG，并检查最终 20:9 UI 区域截图。九帧船位置相差约 35 设计像素；动态商船命中跟随实际船体；20:9 UI 区域内八个主页入口中心命中正确，玩家进度未改变。20:9 是在普通桌面窗口中改变 UI 区域大小，不能等同于实际 OS 窗口比例或手机验证。参考最终 native-projection-final-logs.json，早期截图/日志方案已淘汰。

最终已恢复全部 DevChecks=false 并刷新到普通玩家入口。预览会话 e94a1a56-533d-4c66-8225-fb74dede88e8，reload 3，运行中。官方 check 仍为 FAIL：原有 Cube/Day/DaySpecularHDR.dds 缺失及 themis_x64.dll 加载失败；不能声称整个运行环境通过。手机测试版本没有重新构建，本轮无真机触控/刘海/平台胶囊验收。
