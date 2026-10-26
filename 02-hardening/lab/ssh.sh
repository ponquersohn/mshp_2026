#!/usr/bin/env bash
# Shell into the guest, or run a command there (as $GUEST_USER, default hunter).
#   ./ssh.sh                            interactive shell
#   ./ssh.sh 'ss -lntup'                run a command
#   ./ssh.sh 'cloud-init status --wait' wait for first-boot provisioning
#   GUEST_USER=root ./ssh.sh            log in as root
set -euo pipefail
source "$(dirname "$0")/config.sh"
ssh_guest "$@"
