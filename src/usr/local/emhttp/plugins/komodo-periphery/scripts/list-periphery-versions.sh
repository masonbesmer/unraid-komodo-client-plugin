#!/bin/bash
set -euo pipefail

curl -fsSL --max-time 15 "https://api.github.com/repos/moghtech/komodo/releases?per_page=15" \
  | grep -o '"tag_name": *"[^"]*"' \
  | sed -E 's/.*"(v[^"]+)"/\1/'
