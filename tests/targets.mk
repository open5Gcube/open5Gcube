tests-install-venv: tests/.venv.build
tests-remove-venv:
	rm -rf tests/.venv.build tests/venv

ACTIVATE_TEST_VENV = source tests/venv/bin/activate;                          \
    export BASE_DIR=${BASE_DIR}; export ENV_DIR=${ENV_DIR}
ROBOT = $(ACTIVATE_TEST_VENV); robot --consolewidth $${COLUMNS:-120}

tests/.venv.build: tests/requirements.txt
	test -d tests/venv || virtualenv --prompt test-env tests/venv
	$(ACTIVATE_TEST_VENV); pip install -r $<
	@touch $@

tests-run-all-emulated: tests-install-venv
	${ROBOT} -N "open5Gcube" -i Emulated                                      \
	    -d tests/results/all-emulated/$$(date '+%Y%m%d-%H%M') modules

# Explicit tests-run-<stack> targets for every stack that has a tests/ directory
# e.g. `make tests-run-ueransim-open5gs`.
TEST_STACKS := $(sort $(notdir $(patsubst %/tests,%,$(wildcard modules/*/stacks/*/tests))))
$(addprefix tests-run-,${TEST_STACKS}): tests-run-%: tests-install-venv
	${ROBOT} -N "$*" -d tests/results/$*/$$(date '+%Y%m%d-%H%M')              \
	    $(wildcard modules/*/stacks/$*/tests)

tests-lint: tests-install-venv
	$(ACTIVATE_TEST_VENV); robocop check --config tests/robocop.toml modules tests

tests-clean:
	rm -rf tests/results
