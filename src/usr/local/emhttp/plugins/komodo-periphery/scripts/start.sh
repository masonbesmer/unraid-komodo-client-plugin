#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

load_config
ensure_layout
render_runtime_config

if is_running; then
  echo "Komodo Periphery is already running."
  exit 0
fi

require_start_config
is_runtime_ready

export PERIPHERY_CORE_ADDRESS
export PERIPHERY_CONNECT_AS
export PERIPHERY_ONBOARDING_KEY="${PERIPHERY_ONBOARDING_KEY:-}"
export PERIPHERY_CORE_PUBLIC_KEYS="${PERIPHERY_CORE_PUBLIC_KEYS:-}"

if ! command -v script >/dev/null 2>&1; then
  echo "The 'script' utility is required to start Periphery but was not found."
  exit 1
fi

# Periphery exits immediately when its stdout isn't a pseudo-terminal, so it
# can't be launched as a plain backgrounded process; `script` gives it one.
setsid script -qc "exec \"${BINARY}\" --config-path \"${RUNTIME_CONFIG_FILE}\"" "${LOG_FILE}" < /dev/null > /dev/null 2>&1 &
SCRIPT_PID=$!

PERIPHERY_PID=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if PERIPHERY_PID=$(find_child_pid "${SCRIPT_PID}"); then
    break
  fi
  sleep 0.2
done

if [[ -z "${PERIPHERY_PID}" ]]; then
  echo "Komodo Periphery failed to start. See ${LOG_FILE}."
  exit 1
fi

echo "${PERIPHERY_PID}" > "${PID_FILE}"
sleep 2

if ! is_running; then
  echo "Komodo Periphery failed to start. See ${LOG_FILE}."
  rm -f "${PID_FILE}"
  exit 1
fi

echo "Komodo Periphery started."
