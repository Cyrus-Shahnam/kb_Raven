#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
exec /opt/conda3/bin/python -u "${script_dir}/../lib/kb_raven/kb_ravenServer.py" "$@"
