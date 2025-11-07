SERVICE = kb_raven
SERVICE_CAPS = kb_raven
SPEC_FILE = kb_raven.spec
LIB_DIR = lib
SCRIPTS_DIR = scripts
TEST_DIR = test
LBIN_DIR = bin
EXECUTABLE_SCRIPT_NAME = run_$(SERVICE_CAPS)_async_job.sh
STARTUP_SCRIPT_NAME = start_server.sh
TEST_SCRIPT_NAME = run_tests.sh
CLIENTS = ReadsUtils DataFileUtil AssemblyUtil KBaseReport Workspace

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: default all deps compile build scripts test clean

default: compile

all: deps compile build

# one-shot for local dev only; do NOT call in Docker build
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

# just make scripts executable (they're checked into the repo)
build:
	@[ -f $(SCRIPTS_DIR)/entrypoint.sh ] && chmod +x $(SCRIPTS_DIR)/entrypoint.sh || echo "WARN: missing scripts/entrypoint.sh"
	@[ -f $(SCRIPTS_DIR)/$(STARTUP_SCRIPT_NAME) ] && chmod +x $(SCRIPTS_DIR)/$(STARTUP_SCRIPT_NAME) || echo "WARN: missing scripts/$(STARTUP_SCRIPT_NAME)"
	@[ -f $(LBIN_DIR)/$(EXECUTABLE_SCRIPT_NAME) ] && chmod +x $(LBIN_DIR)/$(EXECUTABLE_SCRIPT_NAME) || echo "WARN: missing $(LBIN_DIR)/$(EXECUTABLE_SCRIPT_NAME)"
	@[ -f $(TEST_DIR)/$(TEST_SCRIPT_NAME) ] && chmod +x $(TEST_DIR)/$(TEST_SCRIPT_NAME) || echo "WARN: missing $(TEST_DIR)/$(TEST_SCRIPT_NAME)"


# alias for Dockerfiles that might call 'make scripts'
scripts: build

# test harness (inside container)
test: build
	@if [ ! -f /kb/module/work/token ]; then echo -e '\nOutside a docker container please run "kb-sdk test" rather than "make test"\n' && exit 1; fi
	bash $(TEST_DIR)/$(TEST_SCRIPT_NAME)

clean:
	rm -rfv $(LBIN_DIR)/*
