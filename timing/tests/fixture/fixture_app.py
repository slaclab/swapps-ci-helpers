"""Tiny program used to exercise the timing composite actions."""

import sys


def main(argv: list[str]) -> int:
    if "--fail" in argv:
        return 3
    if "--import-check" in argv:
        print("import check ok")
        return 0
    print("hello from fixture_app")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
