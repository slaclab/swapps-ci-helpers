# Builds a console and a windowed executable, so the Windows smoke test covers
# both. Pass "-- --console-only" to build just fixture_cli.
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--console-only", action="store_true")
options = parser.parse_args()

targets = [("fixture_cli", True)]
if not options.console_only:
    targets.append(("fixture_gui", False))

for name, console in targets:
    a = Analysis(["fixture_app.py"])
    pyz = PYZ(a.pure)
    EXE(pyz, a.scripts, a.binaries, a.datas, name=name, console=console)
