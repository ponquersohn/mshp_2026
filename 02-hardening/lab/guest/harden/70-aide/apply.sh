#!/usr/bin/env bash
# Appendix: file-integrity baseline with AIDE. Baseline a clean box, let the
# attacker change things, then prove exactly what changed.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

case "${1:-baseline}" in
  baseline)
    echo "[70] building AIDE baseline (this can take a minute)"
    aideinit -y -f 2>/dev/null || aide --init
    cp -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true
    echo "[70] baseline stored. Now run the exploit / change something, then:"
    echo "     sudo bash 70-aide/apply.sh check"
    ;;
  check)
    echo "[70] checking filesystem against the baseline"
    aide --check || true   # non-zero exit = differences found, which is the point
    ;;
  *) echo "usage: $0 [baseline|check]"; exit 2 ;;
esac
