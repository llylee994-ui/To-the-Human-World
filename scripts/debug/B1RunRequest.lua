-- 显式本地验收入口。正常开发必须为 off；write/read/error 只操作 b1_* 专用槽。
-- write: 专项回归并写重启夹具；退出重进后 read: 读取同一夹具；error: 显示坏档门禁。
-- 禁止用该开关运行默认 slot1 的故障注入。
return "off"
