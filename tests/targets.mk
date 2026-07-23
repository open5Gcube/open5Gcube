tests-install-venv: tests/.venv.build
tests-remove-venv:
	rm -rf tests/.venv.build tests/venv

ACTIVATE_TEST_VENV = source tests/venv/bin/activate;                          \
    export BASE_DIR=${BASE_DIR}; export ENV_DIR=${ENV_DIR}
ROBOT = $(ACTIVATE_TEST_VENV); robot --consolewidth $${COLUMNS:-120}          \
    --prerunmodifier ${BASE_DIR}/tests/SuiteNameTidier.py

tests/.venv.build: tests/requirements.txt
	test -d tests/venv || virtualenv --prompt test-env tests/venv
	$(ACTIVATE_TEST_VENV); pip install -r $<
	@touch $@

# One `tests-run-all-<tag>` target per tag used by any suite, e.g.
# `make tests-run-all-open5gs` or `make tests-run-all-oai-cn`. The tag list is
# derived from the suites' `Test Tags` lines.
TEST_TAGS := $(sort $(shell sed -n 's/^Test Tags//p'                          \
    modules/*/stacks/*/tests/*.robot | tr 'A-Z' 'a-z'))
$(addprefix tests-run-all-,${TEST_TAGS}): tests-run-all-%: tests-install-venv
	${ROBOT} -N "open5Gcube" -i $*                                            \
	    -d tests/results/all-$*/$$(date '+%Y%m%d-%H%M') modules

# Explicit tests-run-<stack> targets for every stack that has a tests/ directory
# e.g. `make tests-run-ueransim-open5gs`.
TEST_STACKS := $(sort $(notdir $(patsubst %/tests,%,$(wildcard modules/*/stacks/*/tests))))
$(addprefix tests-run-,${TEST_STACKS}): tests-run-%: tests-install-venv
	${ROBOT} -N "open5Gcube.$*" -d tests/results/$*/$$(date '+%Y%m%d-%H%M')   \
	    $(wildcard modules/*/stacks/$*/tests)

tests-lint: tests-install-venv
	$(ACTIVATE_TEST_VENV); robocop check --config tests/robocop.toml           \
	    modules/*/stacks tests

tests-clean:
	rm -rf tests/results
