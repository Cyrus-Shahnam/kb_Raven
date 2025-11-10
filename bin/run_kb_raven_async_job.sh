#!/usr/bin/env bash
set -euo pipefail
script_dir="$(dirname "$(readlink -f "$0")")"

# env + config
export PATH="/opt/conda3/bin:${PATH:-}"
export PYTHONPATH="${script_dir}/../lib:${PYTHONPATH:-}"
export KB_DEPLOYMENT_CONFIG="${script_dir}/../deploy.cfg"

# If we got exactly one empty arg (""), treat as zero args
if (( $# == 1 )) && [[ -z "${1}" ]]; then
  set --
fi

discover_job_id() {
  local jid="${JOB_ID:-}"
  # try common file used by the job runner
  if [[ -z "$jid" && -f /kb/module/work/job_id ]]; then
    jid="$(cat /kb/module/work/job_id || true)"
  fi
  # try config.properties (often present)
  if [[ -z "$jid" && -f /kb/module/work/config.properties ]]; then
    jid="$(grep -E '^job_id=' /kb/module/work/config.properties | cut -d= -f2- || true)"
  fi
  # trim spaces
  jid="$(echo -n "$jid" | tr -d '[:space:]')"
  echo "$jid"
}

args=()
if (( $# >= 1 )); then
  # NJS provided args → pass through
  args=("$@")
else
  # Build the 3 args for kb_*Server.py from env/files
  cb="${SDK_CALLBACK_URL:-}"
  tok="${KB_AUTH_TOKEN:-}"
  [[ -z "${tok}" && -f /kb/module/work/token ]] && tok="$(cat /kb/module/work/token || true)"
  jid="$(discover_job_id)"

  if [[ -z "${cb}" ]]; then
    echo "[async] ERROR: no CLI args and SDK_CALLBACK_URL not set; cannot run async." >&2
    exit 2
  fi
  if [[ -z "${jid}" ]]; then
    echo "[async] WARN: job_id not found in env or work/*. Will try anyway, but server may not fetch params."
    jid="nojid"
  fi

  args=("${cb}" "${tok:-notoken}" "${jid}")
fi

echo "[async] invoking kb_ravenServer.py with ${#args[@]} args: ${args[*]@Q}"
# Helpful breadcrumbs to the log for debugging when it still hangs
echo "[async] env SDK_CALLBACK_URL=${SDK_CALLBACK_URL:-<unset>} KB_AUTH_TOKEN=${KB_AUTH_TOKEN:+<set>} JOB_ID=${JOB_ID:-<unset>}"
echo "[async] ls -la /kb/module/work:"; ls -la /kb/module/work || true
[[ -f /kb/module/work/config.properties ]] && { echo "[async] head -n 50 /kb/module/work/config.properties"; head -n 50 /kb/module/work/config.properties; }

exec /opt/conda3/bin/python -u "${script_dir}/../lib/kb_raven/kb_ravenServer.py" "${args[@]}"
