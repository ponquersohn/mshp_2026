#!/usr/bin/env bash
# Tear the container down and (optionally) bring the vulnerable root service
# back — handy when rehearsing the before/after repeatedly.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
docker rm -f pingboard 2>/dev/null || true
echo "[60] container removed"
if [[ "${1:-}" == "--restore-vuln" ]]; then
  echo "[60] restoring the unconfined root service"
  systemctl enable --now pingboard.service
fi
