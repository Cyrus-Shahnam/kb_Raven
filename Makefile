SERVICE = kb_raven
SERVICE_CAPS = kb_raven
SPEC_FILE = kb_raven.spec
URL = https://kbase.us/services/$(SERVICE)
DIR = $(shell pwd)
LIB_DIR = lib
SCRIPTS_DIR = scripts
TEST_DIR = test
LBIN_DIR = bin
WORK_DIR = /kb/module/work/tmp
EXECUTABLE_SCRIPT_NAME = run_$(SERVICE_CAPS)_async_job.sh
STARTUP_SCRIPT_NAME = start_server.sh
TEST_SCRIPT_NAME = run_tests.sh

CLIENTS = ReadsUtils DataFileUtil AssemblyUtil KBaseReport Workspace

.PHONY: default all deps compile build build-executable-script build-startup-script build-test-script test clean

default: compile

all: deps compile build build-startup-script build-executable-script build-test-script

# Install client stubs once (only if dependencies.json is missing)
deps:
	@if [ ! -f dependencies.json ]; then \
		echo "Installing KBase clients (one-time)..."; \
		kb-sdk install $(CLIENTS); \
	else \
		echo "dependencies.json present; skipping kb-sdk install"; \
	fi

compile:
	KB_SDK_LOCAL_TEST=1 kb-sdk compile $(SPEC_FILE) \
		--out $(LIB_DIR) \
		--pysrvname $(SERVICE_CAPS).$(SERVICE_CAPS)Server \
		--pyimplname $(SERVICE_CAPS).$(SERVICE_CAPS)Impl

build:
	chmod +x $(SCRIPTS_DIR)/entrypoint.sh

build-startup-script:
	mkdir -p $(SCRIPTS_DIR)
	@cat > $(SCRIPTS_DIR)/$(STARTUP_SCRIPT_NAME) <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
exec uwsgi --master --processes 5 --threads 5 --http :5000 \
  --wsgi-file "${script_dir}/../lib/$(SERVICE_CAPS)/$(SERVICE_CAPS)Server.py"
BASH
	chmod +x $(SCRIPTS_DIR)/$(STARTUP_SCRIPT_NAME)

build-executable-script:
	mkdir -p $(LBIN_DIR)
	@cat > $(LBIN_DIR)/$(EXECUTABLE_SCRIPT_NAME) <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"
export PATH="/opt/conda3/bin:${PATH:-}"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"
exec /opt/conda3/bin/python -u "${script_dir}/../lib/$(SERVICE_CAPS)/$(SERVICE_CAPS)Server.py" "$@"
BASH
	chmod +x $(LBIN_DIR)/$(EXECUTABLE_SCRIPT_NAME)

build-test-script:
	mkdir -p $(TEST_DIR)
	@cat > $(TEST_DIR)/$(TEST_SCRIPT_NAME) <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"
export KB_AUTH_TOKEN="$(cat /kb/module/work/token 2>/dev/null || true)"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
mkdir -p /tmp/test_coverage
cd "${script_dir}/../$(TEST_DIR)"
exec nosetests -v --with-coverage --cover-package=$(SERVICE_CAPS) \
  --cover-html --cover-html-dir=/tmp/test_coverage \
  --nocapture --nologcapture .
BASH
	chmod +x $(TEST_DIR)/$(TEST_SCRIPT_NAME)


# IMPORTANT: ensure compile (clients generated) and test script exist before running tests
test: compile build-test-script
	@if [ ! -f /kb/module/work/token ]; then echo -e '\nOutside a docker container please run "kb-sdk test" rather than "make test"\n' && exit 1; fi
	bash $(TEST_DIR)/$(TEST_SCRIPT_NAME)

clean:
	rm -rfv $(LBIN_DIR)
