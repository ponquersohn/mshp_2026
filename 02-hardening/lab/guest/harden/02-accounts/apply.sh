#!/usr/bin/env bash
# Act 1, step 2: fix the account mess.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

echo "[02] removing the second UID-0 account (svc-deploy)"
if id svc-deploy >/dev/null 2>&1; then userdel -f svc-deploy || true; fi

echo "[02] stripping webops of root-equivalent group membership"
gpasswd -d webops sudo   2>/dev/null || true
gpasswd -d webops docker 2>/dev/null || true
# keep the account but it is now unprivileged; lock it if it is not a real user
usermod -L webops 2>/dev/null || true

echo "[02] scrubbing unknown keys from root's authorized_keys"
if [[ -f /root/.ssh/authorized_keys ]]; then
  sed -i '/ATTACKER-DROPPED-KEY/d' /root/.ssh/authorized_keys
fi

echo "[02] result:"
awk -F: '$3==0{print "  UID 0:",$1}' /etc/passwd
echo "  sudo group:   $(getent group sudo   | cut -d: -f4)"
echo "  docker group: $(getent group docker | cut -d: -f4)"
echo
echo "[02] done. Production: enforce password quality (libpam-pwquality) and"
echo "     lockout (pam_faillock), and inventory every account's purpose."
