#!/bin/bash
set -euo pipefail

export PYTHONPATH="/kb/module/lib:${PYTHONPATH}"

cmd="${1:-start}"
shift || true

case "$cmd" in
  report)
    # Catalog's compile-report path: needs to write ./work/*.json
    make compile
    ;;
  start)
    # Launch service as kbmodule
    exec su -s /bin/bash -c "./scripts/start_server.sh" kbmodule
    ;;
  async)
    # Run async job wrapper as kbmodule, forward all args
    exec su -s /bin/bash -c "./bin/run_kb_raven_async_job.sh $*" kbmodule
    ;;
  *)
    # Fallback: pass through
    exec "$cmd" "$@"
    ;;
esac
