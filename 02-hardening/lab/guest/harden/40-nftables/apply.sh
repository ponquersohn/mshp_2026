#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
cd /opt/pingboard/harden/40-nftables
echo "[40] syntax check"; nft -c -f mshp.nft
echo "[40] (re)loading our table only (Docker's chains untouched)"
nft delete table inet mshp 2>/dev/null || true
nft -f mshp.nft
echo "[40] active table:"; nft list table inet mshp
echo
echo "[40] done. Re-run ../../attack/pwn.sh: probe #4 egress -> EGRESS-BLOCKED,"
echo "     while ssh and the app (#0) keep working. Ingress to any OTHER port is"
echo "     now dropped too."
