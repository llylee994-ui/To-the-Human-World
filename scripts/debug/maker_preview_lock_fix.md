# Maker预览与排版编辑器并行：本机兼容补丁

适用官方Maker **0.0.36**，原bundle SHA256必须为`62deb6cd7adc3975d23ce5750be53116f02ef7b9b5b9d49e5ace44fbbc144652`。这是本机安装补丁，不是Maker官方已发布修复。升级包后先重新核查，脚本遇到不同版本或不同源码会拒绝修改。

原因：本地prepare复制整个scripts，Windows编辑器`.local/.server.lock`被占用时copyFile报EBUSY。补丁只在prepareProjectCopy传入要排除的绝对路径`scripts/layout-editor/.local`，递归时精准跳过。其他文件正常复制，其他锁错误/取消仍会报错，原符号链接检查不变。不会改编辑器数据库、锁机制、预览存档方式、项目身份或屏幕方向。

## 安装、检查与回退

在本项目根目录运行；`$makerBundle`必须是实际使用的已安装`dist/maker.js`，不能指向项目代码或未知版本。MCP配置和全局CLI可能使用不同安装副本，需要分别核查。

```powershell
$makerBundle = 'C:/Users/YOUR_USER/.taptap-maker/mcp-runtime/0.0.36/dist/maker.js'
$backupDir = Join-Path (Get-Location) '.tmp/preview-lock-backup'
python -B scripts/debug/maker_preview_lock_fix.py --bundle $makerBundle --backup-dir $backupDir --mode check
python -B scripts/debug/maker_preview_lock_fix.py --bundle $makerBundle --backup-dir $backupDir --mode apply
# 恢复同一安装原件；备份与当前文件不匹配时拒绝覆盖
python -B scripts/debug/maker_preview_lock_fix.py --bundle $makerBundle --backup-dir $backupDir --mode rollback
```

`apply`先备份、再修改并读回校验，重复执行幂等。保留backup-dir；不把安装包、备份、日志或编辑器.local提交。此修复不需要修改AI客户端配置或重启编辑器；已运行的Maker进程仍是旧内存代码，下一次CLI进程读取补丁。

## 后台验证

```powershell
# 参数指向安装前的原件或备份；提取真实复制函数，使用Windows真实锁
python -B scripts/debug/test_maker_preview_lock_fix.py --original-bundle PATH_TO_ORIGINAL --node PATH_TO_NODE
# 启动无浏览器的独立临时编辑器，运行标准prepare，检查编辑器仍健康；不启动Runtime
python -B scripts/debug/probe_editor_preview.py --bundle $makerBundle --node PATH_TO_NODE
```

实际结果见[修复与交付记录](../actions/2026-10-10-preview-lock-and-letter-scroll.md)。后台prepare通过只证明资源准备阶段不再受编辑器锁影响，不替代手机/原生窗口或持久化验收。
