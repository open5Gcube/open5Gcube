tests-install-venv: tests/.venv.build
tests-remove-venv:
	rm -rf tests/.venv.build tests/venv

ACTIVATE_TEST_VENV = source tests/venv/bin/activate;                          \
    export BASE_DIR=${BASE_DIR}; export ENV_DIR=${ENV_DIR}
ROBOT = $(ACTIVATE_TEST_VENV); robot --consolewidth $${COLUMNS:-120}          \
    --prerunmodifier ${BASE_DIR}/tests/SuiteNameTidier.py
TEST_DIRS = modules/*/stacks/*/tests/

tests/.venv.build: tests/requirements.txt
	test -d tests/venv || virtualenv --prompt test-env tests/venv
	$(ACTIVATE_TEST_VENV); pip install -r $<
	@touch $@

tests-run-all: tests-install-venv
	${ROBOT} -N "open5Gcube" -d tests/results/all/$$(date '+%Y%m%d-%H%M') modules

# `tests-run-all-<tag1>-<tag2>-...` runs every suite that has all of the given
# tags, e.g. `make tests-run-all-emulated` or `make tests-run-all-sdr-srsran`.
# Tags therefore must not contain dashes.
tests-run-all-%: tests-install-venv
	${ROBOT} -N "open5Gcube" -i $(subst -,AND,$*)                             \
	    -d tests/results/all-$*/$$(date '+%Y%m%d-%H%M') modules

# Explicit names for `tests-run-all-<tag>` and
# `tests-run-all-<radio type>-<tag>`, the radio type (emulated, sdr) being each
# suite's first tag. They only serve tab completion: their recipe is the
# pattern rule's.
TEST_TARGETS := $(shell sed -n 's/^Test Tags//p' ${TEST_DIRS}*.robot          \
    | tr 'A-Z' 'a-z' | awk '{ for (i = 1; i <= NF; i++) {                     \
        print "tests-run-all-" $$i;                                           \
        if (i > 1) print "tests-run-all-" $$1 "-" $$i } }'                    \
    | sort -u)
${TEST_TARGETS}:

# Explicit tests-run-<stack> targets for every stack that has a tests/ directory
# e.g. `make tests-run-ueransim-open5gs`.
TEST_STACKS := $(sort $(notdir $(patsubst %/tests/,%,$(wildcard ${TEST_DIRS}))))
$(addprefix tests-run-,${TEST_STACKS}): tests-run-%: tests-install-venv
	${ROBOT} -N "open5Gcube.$*" -d tests/results/$*/$$(date '+%Y%m%d-%H%M')   \
	    $(wildcard modules/*/stacks/$*/tests)

tests-lint: tests-install-venv
	$(ACTIVATE_TEST_VENV); robocop check --config tests/robocop.toml          \
	    modules/*/stacks tests

tests-clean:
	rm -rf tests/results
