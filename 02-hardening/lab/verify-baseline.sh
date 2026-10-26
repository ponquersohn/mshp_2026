#!/usr/bin/env bash
# Read-only readiness check for the deliberately vulnerable opening state.
set -euo pipefail
source "$(dirname "$0")/config.sh"
ssh_guest 'sudo bash -s' <<'GUEST'
set -euo pipefail
absent() { if "$@"; then echo "[baseline] FAIL: unexpected: $*" >&2; exit 1; fi; }
pass() { echo "[baseline] OK: $1"; }
test -f /var/lib/cloud/instance/mshp-lab-provisioned
pass 'provisioning completed'
systemctl is-active --quiet pingboard.service
systemctl is-active --quiet app-data-start.service
test "$(systemctl show pingboard.service -p User --value)" = root
pass 'root app and current application-data startup hook are active'
for helper in telemetry-helper knockd-helper; do
  pid=$(cat "/run/pingboard/$helper.pid")
  kill -0 "$pid"
  grep -q "/opt/pingboard/badseed/$helper.py" "/proc/$pid/cmdline"
  grep -q app-data-start.service "/proc/$pid/cgroup"
done
pass 'both helpers belong to the startup unit'
absent systemctl is-active --quiet telemetry-helper.service
absent systemctl is-active --quiet knockd-helper.service
pass 'legacy helper services are inactive'
id svc-deploy | grep -q 'uid=0'
id -nG webops | grep -qw docker
test -u /usr/local/bin/notes
getcap "$(readlink -f /usr/bin/python3)" | grep -q cap_setuid
grep -q MSHP-SU-PAM-BYPASS /etc/pam.d/su
for mode in plain login; do
  args=()
  [[ $mode != login ]] || args=(-)
  test "$(timeout 10 runuser -u hunter -- su "${args[@]}" root -c 'id -u' </dev/null)" = 0
done
pass 'ordinary hunter can su and su - to root without a password' 
test -f /etc/sudoers.d/90-webops
test -f /etc/polkit-1/rules.d/49-trusted.rules
test -f /etc/cron.d/backup
pass 'account, PAM, sudo, SUID, capability, polkit and cron demo fixtures exist'
absent test -e /etc/ssh/sshd_config.d/00-mshp.conf
absent test -e /etc/systemd/system/pingboard.service.d/50-apparmor.conf
absent nft list table inet mshp >/dev/null 2>&1
absent docker container inspect pingboard >/dev/null 2>&1
pass 'hardening steps have not been applied'
docker image inspect mshp/pingboard:hardened >/dev/null
pass 'container image is prebuilt'
python3 - <<'PY'
import json
import urllib.request
with urllib.request.urlopen('http://127.0.0.1:8080/api/ping?host=127.0.0.1', timeout=20) as r:
    result = json.load(r)
assert result['exit'] == 0, result
print('[baseline] OK: legitimate ping works')
PY
GUEST
curl --fail --silent --max-time 5 "http://127.0.0.1:$APP_PORT/" >/dev/null
echo '[baseline] OK: application is reachable through the host port forward'
