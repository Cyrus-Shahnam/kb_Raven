#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"

# env + config for the server
export PATH="/opt/conda3/bin:${PATH:-}"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"

# If we got exactly one empty arg (""), treat as zero args
if (( $# == 1 )) && [[ -z "${1}" ]]; then
  set --
fi

args=()
if (( $# >= 1 )); then
  # NJS provided args → pass through
  args=("$@")
else
  # Build the 3 args for kb_*Server.py from env/files
  cb="${SDK_CALLBACK_URL:-}"
  tok="${KB_AUTH_TOKEN:-}"
  jid="${JOB_ID:-}"

  if [[ -z "${tok}" && -f /kb/module/work/token ]]; then
    tok="$(cat /kb/module/work/token || true)"
  fi
  if [[ -z "${jid}" && -f /kb/module/work/job_id ]]; then
    jid="$(cat /kb/module/work/job_id || true)"
  fi

  if [[ -z "${cb}" ]]; then
    echo "[async] ERROR: no CLI args and SDK_CALLBACK_URL not set; cannot run async." >&2
    exit 2
  fi

  [[ -n "${tok}" ]] || tok="notoken"
  [[ -n "${jid}" ]] || jid="nojid"
  args=("${cb}" "${tok}" "${jid}")
fi

echo "[async] invoking kb_ravenServer.py with ${#args[@]} args: ${args[*]@Q}"
exec /opt/conda3/bin/python -u "${script_dir}/../lib/kb_raven/kb_ravenServer.py" "${args[@]}"
