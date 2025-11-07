#!/usr/bin/env bash
set -eo pipefail
export PATH="/opt/conda3/bin:${PATH:-}"
export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"

cmd="${1:-start}"
shift || true

case "$cmd" in
  report)
    # Catalog compile-report: copy prebuilt JSON if present; else write a minimal fallback.
    mkdir -p work
    if [[ -f ci/compile_report.json ]]; then
      cp -f ci/compile_report.json work/compile_report.json
      echo "Wrote work/compile_report.json from ci/compile_report.json"
    else
      cat > work/compile_report.json <<'JSON'
{
  "version": "1.0",
  "module_name": "kb_raven",
  "status": "ok",
  "details": {
    "spec_file": "kb_raven.spec",
    "service_language": "python",
    "impl": "kb_raven.kb_ravenImpl",
    "server": "kb_raven.kb_ravenServer"
  }
}
JSON
      echo "Wrote minimal work/compile_report.json (fallback)."
    fi
    ;;

  start)
    exec su -s /bin/bash -c "./scripts/start_server.sh" kbmodule
    ;;

  async)
    exec su -s /bin/bash -c "./bin/run_kb_raven_async_job.sh $*" kbmodule
    ;;

  *)
    exec "$cmd" "$@"
    ;;
esac
