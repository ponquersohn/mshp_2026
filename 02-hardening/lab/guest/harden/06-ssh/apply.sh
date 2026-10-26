#!/usr/bin/env bash
# Act 1, step 6: make the SSH entry path explicit, and throttle brute force.
# ALWAYS keep a second session + the console open before reloading sshd.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
cd /opt/pingboard/harden/06-ssh

echo "[06] installing sshd drop-in (key-only, no root, no password)"
install -d /etc/ssh/sshd_config.d
install -m0644 mshp-sshd.conf /etc/ssh/sshd_config.d/00-mshp.conf

echo "[06] syntax + effective config check"
/usr/sbin/sshd -t && echo "  syntax OK"
/usr/sbin/sshd -T 2>/dev/null | grep -Ei '^(permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication) '

echo "[06] reloading sshd (keep your current session open!)"
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true

echo "[06] brute-force throttling with fail2ban"
if command -v fail2ban-server >/dev/null; then
  cat > /etc/fail2ban/jail.d/sshd.local <<'JAIL'
[sshd]
enabled = true
maxretry = 3
findtime = 10m
bantime = 10m
JAIL
  systemctl enable --now fail2ban
  sleep 1
  fail2ban-client status sshd 2>/dev/null | sed 's/^/    /' || true
else
  echo "  fail2ban not installed (apt-get install fail2ban)"
fi
echo
echo "[06] done. From a CLIENT: prove key login works, root is refused, and"
echo "     password auth is not offered. Hammer a bad login 3x -> fail2ban ban."
