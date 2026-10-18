# 寄往人间 Windows 候选包

| 版本 | 下载 | 大小 | 状态 |
| --- | --- | --- | --- |
| 2026-10-18 / e4621ef / dependencyfix | [Windows x64 ZIP](2026-10-18-e4621ef/ToTheHumanWorld-Windows-x64-e4621ef-dependencyfix-candidate.zip) | 328,180,438 字节，约 313 MiB | 本机独立启动与存档回归通过 |

ZIP 由 Git LFS 管理。GitHub 文件页面可下载原文件；拉取仓库时需要 Git LFS，然后在仓库根目录执行 `git lfs pull --include="packages/windows/**/*.zip"`。不要把只有三行文字的 LFS 指针当成游戏包。无需下载整个源码仓库才能运行游戏。

完整解压后双击 `ToTheHumanWorld/ToTheHumanWorld.exe`，保留 runtime、scripts、assets 的相对位置。运行不需要 Maker、Python 或 Node；启动器使用 Windows .NET Framework 4。

玩家进度和音乐设置位于解压目录的 `ToTheHumanWorld/temp/savedata/unknown/0/`。这里的 temp 含持久存档，不可当作缓存清理。更新或搬迁前关闭游戏并备份该目录，避免用空目录覆盖旧档。

本包源代码为 e4621efe2f22f1d8023d07854503167245a6b25d，加打包时本地默认音量 60% 修改；后续源码变更不会自动进入这个 ZIP。它是本地封装的 Windows 候选包，不是 Maker 官方原生导出产物。

依赖修复：使用原官方引擎包内 64×64 六面低清贴图补齐 DaySpecularHDR.dds 路径；themis_x64.dll 来自 TapTap 官方 TapThemis-Unity 3.2.3-3，签名、AMD64 位数和所需初始化函数已核对。保持原已验证的 20260923-1717-bf3316f Runtime，没有改写引擎二进制。

实际验收：六阶段独立进程存档恢复、待处理结果提交后强制退出、重置后补货、重复发货不重复扣卡扣料或发奖；最终 ZIP 重新解压后 EXE 独立启动及旧候选存档恢复通过。两项原依赖错误不再出现。

尚未验收：另一台电脑、人工画面/听感/完整交互、Themis 崩溃上报服务端结果、平台上传。ZIP 不含玩家存档、测试探针或本地账号配置。

校验和来源见 [manifest.json](2026-10-18-e4621ef/manifest.json)、[SHA256SUMS.txt](2026-10-18-e4621ef/SHA256SUMS.txt)。详细过程见 [运行与依赖验证](../../scripts/actions/2026-10-18-native-package-delivery.md) 和 [GitHub 交付记录](../../scripts/actions/2026-10-18-windows-package-github.md)。
