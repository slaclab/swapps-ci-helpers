# /// script
# requires-python = ">=3.12"
# dependencies = ["pyyaml==6.0.3", "shellcheck-py==0.11.0.1"]
# ///
"""Shellcheck the timing actions' scripts and inline bash steps.

actionlint only checks workflow files, so this covers the composite actions.
It also rejects ${{ }} expressions inside run: blocks; inputs must reach
scripts through env: to avoid script injection.

Usage: uv run timing/tests/lint_actions.py
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

TIMING = Path(__file__).resolve().parent.parent


def main() -> int:
    failed = False
    scripts = sorted(TIMING.glob("*/*.sh"))
    with tempfile.TemporaryDirectory() as tmp:
        for action in sorted(TIMING.glob("*/action.yml")):
            steps = yaml.safe_load(action.read_text())["runs"].get("steps", [])
            for index, step in enumerate(steps):
                script = step.get("run")
                if script is None:
                    continue
                label = f"{action.relative_to(TIMING)} step {index}"
                if "${{" in script:
                    print(f"{label}: use env: instead of ${{{{ }}}} in run:")
                    failed = True
                if step.get("shell") != "bash":
                    continue
                path = Path(tmp) / f"{action.parent.name}-step{index}.sh"
                path.write_text(f"#!/usr/bin/env bash\n# {label}\n{script}")
                scripts.append(path)
        result = subprocess.run(["shellcheck", *map(str, scripts)])
    return 1 if failed or result.returncode else 0


if __name__ == "__main__":
    sys.exit(main())
