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
