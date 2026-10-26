#!/usr/bin/env bash
# Act 1, step 5: shut down the two backdoor listeners — the obvious bind shell
# AND the covert raw-socket one that never showed up in `ss -lntup`.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

# Stopping the oneshot unit kills both background helpers and their children.
# Mask it so Pingboard's Wants dependency cannot launch it again.
systemctl stop app-data-start.service
rm -f /etc/systemd/system/app-data-start.service
systemctl mask app-data-start.service
rm -f /opt/app-data/start.sh
systemctl daemon-reload
# if the covert backdoor was already knocked, make sure nothing lingers on 31337
fuser -k 31337/tcp 2>/dev/null || true

echo "[05] remaining listeners (tcp/udp):"
ss -lntup | sed 's/^/    /'
echo "[05] remaining raw sockets:"
ss --raw -p 2>/dev/null | sed 's/^/    /' || echo "    none"
echo
echo "[05] done. Re-run ../../attack/knock.sh — the magic packet does nothing now."
