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

  # common file from job runner
  if [[ -z "$jid" && -f /kb/module/work/job_id ]]; then
    jid="$(cat /kb/module/work/job_id || true)"
  fi

  # sometimes appears in config.properties (rare)
  if [[ -z "$jid" && -f /kb/module/work/config.properties ]]; then
    jid="$(grep -E '^[[:space:]]*job_id[[:space:]]*=' /kb/module/work/config.properties | tail -n1 | cut -d= -f2- | tr -d '[:space:]' || true)"
  fi

  # robust parse from input.json (most reliable)
  if [[ -z "$jid" && -f /kb/module/work/input.json ]]; then
    jid="$(
      /opt/conda3/bin/python - <<'PY' || true
import json, re, sys
p='/kb/module/work/input.json'
try:
    with open(p) as f:
        j=json.load(f)
except Exception:
    print("", end=""); sys.exit(0)

found=[]
def walk(x):
    if isinstance(x, dict):
        for k,v in x.items():
            if re.fullmatch(r'job[_-]?id', k, flags=re.I):
                s=str(v).strip()
                if s:
                    found.append(s)
            walk(v)
    elif isinstance(x, list):
        for v in x: walk(v)

walk(j)
print(found[0] if found else "", end="")
PY
    )"
  fi

  printf '%s' "$jid"
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

  [[ -n "${tok}" ]] || tok="notoken"
  args=("${cb}" "${tok}" "${jid}")
fi

echo "[async] invoking kb_ravenServer.py with ${#args[@]} args: ${args[*]@Q}"
echo "[async] env SDK_CALLBACK_URL=${SDK_CALLBACK_URL:-<unset>} KB_AUTH_TOKEN=${KB_AUTH_TOKEN:+<set>} JOB_ID=${JOB_ID:-<unset>}"
echo "[async] ls -la /kb/module/work:"; ls -la /kb/module/work || true
[[ -f /kb/module/work/input.json ]] && { echo "[async] head -n 40 /kb/module/work/input.json"; head -n 40 /kb/module/work/input.json; }
[[ -f /kb/module/work/config.properties ]] && { echo "[async] head -n 40 /kb/module/work/config.properties"; head -n 40 /kb/module/work/config.properties; }

exec /opt/conda3/bin/python -u "${script_dir}/../lib/kb_raven/kb_ravenServer.py" "${args[@]}"
