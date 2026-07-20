tests-install-venv: tests/.venv.build
tests-remove-venv:
	rm -rf tests/.venv.build tests/venv

ACTIVATE_TEST_VENV = source tests/venv/bin/activate;                          \
    export BASE_DIR=${BASE_DIR}; export ENV_DIR=${ENV_DIR}
#    set -a; source ${O5GC_ENV}; unset MODULE

tests/.venv.build: tests/requirements.txt
	test -d tests/venv || virtualenv --prompt test-env tests/venv
	$(ACTIVATE_TEST_VENV); pip install -r $<
	@touch $@

tests-run-emulated: tests-install-venv .create-running-env
	$(ACTIVATE_TEST_VENV); robot -N "open5Gcube" -i Emulated                  \
	    -d tests/results/emulated/$$(date '+%Y%m%d-%H%M') modules

tests-lint: tests-install-venv
	$(ACTIVATE_TEST_VENV); robocop -A tests/robocop.args

tests-clean:
	rm -rf tests/results
