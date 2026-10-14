# 真机反馈落实：玩家入口与触屏词卡

## 状态与情况

In Progress：移动交互实现及后台回归已完成；最终并排药槽的窗口走查与手机验收待完成。2026-10-10剪词失败补修及双端交付转入[修复与交付记录](2026-10-10-preview-lock-and-letter-scroll.md)，以下未提交状态保留为10月9日历史事实。用户要求同步最新代码并优先完成手机可操作前端，落实横屏、开发面板、剪词空白、直接点卡投料反馈。手机验收未通过，存档恢复未完成，不能沿用桌面通过结论。

起点 fengyycon@758e5c1。Maker main 最新5c39738已包含GitHub main 6c4f521；仅入站 project.json、开发日志、真机反馈记录。工作区有其他窗口继续制作的素材和设计记录，全部保留。本机旧真机记录与远端同名，先备份本机版本再快进采用最新用户反馈，不覆盖丢失历史。

已确认交互：第一张主词，后续辅词；点击药槽词卡取出；主词取出保留辅词原位，下一张优先补主词，主词空着禁止炼药。选择与取出只编辑配方，沿用基准、待确认、重置与保存后结算事务。

## 实施措施

1. 安全快进，同步读取新验收记录；由用户向项目拥有者转达官方应用955210方向核查，不擅改登记或换绑应用。
2. 正常入口不挂载开发面板／B1/B2按钮；显式开发入口才启用验收工具，面板自身提供触屏关闭。
3. 信纸剪词位置保留空白／剪痕，不出现“缺口”；保持阅读位置，检验长文与底部操作可达。
4. 炼药显示具体来源词卡、主辅药槽；直接点卡加入、点槽取出，处理满槽与待确认锁定，显示既有属性结果。
5. 完成适合触屏的玩家界面与安全区布局，沿用数据驱动内容；未定稿的美术／排版成果不擅自覆盖或绑定。
6. 验证正常入口、开发关闭、卡片选择及幂等回归，实际窗口操作长信与投料。官方方向与手机P/R/C恢复仍需拥有者和用户实机证据，代码完成不代表手机通过。

## 影响文件树

- `scripts/main.lua`：玩家／显式开发入口与安全区。
- `scripts/debug/DebugPanel.lua`：触屏关闭；现有隔离测试入口继续保留。
- `scripts/ui/PlayModel.lua`：自动分配主辅槽、按来源取出，调用现有事务接口；`PlayView.lua`：点卡交互、并排药槽、信纸局部刷新及固定底部导航。
- `scripts/debug/DeveloperMode.lua`：默认关闭的显式开发入口开关；B1/B2/B6专用请求仍启用开发模式。
- `scripts/debug/MobileFrontendTest.lua`：正常入口、新词卡按钮、重置/恢复/确认和保存失败回归。
- `scripts/debug/PlayFlowTest.lua`：原B6按钮流程适配单击词卡和点击药槽。
- `scripts/debug/run_b1.py`：测试显式选择开发或玩家入口；`fixtures/HeadlessUI.lua`：补齐GetRoot替身。替身不作布局验收。
- `scripts/actions/2026-10-09-mobile-device-validation.md`：同步远端最新反馈并追加本轮实际结果。
- 本记录：实施与方向协同记录；`.tmp/mobile-frontend-20261009/`、`logs/`：忽略的备份及验证证据。

## 自验证方法

完整Lua LSP；v02现有补货、入口与订单回归；新交互验证同来源不可重复投入、满槽拒绝、主词取出保留辅词、空主词不能试做、锁定时不可编辑、失败保存无消耗、确认只扣一次与重置恢复。桌面原生窗口检查信纸长文、剪词锚点、窄屏操作与开发关闭；手机必须另有实测证据。

## 自验证结果

### 后台检查

- `python -X utf8 -B -c "import sys;sys.path.insert(0,'scripts/debug');import run_b1;raise SystemExit(run_b1.main([], 'debug.MobileFrontendTest'))"`：PASS。覆盖玩家入口无开发控件、剪词保留节点、自动主辅槽、重复/满槽拒绝、取主词保留辅词、空主词禁炼药、待确认锁定、保存失败回滚、撤回与恢复、确认后仅扣一次。并排槽修改后重跑通过。日志：`logs/mobile-frontend-test.log`。
- `python -X utf8 -B -c "import sys;sys.path.insert(0,'scripts/debug');from content_test_runtime import run;raise SystemExit(run('debug.PlayFlowTest','3dbca09'))"`：172项按钮检查、104项准备检查，失败0。旧流程依赖3dbca09内容快照；只在内存加载，未改当前内容配置。日志：`logs/mobile-frontend-b6.log`。
- `python -X utf8 -B scripts/debug/run_numeric_v02.py --startup`及`--shop`：PASS。当前v02正常入口保存/恢复、旧slot1保留；补货价格/库存/失败回滚/基准锁。日志：`logs/mobile-frontend-startup.log`、`mobile-frontend-shop.log`。
- 全scripts EmmyLua LSP：0 Error、15个既有测试Warning、1 Hint；`logs/mobile-frontend-lsp/lua_errors.log`及`lua_diagnostics.log`。`git diff --check -- scripts`通过（仅Git换行格式提示）。
- 一次未提升权限的旧B6执行遇到临时目录PermissionError，不能计作整次通过；在可写隔离临时档环境重跑退出码0。故障注入测试中预期SAVE_WRITE_FAILED不视为产品回归失败。

### 已做的实际窗口检查

- 使用已隔离的Maker预览工具`D:/taptap/.mpv/playtest-20261009/dist/maker.js`，未改本机正式CLI。首次因资源索引下载失败没有启动Runtime；重试成功。
- Windows实际客户区412×734：玩家入口无调试/B1/B2按钮；底部五项导航可见；第一封长信可以滚动至剪词/订单按钮，剪词后当前滚动位置保持、按钮变为已剪、正文只留空白剪痕。第二封信可打捞、阅读、剪词和接单。
- 图片证据：`logs/mobile-native-home.png`、`mobile-native-letter.png`、`mobile-native-letter-cut-before.png`、`mobile-native-letter-cut-after.png`、`mobile-native-n01-cuts.png`、`mobile-native-brew.png`。
- 实际窗口发现竖排药槽挤占首屏，随后已改并排槽，并按规则刷新正在运行的预览。**最终并排槽布局尚未目视复验**，不得把此前竖排截图当作最终布局证据。
- 用户反馈前台测试遮挡工作、移动鼠标造成不便，要求转后台。本轮立即停止鼠标/前台切换，并正常关闭本次Runtime窗口；之后仅运行后台检查。剩余原生投料/取出、开发关闭按钮、最终布局及退出恢复走查主动暂停，不自动重启窗口。
- 桌面运行日志仍有既有`Cube/Day/DaySpecularHDR.dds`及`themis_x64.dll`加载错误；已看到UI正常运行，不宣称运行日志全无错误。

### 交付与未完成边界

- 当前分支`fengyycon`快进至`5c39738`，保留其他窗口素材/文档改动。本轮代码未提交、未推送、未远端构建；未更改内容数值、结算系统、存档结构及官方应用方向。
- 用户已确认主词取出保留辅词，下一张补主词；此规则已实现且通过逻辑回归。
- 正式分层美术与排版编辑器成果尚未接入本轮玩家界面，未覆盖队友正在制作的资源。
- 官方竖屏修复仍待拥有者结果；手机长信手势、边缘安全区、触控和P/R/C三个退出点恢复均未复验，原“手机不通过／恢复未完成”结论保持。

## 给项目拥有者的核查说明（由用户转达）

应用955210现有登记为landscape，用户手机也实际横屏，项目目标为portrait。请核查Maker官方应用方向及当前测试版继承方式，确认既有应用纠正方向的官方途径；二维码工具注明方向不可修改，不能靠改本地字符串或重发二维码判断修复。请回传官方处理结果、测试版本及新入口（若更新）。暂不新建／换绑应用，不影响既有项目、账号和存档身份。
