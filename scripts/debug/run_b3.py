"""B3 pure calculation checks using the existing isolated Lua 5.4 runner."""
import sys
sys.dont_write_bytecode = True
from run_b1 import main as run_isolated

if __name__ == "__main__":
    raise SystemExit(run_isolated([], "debug.PotionTest"))
