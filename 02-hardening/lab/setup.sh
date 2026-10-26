#!/usr/bin/env bash
# One-time (idempotent) setup for the MSHP hardening QEMU lab.
#
#   - obtains the Ubuntu cloud image (reflink from a local copy if available)
#   - builds a working qcow2 overlay
#   - generates an SSH keypair for passwordless access
#   - builds a cloud-init seed that, on first boot:
#       * installs a DELIBERATELY BLOATED package set (nmap, netcat, socat,
#         tcpdump, compilers, ... — attacker tooling a prod box should not ship)
#       * installs the containment tooling we will USE later (docker, auditd,
#         nftables, apparmor-utils, bpftrace) and pre-pulls a python base image
#       * copies the lab payload to /opt/pingboard and starts the vulnerable
#         'pingboard' web service as ROOT on :8080
#       * plants a couple of fake secrets for the blast-radius demo
#
# Safe to re-run: existing artifacts are reused. Delete images/ to start clean.
set -euo pipefail
source "$(dirname "$0")/config.sh"

mkdir -p "$IMAGES_DIR"

# --- 1. SSH keypair ----------------------------------------------------------
if [[ ! -f "$SSH_KEY" ]]; then
  echo "[setup] generating lab SSH keypair"
  ssh-keygen -t ed25519 -N '' -f "$SSH_KEY" -C "mshp-hardening-lab" >/dev/null
fi
PUBKEY="$(cat "$SSH_KEY.pub")"

# --- 2. Base cloud image -----------------------------------------------------
if [[ ! -f "$BASE_IMAGE" ]]; then
  if [[ -f "$SEED_FROM" ]]; then
    echo "[setup] reusing local base image $SEED_FROM (reflink/copy)"
    cp --reflink=auto "$SEED_FROM" "$BASE_IMAGE"
  else
    echo "[setup] downloading $CLOUD_IMAGE_URL"
    curl -fL --progress-bar -o "$BASE_IMAGE.part" "$CLOUD_IMAGE_URL"
    mv "$BASE_IMAGE.part" "$BASE_IMAGE"
  fi
else
  echo "[setup] base image present: $BASE_IMAGE"
fi

# --- 3. Working overlay disk -------------------------------------------------
if [[ ! -f "$DISK_IMAGE" ]]; then
  echo "[setup] creating working disk ($DISK_SIZE) backed by base image"
  qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$DISK_IMAGE" "$DISK_SIZE" >/dev/null
else
  echo "[setup] working disk present: $DISK_IMAGE (./reset.sh to roll back)"
fi

# --- 4. cloud-init seed ------------------------------------------------------
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# Pack the lab payload (guest/) into a base64 blob embedded in the seed, so the
# guest is fully self-contained and provisioning needs no 9p share.
echo "[setup] packing lab payload from $GUEST_SRC"
PAYLOAD_B64="$(tar czf - -C "$GUEST_SRC" . | base64 -w0)"

cat >"$WORK/meta-data" <<EOF
instance-id: $VM_NAME
local-hostname: pingboard
EOF

cat >"$WORK/user-data" <<EOF
#cloud-config
users:
  - name: $GUEST_USER
    groups: [sudo, docker]
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    lock_passwd: false
    ssh_authorized_keys:
      - $PUBKEY

chpasswd:
  expire: false
  users:
    - name: $GUEST_USER
      password: $GUEST_PASS
      type: text

disable_root: false

write_files:
  - path: /etc/modules-load.d/9p.conf
    content: |
      9p
      9pnet_virtio
  # A fake "application secret" the service account can read. Reading this via
  # the RCE is the "I owned the box" money shot in the first demo.
  - path: /root/flag.txt
    permissions: '0600'
    content: |
      MSHP{running-as-root-was-a-choice-you-made}
  - path: /srv/pingboard/secret.env
    permissions: '0600'
    content: |
      DB_PASSWORD=hunter2-but-in-prod-this-is-real
      API_TOKEN=sk-live-0bviously-fake-lab-token
  # The whole lab payload (app + harden steps + attack + badseed), embedded in
  # the seed so provisioning needs no 9p share. Extracted to $GUEST_APP_DIR.
  - path: /opt/pingboard.tar.gz
    encoding: b64
    permissions: '0600'
    content: $PAYLOAD_B64

# Optional 9p share for LIVE editing during rehearsal (run.sh --share). The
# payload above does not depend on it.
mounts:
  - [ $MOUNT_TAG, $GUEST_SRC_MNT, 9p, "trans=virtio,version=9p2000.L,msize=262144,nofail,_netdev", "0", "0" ]

bootcmd:
  - mkdir -p $GUEST_SRC_MNT

package_update: true
packages:
  # --- containment tooling we will actually USE in the hardening steps -------
  - docker.io
  - auditd
  - audispd-plugins
  - nftables
  - apparmor-utils
  - bpftrace
  - python3
  - unattended-upgrades
  # --- host-sweep (Act 1) tooling --------------------------------------------
  - fail2ban          # brute-force throttling (06-ssh)
  - aide              # file integrity (appendix 70)
  - acct              # last/lastlog account forensics
  - libpam-pwquality  # password policy (02-accounts)
  - libcap2-bin       # getcap/setcap (recon + the capability backdoor)
  # --- DELIBERATE BLOAT: an over-provisioned box. Step 1 is purging most of ---
  #     this. Several of these are exactly what an attacker wants post-RCE.
  - nmap
  - netcat-traditional
  - socat
  - tcpdump
  - telnet
  - ftp
  - whois
  - bind9-dnsutils
  - build-essential
  - git
  - ruby
  - php-cli
  - nodejs
  - sl
  - cowsay
  - lynx

runcmd:
  # Root key login so GUEST_USER=root ./ssh.sh works.
  - [ bash, -c, "install -d -m700 /root/.ssh && echo '$PUBKEY' > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys" ]
  # Copy the lab payload off the 9p share onto local disk so the running service
  # does not depend on the share staying mounted.
  - [ bash, -c, "mkdir -p $GUEST_APP_DIR && tar xzf /opt/pingboard.tar.gz -C $GUEST_APP_DIR && rm -f /opt/pingboard.tar.gz" ]
  - [ bash, -c, "chmod +x $GUEST_APP_DIR/harden/*.sh $GUEST_APP_DIR/harden/*/*.sh $GUEST_APP_DIR/attack/*.sh $GUEST_APP_DIR/badseed/*.sh 2>/dev/null || true" ]
  # Install and start the vulnerable service AS ROOT on :8080.
  - [ bash, -c, "install -m0644 $GUEST_APP_DIR/systemd/pingboard.service /etc/systemd/system/pingboard.service" ]
  # Make sure pkexec is present for the polkit backdoor demo.
  - [ bash, -c, "apt-get install -y pkexec || apt-get install -y policykit-1 || true" ]
  # Plant the "inherited compromise" (Act 1 hunts + removes all of this).
  - [ bash, -c, "bash $GUEST_APP_DIR/badseed/install.sh || true" ]
  - [ bash, -c, "systemctl daemon-reload && systemctl enable --now pingboard.service" ]
  # Pre-pull the python base AND pre-build the hardened image now, while egress
  # is open — the demo's nftables step later blocks egress, so building then
  # would fail. The docker step just 'docker run's this prebuilt image.
  - [ bash, -c, "systemctl enable --now docker && docker pull python:3.12-slim-bookworm || true" ]
  - [ bash, -c, "docker build -t mshp/pingboard:hardened -f $GUEST_APP_DIR/harden/60-docker/Dockerfile $GUEST_APP_DIR || true" ]
  # Turn auditd OFF at boot so the telemetry step has something to switch on.
  - [ bash, -c, "systemctl disable --now auditd 2>/dev/null || true" ]
  - [ bash, -c, "touch /var/lib/cloud/instance/mshp-lab-provisioned" ]

final_message: "MSHP hardening lab ready after \$UPTIME s. Vulnerable pingboard on :8080."
EOF

echo "[setup] building cloud-init seed image"
if command -v cloud-localds >/dev/null 2>&1; then
  cloud-localds "$SEED_IMAGE" "$WORK/user-data" "$WORK/meta-data"
elif command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs -output "$SEED_IMAGE" -volid cidata -joliet -rock \
    "$WORK/user-data" "$WORK/meta-data" >/dev/null 2>&1
elif command -v genisoimage >/dev/null 2>&1; then
  genisoimage -output "$SEED_IMAGE" -volid cidata -joliet -rock \
    "$WORK/user-data" "$WORK/meta-data" >/dev/null 2>&1
else
  echo "[setup] ERROR: need one of cloud-localds / xorriso / genisoimage." >&2
  echo "        Install with: sudo apt-get install cloud-image-utils" >&2
  exit 1
fi

echo
echo "[setup] done."
echo "  Next:  ./run.sh --daemon                      # boot in background"
echo "         ./ssh.sh 'cloud-init status --wait'    # wait out first-boot provisioning"
echo "         curl http://localhost:$APP_PORT/        # the app answers on the host"
echo
echo "  First boot installs a lot of packages; give it a few minutes."
