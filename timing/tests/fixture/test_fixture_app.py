import os

import pytest

from fixture_app import main


def test_import_check():
    assert main(["--import-check"]) == 0


def test_fail_flag():
    assert main(["--fail"]) == 3


@pytest.mark.skipif(not os.environ.get("FIXTURE_FAIL"), reason="FIXTURE_FAIL not set")
def test_forced_failure():
    raise AssertionError("forced failure requested by FIXTURE_FAIL")
