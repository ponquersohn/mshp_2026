#!/usr/bin/env bash
# Appendix: measure. Containing a bug is not fixing it — scan for the real CVEs.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

echo "[90] host package CVEs (debsecan, if available)"
if command -v debsecan >/dev/null; then debsecan --suite "$(. /etc/os-release; echo $VERSION_CODENAME)" 2>/dev/null | head -20
else echo "  apt-get install debsecan  (needs egress; flush nftables first)"; fi

echo "[90] image scan (Trivy) — the pingboard image STILL ships a vulnerable app"
if command -v trivy >/dev/null; then
  trivy image --scanners vuln mshp/pingboard:hardened 2>/dev/null | tail -30
else
  echo "  Trivy not installed. Install (needs egress):"
  echo "    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
  echo "  then: trivy image mshp/pingboard:hardened"
fi

echo "[90] a Lynis pass for a hardening index + findings (don't chase the score)"
if command -v lynis >/dev/null; then lynis audit system --quick 2>/dev/null | grep -E 'Hardening index|Warning|Suggestion' | head -20
else echo "  apt-get install lynis  (or run from a clone)"; fi
echo
echo "[90] point: contain != patch. The injection in app/pingboard.py is still"
echo "     there — fix it (argv list, no shell) and keep the base image patched."
