#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"
export PATH="/opt/conda3/bin:${PATH:-}"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"
exec /opt/conda3/bin/python -u "${script_dir}/../lib/kb_raven/kb_ravenServer.py" "$@"
