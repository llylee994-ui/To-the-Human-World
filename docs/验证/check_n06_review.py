"""N06上限比较已撤回；入口改为复验当前主轴达标开放发货方案。"""
from pathlib import Path
import runpy

if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).with_name("check_numeric_candidates.py")), run_name="__main__")
