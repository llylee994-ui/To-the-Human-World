"""Actual v02 runtime flows with isolated File/UI adapters; not a window test."""
import sys
import argparse
sys.dont_write_bytecode = True
from content_test_runtime import run

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--shop',action='store_true')
    p.add_argument('--flows',action='store_true')
    p.add_argument('--startup',action='store_true')
    args=p.parse_args()
    if args.startup:
        import run_b1
        raise SystemExit(run_b1.main(['--numeric-v02-startup']))
    module='debug.NumericV02ShopTest' if args.shop else 'debug.NumericV02FlowTest' if args.flows else 'debug.NumericV02RuntimeTest'
    raise SystemExit(run(module))
