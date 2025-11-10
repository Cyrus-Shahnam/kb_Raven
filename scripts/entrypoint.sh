#!/usr/bin/env bash
set -euo pipefail

# Modes:
#   start  -> run uWSGI service (local dev)
#   async  -> run an async job (NJS)
#   report -> write compile_report.json for AppDev registration
#   *      -> exec arbitrary command
mode="${1:-async}"

case "$mode" in
  start)
    export KB_DEPLOYMENT_CONFIG="${KB_DEPLOYMENT_CONFIG:-/kb/module/deploy.cfg}"
    export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"
    exec uwsgi --master --processes 5 --threads 5 --http :5000 \
      --wsgi-file /kb/module/lib/kb_raven/kb_ravenServer.py
    ;;

  async)
    shift || true
    export PYTHONPATH="/kb/module/lib:${PYTHONPATH:-}"

    # Prefer EE2 env; fall back to work/ files (SPAdes pattern)
    cb="${SDK_CALLBACK_URL:-}"
    tok="${KB_AUTH_TOKEN:-}"
    jid="${JOB_ID:-}"

    if [[ -z "${cb}" && -f /kb/module/work/config.properties ]]; then
      cb=$(awk -F'=' '/external_url[[:space:]]*=/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' /kb/module/work/config.properties || true)
    fi
    [[ -z "${tok}" && -f /kb/module/work/token ]] && tok="$(cat /kb/module/work/token || true)"
    if [[ -z "${jid}" && -f /kb/module/work/input.json ]]; then
      jid="$(
        /opt/conda3/bin/python - <<'PY'
import json,sys
try:
    print(json.load(open('/kb/module/work/input.json'))['id'])
except Exception:
    sys.exit(0)
PY
      )"
    fi

    exec /opt/conda3/bin/python -u /kb/module/lib/kb_raven/kb_ravenServer.py "${cb:-}" "${tok:-}" "${jid:-}"
    ;;

  report)
    # AppDev runs this to create compile_report.json
    mkdir -p /kb/module/work
    if [[ -f /kb/module/ci/compile_report.json ]]; then
      cp /kb/module/ci/compile_report.json /kb/module/work/compile_report.json
      echo "Wrote work/compile_report.json from ci/compile_report.json"
    else
      echo '{"ok":true,"source":"fallback"}' > /kb/module/work/compile_report.json
      echo "Wrote minimal compile report"
    fi
    ;;

  *)
    exec "$@"
    ;;
esac
