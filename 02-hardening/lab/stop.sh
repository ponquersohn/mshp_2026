#!/usr/bin/env bash
# Shut the lab VM down.
#   ./stop.sh            graceful ACPI shutdown (waits for clean power-off)
#   ./stop.sh --force    pull the plug (QEMU quit) — fine for a disposable overlay
#   ./stop.sh --status   report whether the VM is running
set -euo pipefail
source "$(dirname "$0")/config.sh"

SOCK="$IMAGES_DIR/monitor.sock"
monitor() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$SOCK" >/dev/null 2>&1; }
vm_pids() { pgrep -f "qemu-system-x86_64.*$VM_NAME" 2>/dev/null || true; }
vm_running() { [[ -S "$SOCK" ]] && monitor "" && return 0; [[ -n "$(vm_pids)" ]]; }

FORCE=0 STATUS=0
for a in "$@"; do
  case "$a" in
    --force)  FORCE=1 ;;
    --status) STATUS=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

if (( STATUS )); then
  if vm_running; then echo "running (pids: $(vm_pids | tr '\n' ' '))"; else echo "stopped"; fi
  exit 0
fi
if ! vm_running; then echo "[stop] VM is not running."; rm -f "$SOCK"; exit 0; fi

if (( FORCE )); then
  echo "[stop] forcing QEMU to quit"
  monitor "quit" || kill $(vm_pids) 2>/dev/null || true
else
  echo "[stop] sending graceful ACPI power-down"
  monitor "system_powerdown"
  echo -n "[stop] waiting for clean shutdown"
  for _ in $(seq 1 30); do
    if ! vm_running; then echo " — done."; rm -f "$SOCK"; exit 0; fi
    echo -n "."; sleep 1
  done
  echo; echo "[stop] still up after 30s. Re-run with --force to pull the plug."
  exit 1
fi
for _ in $(seq 1 5); do vm_running || break; sleep 1; done
vm_running && { echo "[stop] SIGKILL"; kill -9 $(vm_pids) 2>/dev/null || true; }
rm -f "$SOCK"; echo "[stop] stopped."
