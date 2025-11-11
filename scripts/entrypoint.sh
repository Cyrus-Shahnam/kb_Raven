#!/usr/bin/env bash
set -euo pipefail

mode="${1:-async}"
shift || true

export PATH="/opt/conda3/bin:${PATH:-}"
export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"

echo "[entrypoint] mode=${mode} args_left=[$*]"
case "${mode}" in
  report)
    mkdir -p /kb/module/work
    if [ -f /kb/module/ci/compile_report.json ]; then
      cp /kb/module/ci/compile_report.json /kb/module/work/compile_report.json
      echo "Wrote work/compile_report.json from ci/compile_report.json"
    else
      printf '{"status":"ok","notes":"stub compile report for AppDev"}\n' > /kb/module/work/compile_report.json
      echo "Wrote stub work/compile_report.json"
    fi
    exit 0
    ;;
  async)
    cb="${1:-${SDK_CALLBACK_URL:-}}"; shift || true
    tok="${1:-$(cat /kb/module/work/token 2>/dev/null || echo notoken)}"; shift || true
    jid="${1:-$(/opt/conda3/bin/python - <<'PY' 2>/dev/null || echo nojid
import json
try:
    print(json.load(open("/kb/module/work/input.json")).get("id",""))
except Exception:
    pass
PY
)}"
    if [ -z "${cb}" ]; then echo "[async] ERROR: missing SDK_CALLBACK_URL and no CLI cb"; exit 2; fi
    echo "[async] exec bin/run_kb_raven_async_job.sh '${cb}' '${tok}' '${jid}'"
    exec /kb/module/bin/run_kb_raven_async_job.sh "${cb}" "${tok}" "${jid}"
    ;;
  server)
    exec /opt/conda3/bin/uwsgi --master --processes 5 --threads 5 --http :5000 \
      --wsgi-file /kb/module/lib/kb_raven/kb_ravenServer.py
    ;;
  *)
    echo "[entrypoint] unknown mode '${mode}' → fallback to async"
    exec "$0" async "$@"
    ;;
esac
