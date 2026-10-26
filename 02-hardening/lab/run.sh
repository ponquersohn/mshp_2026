#!/usr/bin/env bash
# Boot the hardening-lab VM.
#
#   ./run.sh                 boot in foreground (console attached)
#   ./run.sh --daemon        run in background, console -> console.log
#   ./run.sh --snapshot      ephemeral boot; all disk writes discarded on exit
#   ./run.sh --share         also mount lab/guest over 9p for live editing
#                            (disables ./snapshot.sh: 9p blocks QEMU savevm)
#
# Host port forwards: ssh -> localhost:$SSH_PORT, app -> localhost:$APP_PORT.
set -euo pipefail
source "$(dirname "$0")/config.sh"

SNAPSHOT=0 DAEMON=0 SHARE=0
for arg in "$@"; do
  case "$arg" in
    --daemon)   DAEMON=1 ;;
    --snapshot) SNAPSHOT=1 ;;
    --share)    SHARE=1 ;;
    -h|--help)  sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

[[ -f "$DISK_IMAGE" ]] || { echo "No disk image. Run ./setup.sh first." >&2; exit 1; }

QEMU=(
  qemu-system-x86_64
  -name "$VM_NAME"
  -machine q35,accel=kvm
  -cpu host
  -smp "$VM_CPUS"
  -m "$VM_MEM"
  -drive "file=$DISK_IMAGE,if=virtio,format=qcow2"
  # readonly so it does not block ./snapshot.sh (savevm rejects writable
  # non-qcow2 devices); cloud-init only ever reads the seed anyway.
  -drive "file=$SEED_IMAGE,if=virtio,format=raw,readonly=on"
  # user-mode NAT: ssh + the app port are forwarded to the host; guest reaches
  # the internet for apt/docker pulls during the demo.
  -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22,hostfwd=tcp:127.0.0.1:${APP_PORT}-:8080"
  -device "virtio-net-pci,netdev=net0"
  -monitor "unix:$IMAGES_DIR/monitor.sock,server,nowait"
)

# The payload is copied into the guest at provision time, so the 9p share is
# only for LIVE host-side editing. It is OFF by default because an active 9p
# export blocks QEMU's savevm (./snapshot.sh). Add --share to mount lab/guest at
# $GUEST_SRC_MNT; without it, re-sync edits by re-running ./setup.sh + ./reset.sh.
if (( SHARE )); then
  QEMU+=( -virtfs "local,path=$GUEST_SRC,mount_tag=$MOUNT_TAG,security_model=mapped-xattr,id=hostshare" )
fi

(( SNAPSHOT )) && QEMU+=( -snapshot )

echo "[run] $VM_NAME  cpus=$VM_CPUS mem=${VM_MEM}M"
echo "[run] ssh -> localhost:$SSH_PORT   (./ssh.sh)"
echo "[run] app -> http://localhost:$APP_PORT/   (the vulnerable service)"
(( SHARE ))    && echo "[run] 9p share ON: lab/guest -> $GUEST_SRC_MNT (disables ./snapshot.sh)"
(( SNAPSHOT )) && echo "[run] SNAPSHOT mode: disk writes are discarded on shutdown"
echo "[run] console: Ctrl-a x to quit, Ctrl-a c for QEMU monitor"
echo

if (( DAEMON )); then
  "${QEMU[@]}" -display none -daemonize -serial "file:$LAB_DIR/console.log"
  echo "[run] backgrounded, console -> $LAB_DIR/console.log"
  echo "[run] stop it with: ./stop.sh"
else
  exec "${QEMU[@]}" -nographic -serial mon:stdio
fi
