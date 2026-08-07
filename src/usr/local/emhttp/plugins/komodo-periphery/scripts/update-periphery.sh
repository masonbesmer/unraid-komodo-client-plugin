#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <latest|vX.Y.Z>" >&2
  exit 1
fi

API_URL="https://api.github.com/repos/moghtech/komodo/releases/latest"
if [[ "${VERSION}" != "latest" ]]; then
  API_URL="https://api.github.com/repos/moghtech/komodo/releases/tags/${VERSION}"
fi

RELEASE_JSON=$(curl -fsSL --max-time 20 "${API_URL}")
ASSET_BLOCK=$(printf '%s\n' "${RELEASE_JSON}" | sed -n '/"name": "periphery-x86_64"/,/^    },$/p')

if [[ -z "${ASSET_BLOCK}" ]]; then
  echo "Could not find a periphery-x86_64 asset for ${VERSION}." >&2
  exit 1
fi

ASSET_URL=$(printf '%s\n' "${ASSET_BLOCK}" | grep -m1 '"browser_download_url"' | sed -E 's/.*"(https:[^"]+)".*/\1/')
ASSET_SHA256=$(printf '%s\n' "${ASSET_BLOCK}" | grep -m1 '"digest"' | sed -E 's/.*"sha256:([0-9a-f]+)".*/\1/')

if [[ -z "${ASSET_URL}" || -z "${ASSET_SHA256}" ]]; then
  echo "Could not parse release metadata for ${VERSION}." >&2
  exit 1
fi

RESOLVED_VERSION=$(basename "$(dirname "${ASSET_URL}")")

load_config
ensure_layout

TMP_FILE=$(mktemp)
trap 'rm -f "${TMP_FILE}"' EXIT

echo "Downloading Komodo Periphery ${RESOLVED_VERSION}..."
curl -fsSL --max-time 180 "${ASSET_URL}" -o "${TMP_FILE}"

ACTUAL_SHA256=$(sha256sum "${TMP_FILE}" | awk '{print $1}')
if [[ "${ACTUAL_SHA256}" != "${ASSET_SHA256}" ]]; then
  echo "Checksum mismatch for ${ASSET_URL}" >&2
  echo "Expected: ${ASSET_SHA256}" >&2
  echo "Actual:   ${ACTUAL_SHA256}" >&2
  exit 1
fi

WAS_RUNNING="no"
is_running && WAS_RUNNING="yes"
[[ "${WAS_RUNNING}" == "yes" ]] && "${SCRIPT_DIR}/stop.sh"

install -m 0755 "${TMP_FILE}" "${BINARY}"
echo "${RESOLVED_VERSION}" > "${STATE_DIR}/periphery-version"

if [[ "${WAS_RUNNING}" == "yes" ]]; then
  "${SCRIPT_DIR}/start.sh"
fi

echo "Komodo Periphery updated to ${RESOLVED_VERSION}."
