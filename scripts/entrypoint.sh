#!/bin/bash
set -euo pipefail
export PYTHONPATH="/kb/module/lib:${PYTHONPATH}"

cmd="${1:-start}"
shift || true

case "$cmd" in
  report)
    # The Catalog mounts ./work; just drop the prebuilt report there.
    if [ ! -f ci/compile_report.json ]; then
      echo "ERROR: ci/compile_report.json missing; run 'kb-sdk compile' locally and commit it." 1>&2
      exit 1
    fi
    mkdir -p work
    cp ci/compile_report.json work/compile_report.json
    echo "Wrote work/compile_report.json from prebuilt ci/compile_report.json"
    ;;

  start)
    # Serve API as kbmodule
    exec su -s /bin/bash -c "./scripts/start_server.sh" kbmodule
    ;;

  async)
    # Run async job wrapper as kbmodule
    exec su -s /bin/bash -c "./bin/run_kb_raven_async_job.sh $*" kbmodule
    ;;

  *)
    exec "$cmd" "$@"
    ;;
esac
