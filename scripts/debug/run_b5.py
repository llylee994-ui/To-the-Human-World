"""B5 real-module order transactions using isolated Lua 5.4 storage adapters."""
import sys
sys.dont_write_bytecode = True
from run_b1 import main as run_isolated
if __name__ == "__main__":
    raise SystemExit(run_isolated([], "debug.OrderFlowTest"))
