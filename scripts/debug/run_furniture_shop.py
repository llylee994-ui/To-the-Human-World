"""Real furniture transactions with committed story data and isolated file media."""
import argparse
import sys
sys.dont_write_bytecode = True
from content_test_runtime import run

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content-ref', default='ea4eb75')
    args = parser.parse_args()
    raise SystemExit(run('debug.FurnitureShopTest', args.content_ref))
