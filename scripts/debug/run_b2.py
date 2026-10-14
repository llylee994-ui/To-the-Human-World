"""B2 Lua 5.4 isolated checks; reuse B1 File/UI adapters, no rendering evidence."""
import argparse
import sys
sys.dont_write_bytecode = True
from run_b1 import main as run_isolated

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--letter-only", action="store_true")
    args = parser.parse_args()
    raise SystemExit(run_isolated([], "debug.LetterTest" if args.letter_only else "RunB2Checks"))
