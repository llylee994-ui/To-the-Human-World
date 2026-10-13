# D3 v03.5 独立接入步骤报告

记录时间：2026-10-13T11:07:16.401014+00:00。唯一任务：`01a12c24-a725-712b-ba7d-df58430f5098`。

## 模块定位

本轮为 Blender v03.5 场景的加载器与 main 业务接口适配骨架，全部写入独立 Lab 的 `v035/`。正式工程、旧 Lab 场景和入口保留。固定 main SHA：`1cd0cdbec06487a5c60f109d5fd477198cfc8846`。

## 已落盘工作

- `v035/scripts/lab35/`: 网格格式/索引/法线/UV/纹理路径校验、Blender→引擎轴转换、CustomGeometry 分块发射与失败回收、PBR 不透明/透明材质适配、语义代理拾取、原生投影函数。
- 八个 main Home ID 的入口映射、导航锁、取消及过期回调防重、只执行一次的跨天确认。商船要求独立语义三角形代理；未提供代理则禁用拾取。
- 只创建一套真实 GameSession/PlayModel；通过 SaveSystem.New 注入 `d3_lab_v035` 独立内存槽，拒绝正式槽且没有磁盘回退。
- 适配版 AppView 使用原 main 面板、SeasideView、SalvageController；HUD绑定真实金币/天数，提示气泡由可见锚点投影。仅替换 Home平面表现/缩放过渡；现成捕捞与读信剪词流程保留。
- 80份 main Lua原件保持哈希一致；5份原main海边资源已获取并记录哈希。它们不是云端3D参考图。

## 为什么现在做

在等待云端小样落到Windows时完成不依赖素材的工程接入和真实业务检查；使素材到位后只需核对实际schema、几何/贴图和原生表现。

## 完成依据

命令：`python -X utf8 tools/check_v035.py`。结果：**102项离线检查通过，97个Lua文件语法编译通过，80份固定main源码哈希一致**。

验证包括：非法索引/稀疏数组/非有限值/坐标溢出/路径逃逸被拒；UV保留、正面绕序和单位换算；引擎API调用顺序替身检查；缺纹理在建场景前失败；透明船卡片角落不命中；遮挡回调拒绝隔墙拾取；导航重复与取消；全部8入口无业务副作用；跨天需确认且重复确认仅推进一天；真实商店购买与失败不扣款；原捕捞仅收信一次、跳过动画后打开真实Reader；重复Cut不复制词卡、重开保留剪口；HUD同步；16:9/宽屏/4:3的布局状态更新；内存存储审计。

证据：`docs/evidence/v035-main-interface/offline-v035.json`、`offline-v035.log`、`runtime-source-manifest.json`、`seaside-resource-manifest.json`。接口说明：`docs/v035-interface-map.md`。断点：`HANDOFF_V035_INDEPENDENT.json`。

## 当前状态与限制

独立步骤完成；完整3D接入仍被资产交付与原生许可阻塞。小样ZIP当前本地存在：False。未本地查看v03.5图像，未加载实际云端小样/完整场景，未启动游戏。本次没有系统输入、正式工程修改、提交或推送。

离线检查使用真实业务模块，但UI控件/布局和引擎API是替身，不能证明GPU渲染、原生触控、画面构图、连续镜头路径、帧率或手机通过。MASK/cutoff材质当前明确拒绝，待验证技术映射；不静默替换成BLEND。Integration要求外部明确提供实际导航路径和遮挡查询，不以空回调或旧模型冒充。

Library官方Windows材料化兼容错误已记录，本轮没有重试或修改helper。云端小样使用manifest.json→probe.json/schema.json和单独proxyMeshes；尚未读取实际内容，需到件后对照，而不是假设已经与加载器完全一致。

## 下一步与待决定

收到小样后先核验 9225580B 和 SHA256 `e782c36e3c5445847a13b1ffbb57dea04321ff40086baac4906bbbb0035a179f`，检查ZIP路径，再解压到 `experiments/3d-lab/assets/import-probe-v035/`，实际查看PNG、棋盘和重建截图，核对schema后适配。6个可见网格与8个语义代理必须分开；小样不等于完整场景。

无需新增用户决定。原生预览许可已由父会话询问，当前未获回复，继续禁止启动。A2可审查上述源码/接口映射/测试证据；本轮结果不代表A2独立审查或最终审美接受。
