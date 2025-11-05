#!/bin/bash
set -eo pipefail
# tolerate unset PYTHONPATH
export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"

cmd="${1:-start}"
shift || true

case "$cmd" in
  report)
    # Catalog's compile-report step: just drop the prebuilt report in ./work
    if [ ! -f ci/compile_report.json ]; then
      echo "ERROR: ci/compile_report.json missing. Run 'kb-sdk compile' locally and commit it." >&2
      exit 2
    fi
    mkdir -p work
    cp -f ci/compile_report.json work/compile_report.json
    echo "Wrote work/compile_report.json from ci/compile_report.json"
    exit 0
    ;;

  start)
    # Serve API as kbmodule
    exec su -s /bin/bash -c "./scripts/start_server.sh" kbmodule
    ;;

  async)
    # Async job wrapper as kbmodule
    exec su -s /bin/bash -c "./bin/run_kb_raven_async_job.sh $*" kbmodule
    ;;

  *)
    exec "$cmd" "$@"
    ;;
esac
