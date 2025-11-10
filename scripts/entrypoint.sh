#!/usr/bin/env bash
set -euo pipefail

# Always have Python + lib in path
export PATH="/opt/conda3/bin:${PATH:-}"
export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"

echo "[entrypoint] args: $*"
echo "[entrypoint] SDK_CALLBACK_URL=${SDK_CALLBACK_URL:-<unset>}"

# Decide mode:
# - If explicit command was passed (report/start/async), use it.
# - If nothing passed and we're in NJS (SDK_CALLBACK_URL set), default to async.
# - Otherwise default to service start.
cmd="${1:-}"
shift || true

if [[ -z "${cmd}" ]]; then
  if [[ -n "${SDK_CALLBACK_URL:-}" ]]; then
    cmd="async"
  else
    cmd="start"
  fi
fi

case "${cmd}" in
  report)
    echo "[entrypoint] mode=report"
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
    "server": "kb_raven.kb_ravenServer.py"
  }
}
JSON
      echo "Wrote minimal work/compile_report.json (fallback)."
    fi
    ;;

  start)
    echo "[entrypoint] mode=start (service/uwsgi)"
    exec uwsgi --master --processes 5 --threads 5 --http :5000 \
      --wsgi-file "/kb/module/lib/kb_raven/kb_ravenServer.py"
    ;;

  async)
    echo "[entrypoint] mode=async"
    if [ "$#" -gt 0 ]; then
      exec su -m -s /bin/bash kbmodule -c 'exec ./bin/run_kb_raven_async_job.sh "$@"' -- "$@"
    else
      exec su -m -s /bin/bash kbmodule -c 'exec ./bin/run_kb_raven_async_job.sh'
    fi
    ;;

esac
