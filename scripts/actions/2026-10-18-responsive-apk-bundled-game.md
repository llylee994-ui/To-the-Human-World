# 响应式游戏 APK 本地打包

## 状态与情况

- Completed（本地打包与双包交付；手机验收仍未完成）。用户在查看 8 组尺寸及截图后要求「打包成 apk」。本轮已将刚才的本地响应式游戏一并装入 APK，避免安装只含外壳的 v3 后仍加载远端旧 UI。
- 继续使用 `D:/taptap/android-web-test` 隔离 WebView 工程、原包名/签名、原 appassets origin、m_h4x3 项目及访客槽；官方 Web 引擎仍联网，不声称原生独立引擎或离线包。
- 游戏基线 `feat/brewing-bgm` / `9eb6942`。本轮不修改 Lua、配置或美术，不提交/推送/Maker 构建，不控制前台窗口。仅把已检查的响应式 UI 差异纳入快照；他人未提交 MusicSettings/SceneMusicTest 代码保留在工作区，快照使用其 HEAD 版本。
- 先前 v3 包只有宿主，未内置 Lua；本轮以更高版本覆盖安装，不卸载或清除数据。存储地址保持是兼容条件，不等于手机退出恢复已通过。
- 用户追加要求同时输出上一版与本版用于比较尺寸。保留原始 v2 沉浸式 APK，另交付 v4 内置响应式游戏 APK；两包同名同签，旧包读取远端游戏，不能声称是完全固定内容的 A/B 实验。

## 实施措施

1. 生成固定的本地游戏快照：沿用已验证的官方 manifest 结构，更新本地资源 CRC 与索引，记录 SHA-256 和源码来源；不纳入凭证、工作区缓存、存档或后台探针。
2. 在 Android `shouldInterceptRequest` 中仅为本项目的已索引 HTTPS 资源提供 APK 内资源，其余官方引擎地址继续正常联网。不修改引擎、白名单、登录或游戏保存实现。
3. 增加版本号，构建并核对 Java/DEX、签名、zipalign、ZIP 内容、资源索引、原存储 origin 和来源哈希。
4. 用独立后台浏览器从实际 APK 读取相同内置内容，验证官方引擎进入本地响应式界面；与 Android 真机验收分开记录。

## 实际影响文件树

```text
scripts/actions/2026-10-18-responsive-apk-bundled-game.md  本记录
D:/taptap/android-web-test/
  package_game.py                  新增，固定游戏快照与 CRC/哈希清单
  src/cn/tothehumanworld/webtest/BundledGame.java  新增，精确资源路由与 APK assets 读取
  src/cn/tothehumanworld/webtest/MainActivity.java 接入资源路由、说明与构建标识
  AndroidManifest.xml             更高版本
  build.py                        纳入游戏快照并输出真实回执
  probe_packaged_apk.py            新增，从交付 APK 读取资源，无探针注入
  README.md                       更新打包边界和交付结果
  build/20261018T153630Z/          最终独立构建、快照、签名与审计
  evidence/responsive-reference/game-{project,engine}.json  官方公开启动元数据
  evidence/apk-content-20261018-233751/  旧缓存升级/新包启动/重开证据
D:/taptap/download/APK-尺寸对比-20261018/
  寄往人间-A-修改尺寸前-v2.apk      原版沉浸式包，二进制未改
  寄往人间-B-响应式调整后-v4.apk    新版内置当前游戏，沿用原签名
  对比说明.md                      安装顺序、版本来源与验收边界
```

同时更新上一轮 `2026-10-18-game-responsive-layout.md`：其“本地 Lua 必须发布才可在 APK 测试”的限制仅适用 v3，v4 已内置，不再要求本次远端发布。游戏源码、资源、配置均未在本轮改动。

## 自检方法

- 官方 Android 本地 Web 内容文档：<https://developer.android.com/develop/ui/views/layout/webapps/load-local-content>；只拦截精确本项目路径，未知资源不回退成旧游戏。
- 快照与 APK 每项 CRC/SHA-256 检查，确认当前 main、Responsive、HostViewport 和 BrewView 的实际代码入包；无探针和私钥。
- Java/DEX 编译、apksigner verify、zipalign、aapt badging，确认版本递增及签名/包名不变。
- 独立无头 Chrome 加载 APK 中的快照，检查真实引擎启动、响应式就绪、关键页面及错误日志；不替代 WebView/手机验收。
- 沿用上一轮未改 Lua 的检查证据，详细见 `2026-10-18-game-responsive-layout.md`；本轮不声称修复 4 项既有回归失败。

## 自检结果

### 成功证据

- `python -X utf8 -B build.py` 最终成功：`build/20261018T153630Z/`，Java/DEX 编译、APK 签名 v2/v3、zipalign、aapt 版本核对通过；VersionCode 4 / `0.4-responsive-bundled`。
- 包名仍为 `cn.tothehumanworld.webtest`；签名 SHA-256 `dbaff71f2d68373b5e545a5e8a5ab493f5ccb5fc5288fbebf2a0d3ac1446b842`，与 v2 一致。
- `package-audit.json` 全部 14 项通过：ZIP CRC；全部索引资源 SHA-256/CRC；main 的 DPR、HostViewport 就绪协议、BrewView 最终数量标签确实入包；无本轮探针注入/私钥/测试二维码/Python及编辑器文件；原启动配置和 origin 一致；他人未提交音乐逻辑未混入。
- 477 项游戏文件，快照 `36a10d9ba6b641ac595169160ea1ff61f42c500fcd4c8c61b6535fff1cde6db8`，逐文件来源/哈希见 `game-snapshot.json`。保留工程原有 Lua 测试模块依赖及关闭的开发开关，未把本轮后台探针插入 main。
- `python -X utf8 -B probe_packaged_apk.py D:/taptap/download/ToTheHumanWorld-online-test-v4-20261018T153630Z.apk --upgrade` 通过。独立 Chrome 资料先运行 HEAD 基线，再在相同 origin/项目/资料中切换到实际 APK 资源，最后重开；三次启动、两次响应式就绪，游戏资源无缺失。当前包内容直接从 ZIP 读取，不改包内 Lua；基线在测试目录从 HEAD 生成。查看实际主页渲染已确认新布局。
- 上述只证明后台 Chromium 的资源加载、缓存切换和重开，不是 Android WebView 或手机同槽退出恢复验收；没有操控前台鼠标或用户窗口。
- `git diff --check` 通过；本轮没有修改 Lua，所以沿用上一轮静态 0 Error 及相关测试结果，不重复宣称修复既有 4 项失败。

### 双包交付

| 文件 | 大小（字节） | SHA-256 |
|---|---:|---|
| A：修改尺寸前 v2 | 1,060,074 | `9ac8e89ec1471970b0988833be2e498a775fe27743e4a368d20ad6e60ec64590` |
| B：响应式 v4 | 234,397,435 | `3e59f889a838ef3c3393444e2a8bfe0201797fb0bdfa7bc242a5de965a209f0b` |

两份位于 `D:/taptap/download/APK-尺寸对比-20261018/`，复制后哈希复核一致。A 来自原始 `build/20261018T132836Z/`，没有重编或篡改；其历史回执 web_origin 写成远端入口，本轮已从两包实际 classes.dex 核对实际本地存储 origin 均为 appassets，不据历史字段误认换档。

建议先 A 后 B 覆盖安装；不卸载/清数据。旧包联网读取远端内容、新包固定当前内容，无法承诺完全固定同一内容版本的 A/B 对比。若已安装更高版本，不通过清档强行降级。手机触控、长信滚动、边缘安全区、翻转、退出恢复与重复结算未完成验收。

### 过程中失败与处理

- 第一份 v4 候选的后台实际 APK 启动失败：缺少 `project.json` 和版本目录下的引擎描述。已为官方元数据和版本目录路由补齐索引，并移除不需要的 test_qrcode；失败候选不交付。
- 签名重建时 D 盘仅剩不足 1 MB，apksigner 因磁盘不足失败。核对绝对路径后仅删除本轮三个 v4 构建目录中的 base/unsigned/aligned 重复 APK 和失败签名文件，保留已签名候选、旧包、源码、快照及日志；构建脚本改为逐阶段释放可再生成中间 APK。

未提交、推送或执行 Maker 远端构建；本轮打包不需要这些操作。手机验收由双包实测继续。

## 追加：平台上传 upload_error（原因未定位）

- 用户确认失败文件为 B 响应式 v4（约 234 MB），上传一段时间后出现 `upload_error`；截图没有 HTTP 状态码、响应正文或平台拒绝原因。APK 打包完成不等于平台上传/审核通过。
- 排查范围：先验证原交付文件完整性、官方上传要求和单变量重试条件；不改游戏、签名或包名，不盲目重打包，不替用户提交审核。本节先登记排查，再更新下载说明。
- 重新计算 B 文件 SHA-256，与最终构建的 `3e59f889...209f0b` 一致；ZIP `testzip()` 返回 None，无损坏成员。签名检查沿用本轮构建成功记录，不能据此证明平台认可包体。
- 官方 API 文档 `https://developer.taptap.cn/docs/sdk/apk-upload/guide/` 明确 file_name 为 `.apk`，主体只允许字母、数字、下划线、中横线。中文对比文件名不符合这一 API 约束；尚未确认截图网页是否执行同一规则，因此不能定为根因。
- 已有 `D:/taptap/download/ToTheHumanWorld-online-test-v4-20261018T153630Z.apk` 满足英文命名约束，与中文 B 文件大小/哈希完全一致，可作为只改变文件名的重试输入。未重新编译，未改变 APK 内容。
- 用户随后明确「排除中文问题」：按文件名原因已排除继续排查，不再要求重复改名；尚未收到该次失败请求的响应证据，不把此前命名约束当作根因。
- 本地没有该次上传的认证会话/网络响应，无法在代理端复现平台 `upload_error`；诊断停留在反馈收集。下一步收集浏览器 Network 中失败请求的 HTTP 状态码和 Response 错误文字；若显示 `(failed)`，收集对应 `net::ERR_...`。不提供 Cookie、Authorization、上传签名或 Server Secret。收到实际错误前不继续凭猜测更换包名、签名或重编 APK。
- 状态：本地包完整性确认；网页上传仍未验证通过，原因未定位。当前包仍是已说明的 WebView 测试包，未声称满足平台正式审核条件。
