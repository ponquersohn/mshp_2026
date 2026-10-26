#!/usr/bin/env bash
# Live snapshots of the running lab. Default baseline: clean (deliberately dirty).
# Usage: ./snapshot.sh save|restore|list [name]
set -euo pipefail
source "$(dirname "$0")/config.sh"
exec python3 "${LAB_DIR}/snapshot-monitor.py" "$IMAGES_DIR/monitor.sock" "$@"
