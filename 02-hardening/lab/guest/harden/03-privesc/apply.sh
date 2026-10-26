#!/usr/bin/env bash
# Act 1, step 3: close the privilege-escalation backdoors.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

echo "[03] removing the su PAM authentication bypass"
sed -i '/# MSHP-SU-PAM-BYPASS$/d' /etc/pam.d/su /etc/pam.d/su-l

echo "[03] removing the sudoers backdoor"
rm -f /etc/sudoers.d/90-webops /etc/sudoers.d/91-hunter-less
visudo -c >/dev/null && echo "  sudoers still valid"

echo "[03] disarming the SUID-root shell"
if [[ -u /usr/local/bin/notes ]]; then
  chmod u-s /usr/local/bin/notes
  echo "  chmod u-s /usr/local/bin/notes  (or: rm it entirely)"
fi

echo "[03] removing the cap_setuid backdoor on python"
PYBIN="$(readlink -f /usr/bin/python3)"
setcap -r "$PYBIN" 2>/dev/null || true
getcap "$PYBIN" || echo "  no capabilities on $PYBIN now"

echo "[03] deleting the polkit/pkexec backdoor rule"
rm -f /etc/polkit-1/rules.d/49-trusted.rules

echo
echo "[03] done. Re-run ../../attack/privesc.sh: SUID shell, pkexec and the python"
echo "     cap route should all fail now."
