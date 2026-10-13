# 主会话回传记录

## 2026-10-12 更新（当前有效）

报告与审查包通过同一 Library ID 的 guarded replace 均成功，当前版本均为 **1**（代码成果标签仍为 r3-v01）。没有新建重复 Library 文件。

- REPORT.md：libfile_2b7899edaabc819199c5b25a46bd693c；file_00000000b9588207b493f033981fe2da；10366 字节。
- 审查包：libfile_a96a3b502d5c8191a8fab49a5d70d685；file_00000000374c821196e5fc12e655fbf1；1280957 字节；436 文件；SHA256 `732fb98b5a938eb1ae80b669378450ac4c136f27e38cdc419eed00a94302c7a9`。
- 原始返回：library-replace-20261012-report.json / library-replace-20261012-review.json。官方 xattr 回写仍因 Windows os.setxattr 不支持而失败；Library 版本 1 创建已获确认，本文件保留准确版本关联。
- 更新内容为独立绑定授权后的实际预检与权限停点，无新游戏代码、测试运行或原生画面。旧报告和旧包归档在 history/2026-10-11-v01。

以下为版本 0 的原始历史记录。

两个文件经 Library 确认创建成功，均为版本 0；现有 ID 后续更新应 replace，不重新 create。

| 本机文件 | Library ID | file_id | 字节数 |
|---|---|---|---|
| `D:\taptap\To-the-Human-World-3D-Lab\REPORT.md` | `libfile_2b7899edaabc819199c5b25a46bd693c` | `file_0000000095a482078b96b67a69cdd6d5` | 9113 |
| `D:\taptap\To-the-Human-World-3D-Lab\deliverables\D3-LAB-20261012-r3-v01-review.zip` | `libfile_a96a3b502d5c8191a8fab49a5d70d685` | `file_0000000071548207aa38475097f13677` | 1270907 |

Library 原始结果：library-direct-result.json。包 SHA256 为 `a15cff201a1e9cbfcd3ee0e062d665b955644c13486a4f9c2c32cbb3afdd0898`；432 文件，含独立代码、报告、证据和 DELIVERY_MANIFEST.json，ZIP CRC 校验通过。

批量官方助手在准备前返回 `Library prepare_uploads is not available`，没有产生上传会话或不明结果。按照技能“prepared tools unavailable”支持分支，改为有序 direct create batch；两个 item 均 succeeded，无重试不明写入。

上传成功后的官方 apply-xattrs 在本机仍不支持 os.setxattr；完整元数据写回日志为 metadata-writeback-0.log / metadata-writeback-1.log。这不撤销已确认的 Library 创建结果，但不能宣称 Windows xattr 已落盘；本文件与原始结果保留本机路径、ID 与版本对应，便于后续受控 replace。

输入附件没有上传；传输签名 URL 临时 JSON 已删除，未打入审查包。交付包不含 Library 助手、凭据或原生运行截图。此处回传记录产生于打包之后，不在包内，不影响包内代码/检查哈希。
