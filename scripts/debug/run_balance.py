"""Regression for single-main shortcuts using real Lua modules and isolated storage."""
import json
from pathlib import Path
from content_test_runtime import run

if __name__ == '__main__':
    target=Path(__file__).resolve().parents[2]/'.tmp/balance'
    target.mkdir(parents=True,exist_ok=True)
    def publish(raw):
        (target/'shortcut-check.json').write_text(raw,encoding='utf-8')
    flags={'BALANCE_REPORT':publish}
    economic=target.parents[1]/'docs/验证/普通剧情搭配平衡_经济验算_2026-10-16.json'
    if economic.exists():
        raw=economic.read_text(encoding='utf-8')
        evidence=json.loads(raw)
        if evidence.get('status')=='passed' and len(evidence.get('routes',[]))==4:
            flags['BALANCE_ECONOMY_JSON']=raw
    raise SystemExit(run('debug.BalanceTest',flags=flags))
