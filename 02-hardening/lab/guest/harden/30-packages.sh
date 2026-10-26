#!/usr/bin/env bash
# Hardening step 1: shrink the attack surface by removing packages the box does
# not need. On a real host every one of these is a liability: more code to patch
# and, after an RCE, a ready-made toolbox for the attacker (probe #6 in pwn.sh).
#
# Run as root in the guest:  sudo bash 30-packages.sh
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

# Attacker-useful tooling and dev cruft that a single-purpose app server should
# not carry. (We keep python3 — the app needs it — and the containment tools.)
# Keep netcat-openbsd: Ubuntu 26.10 cloud-init-base depends on it.
# Remove bsd-mailx with postfix so apt does not install a replacement MTA.
# Keep make: removing it can install a replacement implementation.
BLOAT=(
  nmap netcat-traditional socat tcpdump telnet ftp whois dnsutils bind9-dnsutils
  build-essential gcc g++ git ruby php-cli nodejs
  sl cowsay lynx postfix bsd-mailx
)

echo "[30] packages before: $(dpkg --get-selections | grep -c '\binstall$')"
# Package names vary across Ubuntu releases. Purge only installed packages;
# an unavailable name would otherwise abort the entire apt transaction.
INSTALLED_BLOAT=()
for package in "${BLOAT[@]}"; do
  if [[ "$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)" == installed ]]; then
    INSTALLED_BLOAT+=("$package")
  fi
done
echo "[30] purging: ${INSTALLED_BLOAT[*]}"
export DEBIAN_FRONTEND=noninteractive
if (( ${#INSTALLED_BLOAT[@]} )); then
  apt-get purge -y "${INSTALLED_BLOAT[@]}"
fi
apt-get autoremove --purge -y
apt-get clean
echo "[30] packages after:  $(dpkg --get-selections | grep -c '\binstall$')"

echo
echo "[30] and keep them gone: unattended-upgrades applies security updates."
systemctl enable --now unattended-upgrades 2>/dev/null || true
systemctl is-enabled unattended-upgrades 2>/dev/null || true

echo
echo "[30] done. Re-run ../attack/pwn.sh — probe #6 (toolbox) should be nearly"
echo "     empty now, and #4 (egress via curl) may already fail if curl went."
