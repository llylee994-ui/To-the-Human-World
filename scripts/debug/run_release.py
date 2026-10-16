"""Release stage checks using real Lua modules and isolated File/UI adapters."""
import argparse
import sys

sys.dont_write_bytecode = True
from content_test_runtime import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=('schedule', 'startup', 'ingredients', 'economy', 'purchases', 'saves', 'flows', 'endings', 'ending-saves', 'closing', 'ui'), default='schedule')
    args = parser.parse_args()
    if args.suite == 'startup':
        import run_b1
        return run_b1.main(['--release-startup'])
    if args.suite in ('purchases', 'saves'):
        return run('debug.ReleasePurchaseTest' if args.suite == 'purchases' else 'debug.ReleaseSaveTest')
    if args.suite == 'flows':
        return run('debug.ReleaseFlowTest')
    if args.suite in ('endings', 'ending-saves'):
        return run('debug.ReleaseEndingTest' if args.suite == 'endings' else 'debug.ReleaseEndingSaveTest')
    if args.suite == 'closing':
        return run('debug.ReleaseClosingIntegrationTest')
    if args.suite == 'ui':
        return run('debug.ReleaseUITest')
    if args.suite in ('ingredients', 'economy'):
        from pathlib import Path
        def report(raw):
            name = '辅料' if args.suite == 'ingredients' else '经济'
            path = Path(__file__).resolve().parents[2] / f'docs/验证/普通剧情搭配平衡_{name}验算_2026-10-16.json'
            path.write_text(raw + '\n', encoding='utf-8')
        module = 'debug.ReleaseIngredientTest' if args.suite == 'ingredients' else 'debug.ReleaseEconomyTest'
        flag = 'RELEASE_INGREDIENT_REPORT' if args.suite == 'ingredients' else 'RELEASE_ECONOMY_REPORT'
        return run(module, flags={flag: report})
    return run('debug.ReleaseScheduleTest')


if __name__ == '__main__':
    raise SystemExit(main())
