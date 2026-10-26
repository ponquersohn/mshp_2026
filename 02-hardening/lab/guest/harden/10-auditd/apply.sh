#!/usr/bin/env bash
# Hardening step 4: turn on the flight recorder.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
cd /opt/pingboard/harden/10-auditd

echo "[10] installing audit rules"
install -m0640 mshp.rules /etc/audit/rules.d/mshp.rules
systemctl enable --now auditd
# augenrules compiles rules.d into the live policy; -e 2 makes it immutable, so
# do this before load. If a previous run already set immutable, a reboot resets.
augenrules --load || { echo "immutable already set; reboot to reload rules"; }
auditctl -s | sed 's/^/[10] /'
auditctl -l | sed 's/^/[10] rule: /' | head

echo
echo "[10] done. Now run ../../attack/pwn.sh, then SEE it:"
echo "     sudo ausearch -if /var/log/audit/audit.log -k exec | aureport -i --summary 2>/dev/null | tail"
echo "     sudo ausearch -if /var/log/audit/audit.log -k secret"
echo "     sudo ausearch -if /var/log/audit/audit.log -k persist"
echo "     (raw:  sudo tail -f /var/log/audit/audit.log)"
echo
echo "[10] production upgrade: ship these off-host and parse to JSON — see"
echo "     ../20-telemetry for a modern eBPF stream, and laurel/sysmonforlinux"
echo "     in the README for turning audit records into structured events."
