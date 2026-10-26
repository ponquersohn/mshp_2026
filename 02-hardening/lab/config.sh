# Shared configuration for the MSHP hardening QEMU lab.
# Sourced by every script here. Override any value via the environment, e.g.
#   SSH_PORT=2300 ./run.sh
#
# This lab boots a DELIBERATELY INSECURE Ubuntu VM: a command-injection web
# service running as root, plus a pile of packages a production box has no
# business shipping. Everything happens inside a disposable QEMU guest reachable
# only through host-local port forwards. Never run the guest's services, or the
# exploit, against anything you care about.

# --- Paths -------------------------------------------------------------------
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUEST_SRC="$LAB_DIR/guest"                         # shared into the guest over 9p
IMAGES_DIR="${IMAGES_DIR:-$LAB_DIR/images}"        # working disk + seed (gitignored)

# --- Guest OS ----------------------------------------------------------------
# Ubuntu cloud image, picked by codename.
#   noble     24.04 LTS
#   stonking  26.10       (matches the lkmhunter testbed)
# Override per-invocation, e.g. CLOUD_RELEASE=noble ./run.sh
CLOUD_RELEASE="${CLOUD_RELEASE:-stonking}"
CLOUD_IMAGE_URL="${CLOUD_IMAGE_URL:-https://cloud-images.ubuntu.com/${CLOUD_RELEASE}/current/${CLOUD_RELEASE}-server-cloudimg-amd64.img}"
BASE_IMAGE="$IMAGES_DIR/${CLOUD_RELEASE}-base.img"   # pristine download, never booted directly
DISK_IMAGE="$IMAGES_DIR/${CLOUD_RELEASE}-disk.qcow2" # working overlay we actually boot
SEED_IMAGE="$IMAGES_DIR/seed.img"                    # cloud-init NoCloud seed
DISK_SIZE="${DISK_SIZE:-16G}"

# If this host already has a matching Ubuntu base image downloaded elsewhere
# (e.g. the lkmhunter testbed), setup.sh will reflink it instead of re-fetching.
SEED_FROM="${SEED_FROM:-$HOME/dev/lkmhunter/testbed/images/${CLOUD_RELEASE}-base.img}"

# --- VM resources ------------------------------------------------------------
VM_CPUS="${VM_CPUS:-2}"
VM_MEM="${VM_MEM:-2048}"      # MiB; 2G is comfortable for one container + auditd
VM_NAME="${VM_NAME:-mshp-hardening-lab}"

# --- Networking (QEMU user-mode NAT + host port forwards) --------------------
SSH_PORT="${SSH_PORT:-2223}"   # host port -> guest :22  (2223 to avoid lkmhunter's 2222)
APP_PORT="${APP_PORT:-8080}"   # host port -> guest :8080 (the vulnerable app)

# --- Guest-side account ------------------------------------------------------
# A named admin, 'hunter', with passwordless sudo — matches the slide examples.
# Root key-login is also enabled (GUEST_USER=root ./ssh.sh) for convenience.
GUEST_USER="${GUEST_USER:-hunter}"
GUEST_PASS="${GUEST_PASS:-hunter}"          # console login; ssh uses the key below
SSH_KEY="$LAB_DIR/id_lab"                   # auto-generated keypair (gitignored)
MOUNT_TAG="mshplab"                          # 9p tag; lab/guest mounts at /opt/mshp-src
GUEST_SRC_MNT="/opt/mshp-src"               # read-only-ish live view of lab/guest
GUEST_APP_DIR="/opt/pingboard"              # local copy the service actually runs from

# Convenience wrappers so every ssh/scp call shares the same options.
ssh_guest() {
  ssh -i "$SSH_KEY" -p "$SSH_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR -o ConnectTimeout=5 \
    "${GUEST_USER}@localhost" "$@"
}
scp_guest() {
  scp -i "$SSH_KEY" -P "$SSH_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR "$@"
}
