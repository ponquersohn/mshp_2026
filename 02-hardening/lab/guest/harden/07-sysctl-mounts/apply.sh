#!/usr/bin/env bash
# Act 1, step 7: harden the kernel/network surface and make scratch dirs
# unexecutable (a dropped payload in /tmp can't run).
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
cd /opt/pingboard/harden/07-sysctl-mounts

echo "[07] before: ptrace_scope=$(sysctl -n kernel.yama.ptrace_scope) dmesg_restrict=$(sysctl -n kernel.dmesg_restrict)"
install -m0644 99-mshp-hardening.conf /etc/sysctl.d/99-mshp-hardening.conf
# unprivileged_userns_clone only exists on some kernels; don't fail if absent
sysctl -p /etc/sysctl.d/99-mshp-hardening.conf 2>/dev/null | sed 's/^/    /' || true
echo "[07] after:  ptrace_scope=$(sysctl -n kernel.yama.ptrace_scope) dmesg_restrict=$(sysctl -n kernel.dmesg_restrict)"

echo "[07] making scratch dirs noexec,nosuid,nodev"
for m in /tmp /dev/shm /var/tmp; do
  if mountpoint -q "$m"; then
    mount -o remount,noexec,nosuid,nodev "$m"
  else
    # Not its own mount on this cloud image — put a hardened tmpfs over it.
    mount -t tmpfs -o noexec,nosuid,nodev tmpfs "$m"
  fi
  echo "    $m -> $(findmnt -no OPTIONS "$m" | tr ',' '\n' | grep -E 'noexec|nosuid|nodev' | tr '\n' ',')"
done
echo
echo "[07] demo: a payload dropped in /tmp can no longer execute:"
printf '#!/bin/sh\necho pwned\n' > /tmp/mshp-payload.sh; chmod +x /tmp/mshp-payload.sh
/tmp/mshp-payload.sh 2>&1 | sed 's/^/    /' || echo "    -> Permission denied (noexec). good."
rm -f /tmp/mshp-payload.sh
echo
echo "[07] done. These sysctls persist (sysctl.d); the remounts need /etc/fstab"
echo "     entries (or systemd tmpfs units) to survive reboot."
