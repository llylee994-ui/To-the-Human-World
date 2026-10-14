"""Single-use semantics plus formal W01 gate. --technical excludes only W01."""
import argparse
import sys
sys.dont_write_bytecode = True
from content_test_runtime import run

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--technical', action='store_true')
    parser.add_argument('--content-ref', help='Read only committed scripts/data at this ref; does not merge or deploy')
    args = parser.parse_args()
    return run('debug.SingleUseWordTest', args.content_ref, {'SINGLE_USE_TECHNICAL_ONLY': args.technical})

if __name__ == '__main__':
    raise SystemExit(main())
