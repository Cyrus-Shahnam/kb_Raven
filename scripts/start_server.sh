#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"
export PATH="/opt/conda3/bin:${PATH:-}"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
exec uwsgi --master --processes 5 --threads 5 --http :5000 \
  --wsgi-file "${script_dir}/../lib/kb_raven/kb_ravenServer.py"
