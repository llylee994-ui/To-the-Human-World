# Windows 候选包纳管与 GitHub 交付

## 状态与情况

- In progress。用户明确要求将已完成的 Windows 包移入受管理目录并推送 GitHub。本轮仅交付已验证包及相关清单/说明，不重新打包、不启动游戏、不推送 Maker。
- 工程 `D:/taptap/To-the-Human-World-bgm`，分支 `feat/brewing-bgm`，起点 `e4621efe2f22f1d8023d07854503167245a6b25d`。实际 GitHub 远端为 `https://github.com/llylee994-ui/To-the-Human-World.git`；远端 main 同为 e4621ef，当前远端功能分支为 739896c。
- 既有音乐设置/测试/文档改动及同步记录均保留。索引开始为空，不提交这些既有改动。
- 包体 328,180,438 字节，SHA-256 `a992df7d6c88c00c229da706362389c5b863b451f231e0ea60187838964521bd`。超过普通 GitHub 文件大小限制，使用 Git LFS，规则只作用于 packages/windows 下 ZIP。

## 实施措施

1. 复核最终包校验、ZIP 清单和已完成验收报告；建立版本化包目录与包体专用 LFS 属性。
2. 确认源/目标绝对路径在 D:/taptap 内且目标不存在后，移动唯一指定 ZIP；复核移动后哈希和大小。
3. 写明包的来源、运行方法、存档位置、两项依赖修复、验证边界和获取方式；记录便携清单。
4. 仅暂存本轮明确路径及前一轮包体交付记录，检查实际 LFS 指针、变更清单和敏感信息。提交到当前功能分支，上传该包的 LFS 对象，再推送 GitHub 同名分支。
5. 核对 GitHub 分支 SHA；独立下载远端 LFS 对象校验原包 SHA-256。不得以仅指针推送成功代替包体上传成功。

## 影响文件树

- `packages/windows/.gitattributes`：仅 Windows ZIP 的 LFS 纳管规则。
- `packages/windows/README.md`：版本索引、获取与存档说明。
- `packages/windows/2026-10-18-e4621ef/`：已有最终 ZIP、manifest.json 与 SHA256SUMS.txt；不含测试目录或凭证。
- `scripts/actions/2026-10-18-native-package-delivery.md`：前一轮依赖修复/运行验证证据，补记纳管后的包路径。
- `scripts/actions/2026-10-18-windows-package-github.md`：本次交付过程及实际结果。
- 原 `D:/taptap/output/windows-package-20261018/`：仅最终 dependencyfix ZIP 移出；旧包、测试证据、构建工具和验收副本保留。

## 自检方法

- 移动前后 SHA-256、大小；ZIP CRC 与文件清单、BUILD_INFO 对照。
- `git check-attr`、暂存内容和 LFS 指针检查；仅允许清单路径进入提交，所有已有改动保持。
- `git lfs push` + GitHub 分支推送；远端 SHA 与独立 LFS 下载 SHA-256 核对。
- 仅包体移动与记录，本轮不重复运行已经通过的游戏回归，不操作开发窗口。

## 自检结果

- 已将唯一最终 dependencyfix ZIP 移至上述受管理目录；原路径不再有该 ZIP，旧候选和证据未动。移动前后 SHA-256 与 328,180,438 字节大小完全相同。
- ZIP CRC 通过，448 个文件；无 temp/User/logs/本地绑定/测试探针路径，BUILD_INFO unresolved 为空。
- `git check-attr` 确认仅指定目录的 ZIP 使用 LFS；暂存 ZIP 实际为 3 行指针，OID 等于包 SHA-256；7 个暂存文件均在明确允许范围，`git diff --cached --check` 通过。
- 首次普通权限 `git add` 遇到 Git for Windows `couldn't create signal pipe, Win32 error 5`，未成功暂存；以正常权限重试同一允许清单后成功，没有扩大提交范围。
- 上传与远端完整包下载核验：Pending。
