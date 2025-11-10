#!/usr/bin/env bash
set -euo pipefail
export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"
exec /opt/conda3/bin/python -u /kb/module/lib/kb_raven/kb_ravenServer.py "$@"
