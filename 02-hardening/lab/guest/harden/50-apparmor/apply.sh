#!/usr/bin/env bash
# Hardening step 3: put a mandatory profile around the app. Works whether or not
# the app runs as root — MAC does not care about UID.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
cd /opt/pingboard/harden/50-apparmor

echo "[50] loading profile (enforce mode)"
apparmor_parser -r mshp-pingboard
aa-status | grep -i pingboard || true

echo "[50] attaching it to the service via a systemd drop-in"
install -d /etc/systemd/system/pingboard.service.d
cat > /etc/systemd/system/pingboard.service.d/50-apparmor.conf <<UNIT
[Service]
AppArmorProfile=mshp-pingboard
UNIT
systemctl daemon-reload
systemctl restart pingboard.service
sleep 1
systemctl --no-pager --lines=3 status pingboard.service || true

echo
echo "[50] done. Re-run ../../attack/pwn.sh:"
echo "     #1 ;id and #2/#3 ;cat -> blocked (binary exec denied by the profile)"
echo "     legit GET /api/ping?host=127.0.0.1 still works"
echo "     watch the denials: sudo journalctl -k --since '-2 min' | grep -i apparmor"
