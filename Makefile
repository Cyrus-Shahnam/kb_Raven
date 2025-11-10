SERVICE       = kb_raven
SERVICE_CAPS  = kb_raven
SPEC_FILE     = kb_raven.spec
LIB_DIR       = lib
SCRIPTS_DIR   = scripts
BIN_DIR       = bin
TEST_DIR      = test

.PHONY: default all compile build build-startup build-async build-test test clean

default: compile
all: compile build build-startup build-async build-test

compile:
	KB_SDK_LOCAL_TEST=1 kb-sdk compile $(SPEC_FILE) \
		--out $(LIB_DIR) \
		--pysrvname $(SERVICE_CAPS).$(SERVICE_CAPS)Server \
		--pyimplname $(SERVICE_CAPS).$(SERVICE_CAPS)Impl

build:
	@[ -f $(SCRIPTS_DIR)/entrypoint.sh ] && chmod +x $(SCRIPTS_DIR)/entrypoint.sh || true

build-startup:
	@mkdir -p $(SCRIPTS_DIR)
	@cat > $(SCRIPTS_DIR)/start_server.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
export KB_DEPLOYMENT_CONFIG="${KB_DEPLOYMENT_CONFIG:-/kb/module/deploy.cfg}"
export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"
exec uwsgi --master --processes 5 --threads 5 --http :5000 \
  --wsgi-file /kb/module/lib/kb_raven/kb_ravenServer.py
BASH
	@chmod +x $(SCRIPTS_DIR)/start_server.sh

build-async:
	@mkdir -p $(BIN_DIR)
	@cat > $(BIN_DIR)/run_$(SERVICE_CAPS)_async_job.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"
exec /opt/conda3/bin/python -u /kb/module/lib/kb_raven/kb_ravenServer.py "$@"
BASH
	@chmod +x $(BIN_DIR)/run_$(SERVICE_CAPS)_async_job.sh

build-test:
	@mkdir -p $(TEST_DIR)
	@cat > $(TEST_DIR)/run_tests.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"
export KB_AUTH_TOKEN="$(cat /kb/module/work/token 2>/dev/null || true)"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
mkdir -p /tmp/test_coverage
cd "${script_dir}"
exec nosetests -v --with-coverage --cover-package=kb_raven \
  --cover-html --cover-html-dir=/tmp/test_coverage \
  --nocapture --nologcapture .
BASH
	@chmod +x $(TEST_DIR)/run_tests.sh

test: compile build-test
	@if [ ! -f /kb/module/work/token ]; then echo -e '\nOutside a docker container please run "kb-sdk test" rather than "make test"\n' && exit 1; fi
	bash $(TEST_DIR)/run_tests.sh

clean:
	rm -rfv $(BIN_DIR)
