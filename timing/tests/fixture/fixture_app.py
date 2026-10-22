"""Tiny program used to exercise the timing composite actions."""

import sys


def main(argv: list[str]) -> int:
    if "--fail" in argv:
        return 3
    if "--expect" in argv:
        # Exits 0 only if the next argument arrives intact, spaces and quotes
        # included.
        received = argv[argv.index("--expect") + 1]
        print(f"received {received!r}")
        return 0 if received == 'say "hi" now' else 4
    if "--import-check" in argv:
        print("import check ok")
        return 0
    print("hello from fixture_app")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
