# 将最新 main 同步到 brewing-bgm

## 状态与情况

- Completed。用户确认目标为 `D:/taptap/To-the-Human-World-bgm` 的 `feat/brewing-bgm`，已从 `6763c29` 快进到 `aaa2108acb3683475e6c17a91a6a9f5a2ff2cc44`。
- GitHub 与 Maker 均已成功 fetch 最新 main，当前同为 `aaa2108`；原仓库路径已不存在，不重建项目，不切换其他 worktree 分支。
- 本地有 MusicSettings 默认音量、SceneMusicTest 以及两份音量说明的未提交修改，全部保留。本轮不提交、推送、构建或主动启动预览。
- 两端首次联合获取长时间无返回，已停止；随后分别获取，禁用交互登录并设 45 秒超时，两端均成功。

## 实施措施

1. 核对 main 为当前分支后继；已确认可快进。
2. 备份四个本地修改文件并记录哈希。仅 SceneMusicTest 与上游重叠，先对该文件做三方合并，成功后再快进并恢复合并结果。
3. 核对未提交内容、最终提交及冲突状态；如测试文件有合并，运行对应背景测试，不将其视为真机验收。

## 影响文件树

```text
scripts/actions/2026-10-18-sync-main-to-brewing-bgm.md  本轮记录
scripts/ui/landscape/tests/SceneMusicTest.lua           合并上游变化和本地音量预期
其余 main 上游变更                                   按 Git 快进拉入，路径清单保存到备份目录
```

## 自检方法

- 比较 HEAD、origin/main、github/main，检查祖先关系与重叠路径。
- 对未重叠本地文件核对 SHA-256；对重叠文件核对三方合并结果。
- 检查未解决冲突、暂存区、差异格式以及对应音频测试。

## 自检结果

- main 涉及 384 个变更路径；四个本地修改路径中仅 SceneMusicTest 重叠。
- 两端 main 和本地 HEAD 同为 `aaa2108acb3683475e6c17a91a6a9f5a2ff2cc44`。本地分支名称未变，比其远端同名分支领先 27 个已有提交，未创建提交、未推送。
- 四个原文件及 SHA-256 清单、上游路径清单和三方合并稿保存在 `D:/taptap/.sync-backups/20261018-brewing-153101/`。三个未重叠文件字节不变；SceneMusicTest 为 git merge-file 无冲突的合并结果，同时保留本地音量断言和上游结局音乐断言。
- GitHub 按需下载缺失对象连接失败；改用已核对为同一提交的 Maker 远端取回测试对象及 437 个缺失对象。首次 PowerShell 对象列表管道格式失败，改为 Python 原始 ASCII 输入后成功；未修改远端配置。
- 第一次快进因重叠文件仍被 Git 判断有本地修改而拒绝，立即恢复备份；确认暂存区为空后仅对该文件同时恢复 HEAD 的索引和工作副本，再执行快进成功，随后恢复已准备的合并稿。
- `git diff --check` 通过；无未解决冲突，暂存区为空。原四项本地改动仍保留，另新增本行动记录。
- `python -X utf8 scripts/ui/landscape/tests/run_scene_music.py`：201 项通过，退出码 0。第一次沙箱执行因隔离临时目录访问被拒绝而失败，正常本机权限重跑成功；不作为玩法保存故障证据。测试中的写入失败、回读失败和缺失音乐为主动注入的检查场景。
- 官方 `taptap-maker preview status --target-dir ... --json` 在同步前后均为 stopped、process_alive=false；未启动或控制窗口。本轮仅验证同步及音频适配器回归，未进行真机或完整游戏验收。
