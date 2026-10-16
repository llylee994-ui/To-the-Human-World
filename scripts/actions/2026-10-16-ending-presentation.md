# 三结局尾声、愿望拼贴与标题首页

## 状态与情况

- 状态：Completed（本轮本地实现、专项验证及预览卡顿修复；手机／真人体验与进一步流畅性优化见下方限制）。用户确认后要求“可以继续”，后续要求排查预览卡死、测试船票出走结局；工作区 `D:\taptap\To-the-Human-World-endings`，分支 `feat/ending-flow`。
- 最新确认优先：全部 11 封成功发货后结束当天，由后台自动分流；达标直接走商人来信／学徒结局，不展示条件清单、计数、缺项或二选一。否则走特殊漂流瓶／愿望拼贴。不增加第 12 天，不接主线。
- 船票确认购买并成功保存后演出启程；三个结局显示正文后返回标题首页。标题页支持开始／继续、当前结局回顾、回到结局前、结局留念、开始新旅程。新旅程保留已达成结局和拼贴留念。
- 复用现有批准的 `data.release_endings` 正文、纸张与海边素材；本轮不改人物、信件订单、数值、主线数据，不提交／推送／远端构建。保留工作区所有既有改动。
- 既有 schema 4 只有五项 chapter 字段；愿望只有词 ID 顺序，标题页尚不存在，新周目原先覆盖结局。需兼容旧档，并让新步骤和拼贴落盘后才推进表现。

## 实施措施

1. 以兼容的可选 chapter 字段保存尾声步骤、愿望布局、开局标记和结局留念；后台决定路线，拒绝跨步骤或反向选路。继续使用 GameState 的完整候选校验及提交协议。
2. 特殊漂流瓶是一次尾声事件，不调用普通接单／扣打捞次数；持久化步骤支持重进。学徒信读完后直接保存结局，无接受／拒绝。
3. 愿望用真实已获得词样本，包含已消耗样本；拖拽、轻吸附、旋转、移除、撤销、预览／封瓶。布局和正文来源一起验证，失败不假装保存成功。
4. 衔接日历收起、清晨、商人信或海边特殊瓶；船票／愿望完成后短演出与正文统一返回标题。开发操作、资格统计不进入玩家页面。
5. 新增标题首页与冻结结局回顾；当前进度、旧结局留念分别呈现。新游戏需明确确认覆盖当前经营进度，留念同次提交保留；回到结局前也保留已达成留念。
6. 真业务＋内存介质验证自动路由、步骤恢复、布局、错误重试、旧档和跨周目留念；运行 LSP 和原生窗口专项，记录检查层次。

## 实际影响文件树

```text
scripts/systems/
  WishCollage.lua                         布局／来源校验与阅读顺序
  JourneyRecord.lua                       冻结结局留念与回顾数据
  ReleaseEndings.lua                      冻结拼贴与自动路线约束
  ReleaseCoordinator.lua                 尾声步骤、开局、拼贴与新周目命令
  ReleaseChapterAudit.lua                 新可选字段／旧档／完整检查点校验
  PlayQueries.lua                        只读标题／尾声查询
  OrderTrial.lua                         完整历史审计结果按精确值复用，检查点单独复用
  WordToken.lua                          同次校验内每封信只解析一次
scripts/core/
  SaveSchema.lua                         schema 4 兼容扩展字段
  GameState.lua                          命令装配，去掉重复整档审计，保留模块恢复校验
  ValidationMemo.lua                     有界完整值缓存；进度或配置变化立即失效
  SaveJson.lua                           原格式不变，字符串扫描跳过普通文本
  SaveSystem.lua                         原 B1 校验和四字节展开，双快照提交协议不变
scripts/ui/
  PlayModel.lua                          公开命令桥接
  landscape/AppView.lua                  标题／尾声生命周期和输入边界
  landscape/ReleaseClosingView.lua       商人来信或特殊瓶流程
  landscape/WishView.lua                 纸上拼贴与预览
  landscape/EndingView.lua               三类结局演出／正文
  landscape/TitleView.lua                首页、回顾和新旅程确认
  landscape/JourneyArt.lua               复用现有美术的尾声绘制与布局
  landscape/WishPaper.lua                编辑、预览和留念共用纸面及字体尺寸
  landscape/人工验收.md                  实际操作与未验证项
scripts/main.lua                         普通玩家启动到标题首页
scripts/debug/
  EndingPresentationTest.lua             自动分流、保存故障、冻结布局、旧档与跨周目
  EndingPresentationUITest.lua           控件生命周期、拖动、取消、多指与失败重试
  LetterTokenAuditTest.lua               单次关联校验及伪造来源拒绝
  ValidationReuseTest.lua                精确复用、同版本篡改和配置变化拒绝
  SaveLatencyCompatibilityTest.lua       旧摘要逐字节兼容及原存储故障回归
  ReleaseUITest.lua                      当前标题、商人信、拖拽界面的原 UI 回归
  fixtures/ReleaseEndingFixtures.lua     缩小专项场景；完整 11 封另行跑真实路线
  run_release_rules.py                  可重放的隔离验证入口
scripts/前端接入接口手册.md                公开接口变动
scripts/actions/2026-10-16-ending-presentation.md 本记录
```

新增 Lua 配套 `.meta`。临时工具／验证日志保存在忽略目录 `.tmp/ending-presentation/`；引擎参考只读。

## 自检方法

- 真实 schema 4 与内存存档：满足／不满足学徒条件自动路由、未完成不能进入、跨步骤／重复确认拒绝、尾声与愿望重读恢复、纸面位置／顺序／角度、保存失败和不确定提交、历史结局兼容、新周目与回溯保留留念。
- 控件与实际引擎输入：隐藏全部条件与分支选择；标题继续准确恢复步骤；拖拽释放提交一次，失败留原位置；画布外释放、重复指针、取消、缩放和安全区。
- EmmyLua Error=0；适当回归原有日历与船票／发货规则；检查最终差异。
- 原生预览状态 → 按已授权流程刷新／启动 → 日志／截图／交互；不把适配器测试或进程存活等同于原生／手机验收。

## 自检结果

- 运行 `python -B -X utf8 scripts/debug/run_release_rules.py --suite <suite> --lua-deps D:\taptap\To-the-Human-World-bgm\.tmp\b1-python --engine-libs D:\taptap\To-the-Human-World-bgm`：audit 10/10、reuse 4/4、storage 3/3、presentation 12/12、presentation-ui 5/5、ui 11/11、saves 24/24、calendar 10/10、gates 8/8、purchases 7/7 全部通过；route 实际 11 封、8 单三星、家居、自动学徒及愿望、恢复通过；closing 集成通过。日志位于 `.tmp/ending-presentation/final-*.log`。
- 原生第一次验收遇到长停顿，用户确认“未响应”指游戏预览窗口。停掉该预览、恢复入口后，用完全相同的真实 11 封内存存档、不启动窗口重放：NextDay 5.984 秒、推进清晨 8.669 秒、海边 9.135 秒、开瓶 11.576 秒、改布局 11.416 秒。见 `.tmp/ending-presentation/latency-before.json`。
- 排除渲染为这段阻塞的必要条件：无窗口仍复现。边界计数显示单次操作反复进行约 9,800 次整批信件校验；每个词来源又复查整批信，同一历史和结束前检查点在命令／候选／恢复入口重复审计。修复该重复工作；缓存只接受完整输入和配置完全一致，所有变更和伪造仍走完整审计。来源关联及缓存专项先失败、修复后通过。
- 同一无窗口重放降至约 0.7～1.2 秒；自定的 500ms 流畅性目标仍未通过，保留失败记录 `.tmp/ending-presentation/latency-latest.json`，不以此声称零卡顿。尝试改通用复制函数未得到明确收益，已撤回，`StateUtil.lua` 未修改。
- 修复后原生 session `72395fd8-0f5c-4069-9d94-64c127617ed4` reload 1：34 步完成日历收起、特殊瓶、三个词、实际 Yoga 布局／引擎指针拖动、旋转、预览、封瓶、留念回顾、回溯、购买家居、自动商人信及学徒结局。日志 PASS，断言玩家会话完全未变。单步（部分含截图）最高 1.187 秒；写入操作约 0.6～1.1 秒，未复现原先 8～11 秒阻塞。证据 `native-fixed-first.json`、`native-fixed-rest.json` 及 `ending_native_*.png`。
- 临时原生计时器首次调用与实际引擎绑定不符，产生诊断脚本错误；改用 `os.clock` 并对照日志时间后重新完成验收。不是产品代码错误。一次适配器重跑误用了尚未恢复的原生入口，因此缺少原生鼠标常量；恢复正常入口后该套 5/5 通过。
- 最终 EmmyLua：29 个目标文件 Error=0，Warning=69（包含引擎类型推断／可空和整数注解提示）；`git diff --check` 通过。正常 PlayView 已字节级恢复，SHA256 `7d21836d31e8f31eb54187eb6df0b80c34514355204ba18a9901e5d43f4de02d`；项目源中无临时 `[EndingNative]`／`[DEBUG-...]` 诊断。
- 最后排版修正后的原生 reload 2：再次完成 34 步，纸面前缀和落款可见、四字词不挤行；已查看 `ending_native_wish-arranged.png`。尝试在临时测试里切换为另一会话时调用了不存在的 AppView.Destroy，测试 stage 35 中止；正常入口不包含该调用。改为单独船票专项，未改生产生命周期 API。
- 用户要求船票出走测试：reload 3 的 10 步原生专项 PASS。独立 D1／1000 金币初始条件，实际按钮选船票→购买确认→扣 666 至 334→启程演出→批准的冻结正文→“结束游戏”→标题首页→回到结局前，断言金币回到 1000、经营阶段恢复、真实玩家会话未变。已查看 `ending_native_ticket-ending.png`；日志 `native-ticket-first.json`、`native-ticket-rest.json`。取消、重读、重复确认、保存失败／不确定提交另有 ui／saves 专项通过，不能混称全部都做了系统鼠标人工点击。
- 正常入口已恢复并执行最后正常预览刷新：同 session reload 4，PID 23828／HWND 22157858，1280×720。已实际聚焦、截图并查看普通标题首页 `normal-title-restored.png`，无自动测试流程。手机触摸、系统级连续鼠标拖动、真实玩家存档退出重进及真人整周目体验未完成；原生自动指针检查不替代这些验收。
- 预览仍报告已有引擎资源 `Cube/Day/DaySpecularHDR.dds`／`themis_x64.dll` 警告，官方 `ready` 未成立；它们不能作为本次存档阻塞的已证原因。本轮没有推送、远端构建或 Maker 发布。
