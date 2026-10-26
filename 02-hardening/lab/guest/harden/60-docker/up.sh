#!/usr/bin/env bash
# Hardening step 6: stop the root systemd service and run the app boxed in.
# Uses plain `docker run` so every least-privilege flag is visible on stage.
# (compose.yml in this dir is the same thing for `docker compose` users.)
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
CTX=/opt/pingboard
DF=$CTX/harden/60-docker/Dockerfile

echo "[60] stopping the unconfined root service"
systemctl disable --now pingboard.service 2>/dev/null || true

# The image is prebuilt at provision time (while egress was open). Only build
# here if it is missing — and warn, because the Act-2 nftables step blocks the
# egress a build needs.
if docker image inspect mshp/pingboard:hardened >/dev/null 2>&1; then
  echo "[60] using prebuilt image mshp/pingboard:hardened"
else
  echo "[60] image missing — building (needs egress; flush nftables if this hangs)"
  docker build -t mshp/pingboard:hardened -f "$DF" "$CTX"
fi

echo "[60] (re)starting the hardened container"
docker rm -f pingboard 2>/dev/null || true
docker run -d --name pingboard \
  -p 8080:8080 \
  --user 10001:10001 \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 128 --memory 256m \
  --tmpfs /tmp --tmpfs /var/log/pingboard \
  --restart unless-stopped \
  mshp/pingboard:hardened

sleep 1
docker ps --filter name=pingboard --format '[60] container: {{.Names}}  {{.Status}}  {{.Ports}}'
echo
echo "[60] done. Re-run ../../attack/pwn.sh:"
echo "     #1 identity now shows uid=10001, not root"
echo "     #2/#3 host secrets -> 'No such file': they aren't in the container"
echo "     #5 persistence -> read-only rootfs / no host /etc"
