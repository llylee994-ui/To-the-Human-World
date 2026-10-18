"""Daily rewind checks with real modules, isolated files and the headless UI host."""
import sys

sys.dont_write_bytecode = True
from content_test_runtime import run


def main():
    return run('debug.RewindTest')


if __name__ == '__main__':
    raise SystemExit(main())
