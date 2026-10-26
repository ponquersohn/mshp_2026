#!/usr/bin/env bash
# Act 1, step 4: remove persistence footholds (scheduled execution).
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

echo "[04] removing the rogue cron job"
rm -f /etc/cron.d/backup

echo "[04] checking other persistence spots"
echo "  rc.local:        $( [[ -f /etc/rc.local ]] && echo present || echo none )"
echo "  user crontabs:   $(ls /var/spool/cron/crontabs 2>/dev/null | tr '\n' ' ' || echo none)"
echo "  @reboot entries:"; grep -rl '@reboot' /etc/cron* /var/spool/cron 2>/dev/null | sed 's/^/    /' || true
echo
echo "[04] done. (The backdoor LISTENERS are handled in 05-services.)"
