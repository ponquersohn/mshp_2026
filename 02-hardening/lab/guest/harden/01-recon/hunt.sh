#!/usr/bin/env bash
# Act 1, step 1: READ-ONLY triage of a server we just inherited. Changes nothing.
# Walks the places a dropped backdoor hides and flags what looks wrong. The
# lesson of the last section is the important one: listening != `ss -lntup`.
#
#   sudo bash /opt/pingboard/harden/01-recon/hunt.sh
set -uo pipefail
hr() { printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }
flag() { printf '  \033[1;31m[!] %s\033[0m\n' "$1"; }

hr "1. accounts that can become root"
awk -F: '$3==0 {print "  UID 0:",$1}' /etc/passwd
awk -F: '$3==0 && $1!="root"{f=1} END{if(f)exit 0; else exit 1}' /etc/passwd \
  && flag "a second UID-0 account exists besides root"
echo "  members of root-equivalent groups:"
for g in sudo docker adm; do printf '    %-6s: %s\n' "$g" "$(getent group $g | cut -d: -f4)"; done
flag "anyone in 'docker' can trivially become root on the host"

hr "2. sudo rules"
echo "  files in /etc/sudoers.d:"; ls -1 /etc/sudoers.d 2>/dev/null | sed 's/^/    /'
grep -rEh 'NOPASSWD|ALL=' /etc/sudoers.d 2>/dev/null | sed 's/^/    /'
flag "NOPASSWD rules and single-command grants (less/vi/env = root via GTFOBins)"

hr "3. SUID / SGID root binaries (outside the usual set)"
find / -xdev -perm -4000 -type f 2>/dev/null | sed 's/^/    /'
flag "anything under /usr/local, /opt, /home, /tmp is suspect"

hr "4. file capabilities"
getcap -r / 2>/dev/null | sed 's/^/    /'
flag "cap_setuid / cap_net_raw / cap_dac_* on an interpreter = privesc"

hr "5. persistence: cron + enabled units"
echo "  /etc/cron.d:"; ls -1 /etc/cron.d 2>/dev/null | sed 's/^/    /'
grep -rEh . /etc/cron.d 2>/dev/null | grep -vE '^\s*#' | sed 's/^/    /'
echo "  non-stock enabled units in /etc/systemd/system:"
ls -1 /etc/systemd/system/*.service 2>/dev/null | sed 's/^/    /'

hr "6. root's authorized_keys"
nl -ba /root/.ssh/authorized_keys 2>/dev/null | sed 's/^/    /'
flag "every key here can log in as root — do you recognise all of them?"

hr "PAM authentication policy (su + SSH)"
nl -ba /etc/pam.d/su /etc/pam.d/su-l 2>/dev/null | sed 's/^/    /'
grep -nE 'pam_succeed_if.*user *= *root|pam_permit' /etc/pam.d/su /etc/pam.d/su-l /etc/pam.d/sshd 2>/dev/null \
  && flag "inspect auth control flags: a sufficient root condition bypasses password verification"
/usr/sbin/sshd -T -C user=root,host=lab,addr=10.0.2.2 2>/dev/null \
  | grep -E '^(usepam|permitrootlogin|passwordauthentication|authenticationmethods) '

hr "7. polkit rules (pkexec)"
ls -1 /etc/polkit-1/rules.d 2>/dev/null | sed 's/^/    /'
grep -rEl 'Result.YES|isInGroup' /etc/polkit-1/rules.d 2>/dev/null | sed 's/^/    rule grants root: /'
flag "a rule returning YES for a group = silent root via pkexec"

hr "8. weak permissions"
find /opt /srv /home -xdev -perm -0002 2>/dev/null | sed 's/^/    world-writable: /'
find /opt /srv -xdev -type f \( -name '*.yml' -o -name '*.env' \) 2>/dev/null | sed 's|^|    config/secret: |'

hr "9. listening sockets — the NAIVE view (ss -lntup)"
ss -lntup 2>/dev/null | sed 's/^/    /'
echo "  ^ this is what most people check. It is not enough."

hr "10. listening sockets — the REAL view (raw & packet sockets)"
echo "  raw sockets (ss --raw -p):"
ss --raw -p 2>/dev/null | sed 's/^/    /'
echo "  processes holding a raw socket FD (these never show in ss -lntup):"
for pid in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
  if ls -l /proc/$pid/fd 2>/dev/null | grep -q 'socket:'; then
    if grep -qi 'raw' /proc/$pid/net/raw 2>/dev/null; then :; fi
  fi
done
# simpler + reliable: anything with an AF_INET raw socket is in /proc/net/raw
if [[ -s /proc/net/raw || -s /proc/net/raw6 ]]; then
  awk 'NR>1{print "    raw-socket inode owner uid="$8" (see: fuser / lsof)"}' /proc/net/raw 2>/dev/null | head
fi
echo "  suspect daemons:"
ps -eo pid,user,comm,args | grep -iE 'knock|telemetry|nc |ncat|socat|bash -i' | grep -v grep | sed 's/^/    /'
flag "a raw-socket daemon can open a shell on a knock with NOTHING listening first"

echo
echo "Triage done. Now remediate in order: 02-accounts, 03-privesc, 04-persistence,"
echo "05-services, 06-ssh, 07-sysctl-mounts. Re-run this hunt after each."
