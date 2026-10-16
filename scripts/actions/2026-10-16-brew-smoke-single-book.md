# 烟雾减速与记录书复用

用户要求：烟雾慢一些；修复熬制后重复记录书、需关闭两次。

## 实现
- BrewSmoke：约 0.7 秒铺满，1.65 秒打开后续，0.65 秒散雾，总计约 2.3 秒；云团和金光漂移同步放慢。BrewInteraction 从演出配置读取时长。
- AppView.Open：炼药场景打开 journal 时调用 BrewView.OpenJournal，复用锅旁侧栏，清除结果弹层；主页记录书沿用原路径。
- 修正锅旁控件标识：同时设置 Widget.id 与 props.id，避免原生 FindById 仍返回旧的 closePanel 名称。

## 验证
- 先复现回归失败：旧速度不符合较慢时间；单独调速后，schema 4 发货后「只保留一本」断言失败；修复后 113 项通过。
- 记录书 69 项回归通过。
- 本地 session 1ae6bc5b-d8b1-4eac-888c-6545796f0a4b / reload 12 原生事件验收通过：发货后只有一本、历史后续可打开、点一次关闭后无 bookArtFrame；玩家原存档不变。已读取引擎截图。证据位于 docs/验证/evidence/brew-single-book-r1/。
- 演出减速使用控制器时间及连续覆盖率回归验证；本轮原生事件验收直接生成待处理结果，不冒充实际观看过完整减速演出。
- LSP 无新增 Error，保留既有 LetterDrawerTest 的 title/senderName 两项。
- 不修改业务/剧情，不提交或远端构建；验收开关恢复 false 后刷新正常预览。
