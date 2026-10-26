#!/usr/bin/env bash
# Hardening step 5: a live eBPF exec stream to a file, as a service.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
cd /opt/pingboard/harden/20-telemetry

echo "[20] installing the eBPF telemetry unit"
install -m0644 mshp-execsnoop.service /etc/systemd/system/mshp-execsnoop.service
systemctl daemon-reload
systemctl enable --now mshp-execsnoop.service
sleep 2
systemctl --no-pager --lines=3 status mshp-execsnoop.service || true

echo
echo "[20] done. In one pane:   sudo tail -f /var/log/mshp/exec.log"
echo "     in another:          ../../attack/pwn.sh"
echo "     watch every injected command appear with caller=sh and the"
echo "     pingboard python process as its parent."
