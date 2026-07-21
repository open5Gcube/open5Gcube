"""Robot Framework pre-run modifier to tidy auto-generated suite names."""

from robot.api import SuiteVisitor

FLATTEN = {"stacks", "tests"}

class SuiteNameTidier(SuiteVisitor):
    def start_suite(self, suite):
        if suite.parent is not None:
            suite.name = suite.name.lower()
        children = []
        for child in suite.suites:
            if child.name.lower() in FLATTEN:
                children.extend(child.suites)
            else:
                children.append(child)
        suite.suites = children
