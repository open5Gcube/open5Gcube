#!/usr/bin/env python
"""Print Robot Framework keyword timings from an output.xml.

Usage:
    python tests/kw_profile.py <output.xml> [top-N]

Reads the timings Robot already records for every keyword and prints them
grouped per test suite and, within each suite, per test case (keywords run
directly by a suite setup/teardown are listed separately). Each group is
ranked by elapsed time so you can see which keyword dominates. [top-N] limits
the keywords shown per group (default 40).
"""
import sys

from robot.api import ExecutionResult, ResultVisitor

SUITE_LEVEL = None  # key used for keywords run outside any test (suite setup/teardown)


class KeywordTimer(ResultVisitor):
    def __init__(self):
        self._suites = []  # stack of suite longnames currently being visited
        self._test = None  # current test name, or None inside a suite setup/teardown
        # suite longname -> {"elapsed": s, "groups": {test-or-None: [(s, kw), ...]},
        #                    "test_elapsed": {test: s}, "order": [test-or-None, ...]}
        self.suites = {}

    def start_suite(self, suite):
        self._suites.append(suite.longname)
        self.suites.setdefault(
            suite.longname,
            {"elapsed": 0.0, "groups": {}, "test_elapsed": {}, "order": []},
        )

    def end_suite(self, suite):
        self.suites[suite.longname]["elapsed"] = suite.elapsedtime / 1000.0
        self._suites.pop()

    def start_test(self, test):
        self._test = test.name
        data = self.suites[self._suites[-1]]
        data["test_elapsed"][test.name] = test.elapsedtime / 1000.0

    def end_test(self, test):
        self._test = None

    def start_keyword(self, kw):
        if not self._suites:
            return
        data = self.suites[self._suites[-1]]
        group = data["groups"].setdefault(self._test, [])
        if not group:
            data["order"].append(self._test)
        group.append((kw.elapsedtime / 1000.0, kw.kwname or kw.name))


def print_group(title, rows, top):
    print(f"  -- {title} --")
    for elapsed, name in sorted(rows, key=lambda row: row[0], reverse=True)[:top]:
        print(f"    {elapsed:>8.2f}  {name}")


def main(path, top=40):
    result = ExecutionResult(path)
    timer = KeywordTimer()
    result.visit(timer)
    for suite, data in timer.suites.items():
        if not data["groups"]:  # container suite with no keywords of its own
            continue
        print(f"\n=== {suite}  (wall-clock {data['elapsed']:.2f}s) ===")
        for test in data["order"]:
            rows = data["groups"][test]
            if test is SUITE_LEVEL:
                print_group("suite setup/teardown", rows, top)
            else:
                print_group(f"test: {test}  ({data['test_elapsed'][test]:.2f}s)", rows, top)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 40)
