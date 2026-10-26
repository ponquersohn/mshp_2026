#!/usr/bin/env bash
# Appendix: get logs OFF the host so a root attacker cannot quietly erase them.
# Minimal demo: mirror the journal + audit log to a separate append-only sink.
# In production this is a remote rsyslog/journald-remote/SIEM target; here we
# just show the principle locally and name the real options.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

echo "[80] making the journal persistent (survives the attacker clearing /run)"
mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal 2>/dev/null || true
systemctl restart systemd-journald

echo "[80] forwarding to a local sink as a stand-in for a remote collector"
cat > /etc/rsyslog.d/90-mshp-forward.conf <<'RS'
# Real deployment: *.* @@logcollector.internal:6514 (TLS). Lab stand-in:
*.* /var/log/mshp-offhost.log
RS
systemctl restart rsyslog 2>/dev/null || true

echo
echo "[80] principle: the box that is compromised must not be the only place its"
echo "     evidence lives. Real options: journald-remote, rsyslog over TLS,"
echo "     auditd's au-remote/audisp, or an agent shipping to a SIEM."
echo "     Also: make the collector append-only and time-synced (chrony)."
