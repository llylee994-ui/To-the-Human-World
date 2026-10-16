# 后续收录与报酬魔法拖尾

用户要求：熬制出现新后续时，魔法拖尾飞向右边记录书，关闭时自动展开；确认发货成功后，金色拖尾飞到金币栏，抵达后金额增加。

- [x] FeedbackMotion：纯演出时间、曲线路径、事务去重和显示金额，不写业务。
- [x] BrewFeedback：绑定视图的成功 Preview/Resolve；新分支/重复试做分开提示，烟雾消退后复用锅旁记录书；真实报酬差额驱动飞行和数额动画。
- [x] AppView：全局无交互特效层、每帧更新、显示金额投影、导航/异常帧取消后立即同步真实数额。
- [x] 先红后绿回归：失败不反馈、重复不反馈、金额抵达前后、关闭书自动展开、动画不写存档、取消后金额一致。
- [x] 活跃本地预览原生事件和截图验证，恢复正常开关。禁止业务和剧情目录改动。

## 验证记录

- 炼药回归 171 项、记录书回归 69 项通过；git diff --check 通过。业务、剧情、PlayModel 与 main 无差异。
- LSP 无新增 Error；仍有既有 LetterDrawerTest.lua 的 title / senderName 两项。
- 活跃本地预览 session 2cf84817-8e59-49ea-be13-928de2c102ee / reload 4：ReadingNative PASS。内存 fixture 使用真实 UI 指针与滚轮路由、真实 Yoga 几何和引擎窗口截图；原始玩家状态不变。这不是操作系统鼠标或手机实机证据。
- 已读取 1450×815 的 record_arrived / reward_trail / reward_settled 截图：关书后自动展开、紫色抵达提示、金色飞行期间旧余额 30、抵达后余额 130；单记录书一次关闭。
- 截图和日志保存在 docs/验证/evidence/brew-feedback-r1/。首轮快照检查因截图阻塞导致墙钟领先动画时间，已改为等待控制器时间；第二轮通过。
- readingProbe 已恢复 false，reload 5 为正常玩家入口。已知引擎 DaySpecularHDR.dds / themis_x64.dll 两项仍在，因此不声称 Maker 整体 check 通过。未提交、未推送、未远端构建。
