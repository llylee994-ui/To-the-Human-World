"""Real content flows + B5 fault coverage; isolated storage/UI, not engine V13."""
import sys
import argparse
sys.dont_write_bytecode = True
from content_test_runtime import run

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content-ref', help='Read only committed data snapshot; does not merge or deploy')
    parser.add_argument('--single-use-copy', action='store_true', help='TECHNICAL all-word-false copy, not formal W01 acceptance')
    args = parser.parse_args()
    raise SystemExit(run('debug.StoryContentFlowTest', args.content_ref, {'STORY_SINGLE_USE_COPY': args.single_use_copy}))
